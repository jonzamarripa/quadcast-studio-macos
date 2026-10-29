import Foundation

@MainActor
public protocol OwnedChild: AnyObject {
    var isRunning: Bool { get }
    var pid: Int32 { get }
    var status: Int32 { get }
    var onExit: (() -> Void)? { get set }
    var onOutput: ((String) -> Void)? { get set }
    func start(executable: String, arguments: [String]) throws
    func terminate()
    func closeOutput()
}

/// Holds an actual Process reference; never looks up, signals, or adopts external PIDs.
@MainActor
public final class FoundationChild: OwnedChild {
    private let process = Process()
    private let pipe = Pipe()
    public var onExit: (() -> Void)?
    public var onOutput: ((String) -> Void)?
    public var isRunning: Bool { process.isRunning }
    public var pid: Int32 { process.processIdentifier }
    public var status: Int32 { process.terminationStatus }
    public init() {}
    public func start(executable: String, arguments: [String]) throws {
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler = nil; return }
            let text = String(decoding: data, as: UTF8.self)
            Task { @MainActor [weak self] in self?.onOutput?(text) }
        }
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in self?.onExit?() }
        }
        do { try process.run() } catch { closeOutput(); throw error }
    }
    public func terminate() { if process.isRunning { process.terminate() } }
    public func closeOutput() {
        pipe.fileHandleForReading.readabilityHandler = nil
        try? pipe.fileHandleForReading.close()
        try? pipe.fileHandleForWriting.close()
    }
}

public enum ProcessLifecycleError: Error, LocalizedError {
    case busy, timeout
    public var errorDescription: String? {
        switch self {
        case .busy: return "A controller transition is already in progress."
        case .timeout: return "The app-owned controller did not stop. No replacement was launched. Retry Stop controller before quitting."
        }
    }
}

@MainActor
public final class OwnedProcessController {
    private let factory: @MainActor () -> any OwnedChild
    private var child: (any OwnedChild)?
    private var expectedStop = false
    public private(set) var transitioning = false
    public var onUnexpectedExit: ((Int32) -> Void)?
    public var onOutput: ((String) -> Void)?
    public var isRunning: Bool { child?.isRunning == true }
    public var pid: Int32? { child?.pid }
    public init(factory: (@MainActor () -> any OwnedChild)? = nil) { self.factory = factory ?? { FoundationChild() } }

    public func start(executable: String, arguments: [String]) throws {
        guard child == nil, !transitioning else { throw ProcessLifecycleError.busy }
        let next = factory()
        next.onOutput = { [weak self, weak next] text in
            guard let self, let next, self.child === next else { return }
            self.onOutput?(text)
        }
        next.onExit = { [weak self, weak next] in
            guard let self, let next, self.child === next else { return }
            let status = next.status
            next.closeOutput()
            self.child = nil
            if !self.expectedStop { self.onUnexpectedExit?(status) }
        }
        // Install ownership before launch: even immediate exits remain attributable.
        child = next
        do { try next.start(executable: executable, arguments: arguments) }
        catch { child = nil; next.closeOutput(); throw error }
    }
    /// Retain ownership on timeout so subsequent requests cannot spawn duplicates.
    public func stop(timeout: TimeInterval = 2) async throws {
        guard !transitioning else { throw ProcessLifecycleError.busy }
        guard let current = child else { return }
        transitioning = true; expectedStop = true
        defer { transitioning = false; expectedStop = false }
        if current.isRunning { current.terminate() }
        let deadline = Date().addingTimeInterval(timeout)
        while current.isRunning && Date() < deadline {
            // A cancellation still leaves the owned child tracked and replacement blocked.
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        guard !current.isRunning else { throw ProcessLifecycleError.timeout }
        current.onExit = nil
        current.closeOutput()
        if child === current { child = nil }
    }
}
