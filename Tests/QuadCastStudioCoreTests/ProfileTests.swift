import XCTest
@testable import QuadCastStudioCore
final class ProfileTests: XCTestCase {
    func testLegacyProfilesDecodeWithoutFavorite() throws {
        let id = UUID()
        let data = try JSONSerialization.data(withJSONObject: [["id": id.uuidString, "name": "Legacy", "configuration": ["effect": "Solid", "upperHex": "64E1FF", "lowerHex": "64E1FF", "brightness": 80, "speed": 65]]])
        let profiles = try JSONDecoder().decode([SavedProfile].self, from: data)
        XCTAssertEqual(profiles.first?.id, id)
        XCTAssertEqual(profiles.first?.isFavorite, false)
    }
    func testRoundTrip() throws {
        let profile = SavedProfile(name: "Studio", configuration: .sunset, isFavorite: true)
        XCTAssertEqual(try ProfileDocument.decode(ProfileDocument(profiles: [profile]).encoded()), [profile])
    }
    func testRejectsInvalidDocuments() throws {
        let profile = SavedProfile(name: "Studio", configuration: .studioCyan)
        XCTAssertThrowsError(try ProfileDocument(profiles: [profile], version: 2).encoded())
        XCTAssertThrowsError(try ProfileDocument(profiles: [profile, profile]).encoded())
        XCTAssertThrowsError(try ProfileDocument.checkedName(" \n "))
        XCTAssertThrowsError(try ProfileDocument.checkedName("a\u{0000}b"))
        XCTAssertThrowsError(try ProfileDocument.checkedName(String(repeating: "a", count: 61)))
        XCTAssertThrowsError(try ProfileDocument.decode(Data(repeating: 0, count: ProfileDocument.maximumBytes + 1)))
        XCTAssertThrowsError(try ProfileDocument.decode(Data("{}".utf8)))
        var off = SavedProfile(name: "Bad off", configuration: .lightsOff)
        off.configuration.upperHex = "invalid"
        XCTAssertThrowsError(try ProfileDocument(profiles: [off]).encoded())
        XCTAssertThrowsError(try LightingConfiguration.checkedHex("64#E1FF"))
    }
    func testMergeNeverOverwrites() throws {
        let original = SavedProfile(name: "Studio", configuration: .studioCyan)
        let result = try ProfileDocument.merging([original], into: [original])
        XCTAssertEqual(result[0], original)
        XCTAssertNotEqual(result[1].id, original.id)
        XCTAssertEqual(result[1].name, "Studio (2)")
    }
}

@MainActor
private final class FakeChild: OwnedChild {
    var isRunning = false
    var pid: Int32 = 123
    var status: Int32 = 0
    var onExit: (() -> Void)?
    var onOutput: ((String) -> Void)?
    var terminates = true
    var terminationCount = 0
    var startCount = 0
    var failStart = false
    func start(executable: String, arguments: [String]) throws { if failStart { throw NSError(domain: "FakeLaunch", code: 1) }; isRunning = true; startCount += 1 }
    func terminate() { terminationCount += 1; if terminates { isRunning = false; onExit?() } }
    func closeOutput() {}
    func crash() { isRunning = false; status = 4; onExit?() }
}
final class ProcessLifecycleTests: XCTestCase {
    @MainActor func testOnlyOwnedChildAndNoDuplicate() async throws {
        let owned = FakeChild(), unrelated = FakeChild()
        let runner = OwnedProcessController(factory: { owned })
        try runner.start(executable: "/allowed", arguments: [])
        XCTAssertThrowsError(try runner.start(executable: "/allowed", arguments: []))
        try await runner.stop()
        XCTAssertEqual(owned.terminationCount, 1)
        XCTAssertEqual(unrelated.terminationCount, 0)
        XCTAssertNil(runner.pid)
        try runner.start(executable: "/allowed", arguments: [])
        XCTAssertEqual(owned.startCount, 2)
        try await runner.stop()
    }
    @MainActor func testTimeoutRetainsOwnership() async throws {
        let child = FakeChild(); child.terminates = false
        let runner = OwnedProcessController(factory: { child })
        try runner.start(executable: "/allowed", arguments: [])
        do { try await runner.stop(timeout: 0.01); XCTFail("Should time out") } catch {}
        XCTAssertEqual(runner.pid, 123)
        XCTAssertThrowsError(try runner.start(executable: "/allowed", arguments: []))
        child.terminates = true
        try await runner.stop()
        XCTAssertNil(runner.pid)
    }
    @MainActor func testUnexpectedExitReportedButExpectedStopIsQuiet() async throws {
        let child = FakeChild()
        let runner = OwnedProcessController(factory: { child })
        var exits: [Int32] = []
        runner.onUnexpectedExit = { exits.append($0) }
        try runner.start(executable: "/allowed", arguments: [])
        child.crash()
        XCTAssertEqual(exits, [4]); XCTAssertNil(runner.pid)
        try runner.start(executable: "/allowed", arguments: [])
        try await runner.stop()
        XCTAssertEqual(exits.count, 1)
    }
}

