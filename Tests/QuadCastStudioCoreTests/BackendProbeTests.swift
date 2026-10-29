import XCTest
@testable import QuadCastStudioCore
final class BackendProbeTests: XCTestCase {
    @MainActor func testExactSupportedVersion() throws {
        XCTAssertEqual(try BackendProbe.supportedVersion(in: "quadcastrgb version 1.0.5\n"), "1.0.5")
        for invalid in ["", "quadcastrgb version 1.0.4", "quadcastrgb version 1.0.50", "other version 1.0.5"] {
            XCTAssertThrowsError(try BackendProbe.supportedVersion(in: invalid))
        }
    }
    func testPrivateHomeRedaction() {
        XCTAssertEqual(DiagnosticsRedaction.text("Error at /Users/test/private/file", home: "/Users/test"), "Error at ~/private/file")
        XCTAssertEqual(DiagnosticsRedaction.text("/opt/homebrew/bin/quadcastrgb", home: "/Users/test"), "/opt/homebrew/bin/quadcastrgb")
    }
    @MainActor func testNonCLIExecutableCannotPassPreflight() async throws {
        let probe = BackendProbe()
        do { _ = try await probe.check(executable: "/usr/bin/true"); XCTFail("Not a supported CLI") } catch {}
        try await probe.stop()
    }
}

extension BackendProbeTests {
    @MainActor func testInstalledHomebrewDependencyWhenRequested() async throws {
        guard ProcessInfo.processInfo.environment["QUADCAST_CHECK_INSTALLED_BACKEND"] == "1" else { throw XCTSkip("Opt-in read-only installed dependency check") }
        let path = "/opt/homebrew/bin/quadcastrgb"
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path))
        let probe = BackendProbe()
        for _ in 0..<3 {
            let version = try await probe.check(executable: path)
            XCTAssertEqual(version, "1.0.5")
        }
        try await probe.stop()
    }
}
