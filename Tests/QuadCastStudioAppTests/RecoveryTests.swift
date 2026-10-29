import XCTest
import QuadCastStudioCore
@testable import QuadCastStudio

@MainActor private final class Child: OwnedChild {
    var isRunning = false
    var pid: Int32 = 1234
    var status: Int32 = 0
    var onExit: (() -> Void)?
    var onOutput: ((String) -> Void)?
    var starts = 0
    var stops = 0
    func start(executable: String, arguments: [String]) throws { isRunning = true; starts += 1 }
    func terminate() { stops += 1; isRunning = false; onExit?() }
    func closeOutput() {}
    func crash() { status = 1; isRunning = false; onExit?() }
}
final class RecoveryTests: XCTestCase {
    @MainActor private func settled(_ controller: DeviceController) async throws {
        for _ in 0..<100 {
            if !controller.busy { return }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("Controller never settled")
    }
    @MainActor func testReconnectDoesNotReapplyByDefaultAndClearsVerification() async throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let child = Child(), runner = OwnedProcessController(factory: { child })
        var device: USBMicrophone? = USBMicrophone(vendorID: 0x0951, productID: 0x171F, name: "S", registryID: 1)
        let controller = DeviceController(defaults: defaults, runner: runner, discover: { device }, resolveBackend: { "/opt/homebrew/bin/quadcastrgb" }, monitor: false, settleDelay: 1_000_000)
        try await settled(controller)
        XCTAssertFalse(controller.restoreAfterReconnect)
        XCTAssertEqual(child.starts, 0)
        controller.apply(.studioCyan); try await settled(controller)
        XCTAssertEqual(controller.state, .active)
        controller.confirmHardwareChanged(); XCTAssertEqual(controller.state, .verified)
        device = nil; controller.refreshConnection(); try await settled(controller)
        XCTAssertEqual(controller.state, .disconnected); XCTAssertFalse(child.isRunning)
        device = USBMicrophone(vendorID: 0x0951, productID: 0x171F, name: "S", registryID: 2)
        controller.refreshConnection(); try await settled(controller)
        XCTAssertEqual(controller.state, .ready); XCTAssertEqual(child.starts, 1)
        let stopped = await controller.shutdown(); XCTAssertTrue(stopped)
    }
    @MainActor func testOptInReconnectAndSleepWakeRestoreOnce() async throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let child = Child(), runner = OwnedProcessController(factory: { child })
        var device: USBMicrophone? = USBMicrophone(vendorID: 0x03F0, productID: 0x028C, name: "S", registryID: 1)
        let controller = DeviceController(defaults: defaults, runner: runner, discover: { device }, resolveBackend: { "/opt/homebrew/bin/quadcastrgb" }, monitor: false, settleDelay: 1_000_000)
        try await settled(controller)
        controller.restoreAfterReconnect = true
        controller.apply(.sunset); try await settled(controller)
        device = nil; controller.refreshConnection(); try await settled(controller)
        device = USBMicrophone(vendorID: 0x03F0, productID: 0x028C, name: "S", registryID: 2)
        controller.refreshConnection(); try await settled(controller)
        XCTAssertEqual(child.starts, 2); XCTAssertEqual(controller.state, .active)
        controller.refreshConnection(); try await settled(controller); XCTAssertEqual(child.starts, 2)
        controller.prepareForSleep(); try await settled(controller); XCTAssertFalse(child.isRunning)
        controller.wake(); try await settled(controller); XCTAssertEqual(child.starts, 3)
        controller.restoreAfterReconnect = false
        controller.prepareForSleep(); try await settled(controller)
        controller.wake(); try await settled(controller); XCTAssertEqual(child.starts, 3)
        let stopped = await controller.shutdown(); XCTAssertTrue(stopped)
    }
    @MainActor func testDisconnectDuringApplyNeverRestartsStaleCommand() async throws {
        let child = Child(), runner = OwnedProcessController(factory: { child })
        var device: USBMicrophone? = USBMicrophone(vendorID: 0x0951, productID: 0x171F, name: "S", registryID: 1)
        let controller = DeviceController(defaults: UserDefaults(suiteName: UUID().uuidString)!, runner: runner, discover: { device }, resolveBackend: { "/opt/homebrew/bin/quadcastrgb" }, monitor: false, settleDelay: 1_000_000)
        try await settled(controller)
        controller.apply(.studioCyan)
        controller.apply(.onAir) // rapid second apply must not spawn a competitor
        device = nil; controller.refreshConnection()
        try await settled(controller)
        XCTAssertEqual(child.starts, 0); XCTAssertEqual(controller.state, .disconnected)
        let stopped = await controller.shutdown(); XCTAssertTrue(stopped)
    }
    @MainActor func testUnexpectedExitAndUnsupportedDevice() async throws {
        let child = Child(), runner = OwnedProcessController(factory: { child })
        var device = USBMicrophone(vendorID: 0x0951, productID: 0x171F, name: "S", registryID: 1)
        let controller = DeviceController(defaults: UserDefaults(suiteName: UUID().uuidString)!, runner: runner, discover: { device }, resolveBackend: { "/opt/homebrew/bin/quadcastrgb" }, monitor: false, settleDelay: 1_000_000)
        try await settled(controller)
        controller.apply(.studioCyan); try await settled(controller)
        child.crash(); XCTAssertEqual(controller.state, .error); XCTAssertEqual(child.starts, 1)
        device = USBMicrophone(vendorID: 0x03F0, productID: 0x098C, name: "QuadCast S misleading name", registryID: 2)
        controller.refreshConnection(); try await settled(controller)
        XCTAssertFalse(controller.canApply)
        controller.apply(.studioCyan); XCTAssertEqual(child.starts, 1)
        let stopped = await controller.shutdown(); XCTAssertTrue(stopped)
    }
}

extension RecoveryTests {
    @MainActor func testMissingBackendNeverLaunches() async throws {
        let child = Child(), runner = OwnedProcessController(factory: { child })
        let device = USBMicrophone(vendorID: 0x0951, productID: 0x171F, name: "S", registryID: 1)
        let controller = DeviceController(defaults: UserDefaults(suiteName: UUID().uuidString)!, runner: runner, discover: { device }, resolveBackend: { nil }, monitor: false)
        try await settled(controller)
        XCTAssertEqual(controller.state, .missingBackend)
        XCTAssertFalse(controller.canApply)
        controller.apply(.studioCyan)
        XCTAssertEqual(child.starts, 0)
        let stopped = await controller.shutdown(); XCTAssertTrue(stopped)
    }
}

extension RecoveryTests {
    func testExactOriginalSIdentityAllowlist() {
        for (vendor, product) in [(0x0951, 0x171F), (0x03F0, 0x0F8B), (0x03F0, 0x028C), (0x03F0, 0x048C), (0x03F0, 0x068C)] {
            XCTAssertTrue(USBMicrophone(vendorID: vendor, productID: product, name: "", registryID: 1).isSupported)
        }
        for (vendor, product) in [(0x03F0, 0x098C), (0x03F0, 0x09AF), (0x0951, 0x16DF), (0xFFFF, 0x171F), (0x03F0, 0xFFFF)] {
            XCTAssertFalse(USBMicrophone(vendorID: vendor, productID: product, name: "QuadCast S", registryID: 1).isSupported)
        }
    }
}
