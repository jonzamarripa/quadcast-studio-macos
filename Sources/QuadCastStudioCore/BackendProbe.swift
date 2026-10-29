import Foundation

public enum BackendCheckError: Error, LocalizedError {
    case unsupportedVersion, failed, timeout
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion: return "Unsupported QuadcastRGB version. This release requires the separately installed Homebrew QuadcastRGB 1.0.5. Check quadcastrgb --version; nothing is installed automatically."
        case .failed: return "QuadcastRGB could not complete its read-only version check. Check the Homebrew installation and diagnostics."
        case .timeout: return "QuadcastRGB version check timed out. No lighting command was sent."
        }
    }
}

/// Read-only --version preflight, separate from the long-lived lighting process.
@MainActor
public final class BackendProbe {
    private let runner: OwnedProcessController
    private var output = ""
    private var exitStatus: Int32?
    public init(runner: OwnedProcessController? = nil) { self.runner = runner ?? OwnedProcessController() }
    public static func supportedVersion(in output: String) throws -> String {
        guard output.trimmingCharacters(in: .whitespacesAndNewlines) == "quadcastrgb version 1.0.5" else { throw BackendCheckError.unsupportedVersion }
        return "1.0.5"
    }
    public func check(executable: String, timeout: TimeInterval = 2) async throws -> String {
        try await runner.stop()
        output = ""; exitStatus = nil
        runner.onOutput = { [weak self] text in
            guard let self else { return }; self.output = String((self.output + text).prefix(4096))
        }
        runner.onUnexpectedExit = { [weak self] status in self?.exitStatus = status }
        try runner.start(executable: executable, arguments: ["--version"])
        let deadline = Date().addingTimeInterval(timeout)
        while exitStatus == nil && Date() < deadline { try await Task.sleep(nanoseconds: 25_000_000) }
        guard let status = exitStatus else {
            try await runner.stop()
            throw BackendCheckError.timeout
        }
        guard status == 0 else { throw BackendCheckError.failed }
        // Output and termination notifications arrive independently on the main actor.
        try await Task.sleep(nanoseconds: 25_000_000)
        return try Self.supportedVersion(in: output)
    }
    public func stop() async throws { try await runner.stop() }
}

public enum DiagnosticsRedaction {
    public static func text(_ value: String, home: String = NSHomeDirectory()) -> String {
        guard !home.isEmpty, home != "/" else { return value }
        return value.replacingOccurrences(of: home, with: "~")
    }
}
