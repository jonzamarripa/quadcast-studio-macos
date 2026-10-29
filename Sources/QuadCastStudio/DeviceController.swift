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
    let registryID: UInt64

    var isSupported: Bool { ["0951:171F", "03F0:0F8B", "03F0:028C", "03F0:048C", "03F0:068C"].contains(identifier) }
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
                var registryID: UInt64 = 0
                IORegistryEntryGetRegistryEntryID(service, &registryID)
                return USBMicrophone(vendorID: vendor, productID: product, name: name, registryID: registryID)
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
    @Published private(set) var lastCommand = "None"
    @Published private(set) var lastOutput = ""
    @Published private(set) var lastAttempt: Date?
    @Published private(set) var busy = false
    @Published private(set) var sleeping = false
    @Published var restoreAfterReconnect: Bool {
        didSet { defaults.set(restoreAfterReconnect, forKey: "QuadCastStudio.RestoreAfterReconnect"); if !restoreAfterReconnect { restorePending = false } }
    }
    private let runner: OwnedProcessController
    private let defaults: UserDefaults
    private let discover: () -> USBMicrophone?
    private let resolveBackend: () -> String?
    private var subscriptions = Set<AnyCancellable>()
    private var generation = 0
    private var recoveryNeeded = false
    private var restorePending = false
    private var quitting = false
    private var lastApplied: LightingConfiguration?
    private var operation: Task<Void, Never>?
    private let settleDelay: UInt64
    private let lastKey = "QuadCastStudio.LastApplied.v1"

    init(defaults: UserDefaults = .standard,
         runner: OwnedProcessController? = nil,
         discover: @escaping () -> USBMicrophone? = { QuadCastUSBDetector.findOriginalQuadCastS() },
         resolveBackend: @escaping () -> String? = {
             ["/opt/homebrew/bin/quadcastrgb", "/usr/local/bin/quadcastrgb"].first { FileManager.default.isExecutableFile(atPath: $0) }
         }, monitor: Bool = true, settleDelay: UInt64 = 700_000_000) {
        self.settleDelay = settleDelay
        self.defaults = defaults; self.runner = runner ?? OwnedProcessController(); self.discover = discover; self.resolveBackend = resolveBackend
        restoreAfterReconnect = defaults.bool(forKey: "QuadCastStudio.RestoreAfterReconnect")
        if let data = defaults.data(forKey: lastKey), let config = try? JSONDecoder().decode(LightingConfiguration.self, from: data), (try? config.arguments()) != nil { lastApplied = config }
        self.runner.onOutput = { [weak self] text in
            guard let self else { return }
            self.lastOutput = String((self.lastOutput + text).suffix(3000))
        }
        self.runner.onUnexpectedExit = { [weak self] status in
            guard let self else { return }
            self.generation += 1
            self.lastError = "QuadcastRGB exited (status \(status)). No automatic retry was made. Check USB and stop any Terminal controller with Control+C, then apply again."
            self.state = self.microphone == nil ? .disconnected : .error
        }
        refreshConnection()
        if monitor {
            Timer.publish(every: 2.5, on: .main, in: .common).autoconnect().sink { [weak self] _ in self?.refreshConnection() }.store(in: &subscriptions)
            NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification).sink { [weak self] _ in self?.prepareForSleep() }.store(in: &subscriptions)
            NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification).sink { [weak self] _ in self?.wake() }.store(in: &subscriptions)
        }
    }
    var canApply: Bool { microphone != nil && backendPath != nil && !busy && !sleeping && !quitting }
    var ownedPID: Int32? { runner.pid }
    var diagnostics: String {
        """
        QuadCast Studio 0.2 — Local Diagnostics
        USB: \(microphone.map { "\($0.name) [\($0.identifier)] registry \($0.registryID)" } ?? "Not detected")
        Backend: \(backendPath ?? "Not installed at an allowed path")
        Status: \(state.label)
        Owned PID: \(runner.pid.map(String.init) ?? "None")
        Owned process running: \(runner.isRunning)
        Transition in progress: \(busy)
        Sleeping: \(sleeping)
        Restore after reconnect: \(restoreAfterReconnect)
        Last attempt: \(lastAttempt?.formatted() ?? "Never")
        Arguments: \(lastCommand)
        Error: \(lastError ?? "None")
        Output (last 3000 characters): \(lastOutput.isEmpty ? "None" : lastOutput)

        Requested lighting only; no RGB state readback or audio capture.
        Reported Terminal test: QuadcastRGB 1.0.5 changed original-S RGB.
        App hardware verification applies only to a user-confirmed current session.
        """
    }
    func refreshConnection() {
        guard !quitting else { return }
        let detected = discover()
        let latest = detected?.isSupported == true ? detected : nil
        let backend = resolveBackend()
        let changed = latest != microphone || backend != backendPath
        if changed {
            if microphone != nil, lastApplied != nil { restorePending = restoreAfterReconnect }
            microphone = latest; backendPath = backend
            generation += 1; recoveryNeeded = true
            lastError = nil; lastOutput = ""
            state = latest == nil ? .disconnected : (backend == nil ? .missingBackend : .ready)
            reconcile()
        } else if microphone == nil { state = .disconnected }
        else if backendPath == nil { state = .missingBackend }
    }
    private func reconcile() {
        guard recoveryNeeded, !busy, !quitting else { return }
        recoveryNeeded = false
        let restore = restorePending && restoreAfterReconnect && !sleeping && microphone != nil && backendPath != nil
        if restore { restorePending = false }
        if restore, let config = lastApplied { apply(config); return }
        busy = true
        operation = Task { [weak self] in
            guard let self else { return }
            defer { self.finishOperation() }
            do {
                try await self.runner.stop()
                self.state = self.microphone == nil ? .disconnected : (self.backendPath == nil ? .missingBackend : .ready)
            } catch { self.lastError = error.localizedDescription; self.state = .error }
        }
    }
    private func finishOperation() {
        busy = false; operation = nil
        reconcile()
    }
    func apply(_ configuration: LightingConfiguration) {
        guard canApply else { return }
        let arguments: [String]
        do { arguments = try configuration.arguments() }
        catch { lastError = error.localizedDescription; state = .error; return }
        busy = true; state = .applying; lastError = nil; lastOutput = ""
        generation += 1
        let requestGeneration = generation
        let requestedDevice = microphone
        let executable = backendPath!
        lastAttempt = Date(); lastCommand = arguments.joined(separator: " ")
        operation = Task { [weak self] in
            guard let self else { return }
            defer { self.finishOperation() }
            do {
                try await self.runner.stop()
                // Re-enumerate after the asynchronous shutdown; no stale-device restart.
                self.refreshConnection()
                guard self.generation == requestGeneration, self.microphone == requestedDevice,
                      self.backendPath == executable, !self.sleeping, !self.quitting else { return }
                try self.runner.start(executable: executable, arguments: arguments)
                try await Task.sleep(nanoseconds: self.settleDelay)
                guard self.generation == requestGeneration, self.runner.isRunning else { return }
                self.lastApplied = configuration
                if let data = try? JSONEncoder().encode(configuration) { self.defaults.set(data, forKey: self.lastKey) }
                self.state = .active
            } catch { self.lastError = error.localizedDescription; self.state = self.microphone == nil ? .disconnected : .error }
        }
    }
    func stopController() {
        generation += 1; restorePending = false; recoveryNeeded = true
        reconcile()
    }
    func prepareForSleep() {
        sleeping = true; generation += 1
        restorePending = restoreAfterReconnect && lastApplied != nil
        recoveryNeeded = true; reconcile()
    }
    func wake() {
        sleeping = false
        refreshConnection()
        recoveryNeeded = true; reconcile()
    }
    func confirmHardwareChanged() {
        guard state == .active, runner.isRunning, microphone != nil else { return }
        state = .verified
    }
    func reportNoChange() {
        guard state == .active || state == .verified else { return }
        lastError = "No visible RGB change. Check physical mute indication and stop competing Terminal controllers with Control+C."
        state = .error
    }
    /// Called by the app delegate before agreeing to quit. A timeout keeps the app open.
    func shutdown() async -> Bool {
        quitting = true; generation += 1; recoveryNeeded = false; restorePending = false
        if let operation { await operation.value }
        do { try await runner.stop(); return true }
        catch { lastError = error.localizedDescription; state = .error; quitting = false; return false }
    }
}
