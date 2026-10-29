import AppKit
import Combine
import CoreFoundation
import Foundation
import IOKit
import QuadCastStudioCore

struct USBMicrophone: Equatable {
    let vendorID: Int
    let productID: Int
    let name: String

    var identifier: String { String(format: "%04X:%04X", vendorID, productID) }
}

enum QuadCastUSBDetector {
    // Original QuadCast S lighting controller only. DuoCast and QuadCast 2/2S
    // are intentionally excluded, even if a newer backend recognizes them.
    private static let originalIDs: Set<String> = [
        "0951:171F", "03F0:0F8B", "03F0:028C", "03F0:048C", "03F0:068C"
    ]

    static func findOriginalQuadCastS() -> USBMicrophone? {
        for serviceClass in ["IOUSBHostDevice", "IOUSBDevice"] {
            guard let matching = IOServiceMatching(serviceClass) else { continue }
            var iterator: io_iterator_t = 0
            guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(iterator) }

            while true {
                let service = IOIteratorNext(iterator)
                if service == 0 { break }
                defer { IOObjectRelease(service) }
                guard let vendor = number("idVendor", on: service),
                      let product = number("idProduct", on: service) else { continue }
                let id = String(format: "%04X:%04X", vendor, product)
                guard originalIDs.contains(id) else { continue }
                let name = string("USB Product Name", on: service) ?? "HyperX QuadCast S"
                return USBMicrophone(vendorID: vendor, productID: product, name: name)
            }
        }
        return nil
    }

    private static func number(_ key: String, on service: io_service_t) -> Int? {
        guard let raw = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else { return nil }
        return (raw as? NSNumber)?.intValue
    }

    private static func string(_ key: String, on service: io_service_t) -> String? {
        guard let raw = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else { return nil }
        return raw as? String
    }
}

enum ControlState: Equatable {
    case disconnected, missingBackend, ready, applying, active, verified, error

    var label: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .missingBackend: return "Controller unavailable"
        case .ready: return "Connected · ready"
        case .applying: return "Applying lighting…"
        case .active: return "Control active · not visually verified"
        case .verified: return "Lighting verified by you"
        case .error: return "Connection or control error"
        }
    }
}

@MainActor
final class DeviceController: ObservableObject {
    @Published private(set) var microphone: USBMicrophone?
    @Published private(set) var backendPath: String?
    @Published private(set) var state: ControlState = .disconnected
    @Published private(set) var lastError: String?
    @Published private(set) var lastCommand: String = "None"
    @Published private(set) var lastOutput: String = ""
    @Published private(set) var lastAttempt: Date?

    private var ownedProcess: Process?
    private var outputPipe: Pipe?
    private var activeConfiguration: LightingConfiguration?
    private var isReplacing = false

    init() { refreshConnection() }

    var canApply: Bool {
        microphone != nil && backendPath != nil && !isReplacing
    }

    var diagnostics: String {
        let mic = microphone.map { "\($0.name) [\($0.identifier)]" } ?? "Not detected"
        let controller = backendPath ?? "Not installed at a supported path"
        let pid = ownedProcess.map { String($0.processIdentifier) } ?? "None"
        let time = lastAttempt.map { $0.formatted(date: .abbreviated, time: .standard) } ?? "Never"
        return """
        QuadCast Studio — Local Diagnostics
        USB original QuadCast S: \(mic)
        Backend: \(controller)
        Status: \(state.label)
        Owned controller PID: \(pid)
        Last attempt: \(time)
        Last command arguments: \(lastCommand)
        Last error: \(lastError ?? "None")
        Controller output: \(lastOutput.isEmpty ? "None" : lastOutput)

        Notes: RGB previews are requested values, not LED-state readback.
        No microphone audio is captured by this app.
        """
    }