final class ProfileStoreTests: XCTestCase {
    @MainActor func testCRUDPersistenceAndAtomicImportRejection() throws {
        let suite = "QuadCastTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ProfileStore(defaults: defaults)
        try store.save(name: "Original", configuration: .sunset)
        let id = try XCTUnwrap(store.saved.first?.id)
        try store.rename(id: id, to: "Renamed")
        try store.toggleFavorite(id: id)
        try store.duplicate(id: id)
        XCTAssertEqual(store.saved.count, 2)
        XCTAssertEqual(store.saved[0].name, "Renamed")
        XCTAssertTrue(store.saved[0].isFavorite)
        let before = store.saved
        XCTAssertThrowsError(try store.importJSON(Data("{invalid}".utf8)))
        XCTAssertEqual(store.saved, before)
        XCTAssertEqual(ProfileStore(defaults: defaults).saved, before)
        try store.delete(id: id); XCTAssertEqual(store.saved.count, 1)
    }
    @MainActor func testCorruptStorageIsNotOverwritten() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let data = Data("broken".utf8)
        defaults.set(data, forKey: "QuadCastStudio.CustomProfiles.v1")
        let store = ProfileStore(defaults: defaults)
        XCTAssertNotNil(store.loadError)
        XCTAssertThrowsError(try store.save(name: "New", configuration: .studioCyan))
        XCTAssertEqual(defaults.data(forKey: "QuadCastStudio.CustomProfiles.v1"), data)
    }
}

extension ProcessLifecycleTests {
    @MainActor func testRealFoundationChildCanBeStoppedWithoutHardware() async throws {
        let runner = OwnedProcessController()
        try runner.start(executable: "/bin/sleep", arguments: ["30"])
        XCTAssertTrue(runner.isRunning)
        XCTAssertNotNil(runner.pid)
        try await runner.stop()
        XCTAssertFalse(runner.isRunning)
        XCTAssertNil(runner.pid)
    }
}

extension ProcessLifecycleTests {
    @MainActor func testLaunchFailureDoesNotRetainPhantomOwnership() throws {
        let child = FakeChild(); child.failStart = true
        let runner = OwnedProcessController(factory: { child })
        XCTAssertThrowsError(try runner.start(executable: "/allowed", arguments: []))
        XCTAssertNil(runner.pid)
        XCTAssertFalse(runner.isRunning)
    }
    @MainActor func testCancelledStopRetainsOwnershipUntilCleanup() async throws {
        let child = FakeChild(); child.terminates = false
        let runner = OwnedProcessController(factory: { child })
        try runner.start(executable: "/allowed", arguments: [])
        let stopping = Task { try await runner.stop() }
        try await Task.sleep(nanoseconds: 5_000_000)
        stopping.cancel()
        do { try await stopping.value; XCTFail("Should cancel") } catch {}
        XCTAssertEqual(runner.pid, 123)
        XCTAssertThrowsError(try runner.start(executable: "/allowed", arguments: []))
        child.terminates = true
        try await runner.stop()
        XCTAssertNil(runner.pid)
    }
}