    func refreshConnection() {
        let latestDevice = QuadCastUSBDetector.findOriginalQuadCastS()
        let latestBackend = ["/opt/homebrew/bin/quadcastrgb", "/usr/local/bin/quadcastrgb"]
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
        let changed = latestDevice != microphone
        microphone = latestDevice
        backendPath = latestBackend

        if changed {
            lastError = nil
            lastOutput = ""
            activeConfiguration = nil
            if let running = ownedProcess {
                // Never terminate a process started from Terminal or by other apps.
                ownedProcess = nil
                running.terminationHandler = nil
                if running.isRunning { running.terminate() }
            }
        }

        if microphone == nil {
            state = .disconnected
        } else if backendPath == nil {
            state = .missingBackend
        } else if lastError != nil {
            state = .error
        } else if let current = ownedProcess {
            if !current.isRunning {
                ownedProcess = nil
                lastError = "The QuadcastRGB controller stopped. Reapply lighting to retry."
                state = .error
            }
        } else if !isReplacing {
            state = .ready
        }
    }

    func apply(_ configuration: LightingConfiguration) {
        guard !isReplacing else { return }
        Task { await applyAsync(configuration) }
    }

    private func applyAsync(_ configuration: LightingConfiguration) async {
        guard !isReplacing else { return }
        refreshConnection()
        guard let executable = backendPath, microphone != nil else { return }

        let args: [String]
        do { args = try configuration.arguments() }
        catch {
            lastError = error.localizedDescription
            state = .error
            return
        }

        isReplacing = true
        state = .applying
        lastError = nil
        lastOutput = ""
        lastAttempt = Date()
        lastCommand = args.joined(separator: " ")
        defer { isReplacing = false }

        guard await stopOwnedProcess() else {
            lastError = "Existing app-owned lighting process did not stop. Quit and reopen QuadCast Studio before trying again."
            state = .error
            return
        }
        guard microphone != nil else {
            state = .disconnected
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
        let pipe = Pipe()
        outputPipe = pipe
        process.standardError = pipe
        process.standardOutput = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            let data = fileHandle.availableData
            if data.isEmpty {
                fileHandle.readabilityHandler = nil
                return
            }
            let message = String(decoding: data, as: UTF8.self)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.lastOutput = String((self.lastOutput + message).suffix(3000))
            }
        }
        process.terminationHandler = { [weak self] finished in
            Task { @MainActor [weak self] in
                guard let self, self.ownedProcess === finished else { return }
                self.ownedProcess = nil
                self.outputPipe?.fileHandleForReading.readabilityHandler = nil
                self.outputPipe = nil
                self.activeConfiguration = nil
                self.lastError = "QuadcastRGB exited (status \(finished.terminationStatus)). "
                    + "If a Terminal copy is still running, stop it with Control+C. "
                    + (self.lastOutput.isEmpty ? "Check USB connection and retry." : self.lastOutput)
                self.state = self.microphone == nil ? .disconnected : .error
            }
        }

        do {
            try process.run()
            ownedProcess = process
            activeConfiguration = configuration
            // QuadcastRGB on macOS intentionally remains running as it sends LED
            // sequences. A running process indicates control is active, not proof
            // that the LEDs physically changed.
            try? await Task.sleep(nanoseconds: 700_000_000)
            if ownedProcess === process, process.isRunning, microphone != nil {
                state = .active
            }
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            outputPipe = nil
            activeConfiguration = nil
            lastError = "Could not launch QuadcastRGB: \(error.localizedDescription)"
            state = .error
        }
    }

    func confirmHardwareChanged() {
        guard microphone != nil, ownedProcess?.isRunning == true, state == .active else { return }
        state = .verified
    }

    func reportNoChange() {
        guard microphone != nil else { return }
        lastError = "No visible RGB change. Confirm the microphone is unmuted and no Terminal controller is competing."
        state = .error
    }

    /// Returns false rather than starting a second controller if shutdown stalls.
    private func stopOwnedProcess() async -> Bool {
        guard let current = ownedProcess else { return true }
        current.terminationHandler = nil
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        if current.isRunning { current.terminate() }
        let finished = await Task.detached(priority: .utility) { () -> Bool in
            for _ in 0..<20 {
                if !current.isRunning { return true }
                Thread.sleep(forTimeInterval: 0.1)
            }
            return !current.isRunning
        }.value
        if finished {
            ownedProcess = nil
            outputPipe = nil
            return true
        }
        return false
    }

    func stopForQuit() {
        if let current = ownedProcess, current.isRunning { current.terminate() }
    }
}
