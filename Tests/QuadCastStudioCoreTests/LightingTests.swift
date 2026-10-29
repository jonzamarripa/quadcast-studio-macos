import XCTest
@testable import QuadCastStudioCore

final class LightingTests: XCTestCase {
    func testOriginalVerifiedCyanCommand() throws {
        let args = try LightingConfiguration.studioCyan.arguments()
        XCTAssertEqual(args, ["-u", "-b", "80", "solid", "64E1FF", "-l", "-b", "80", "solid", "64E1FF"])
    }

    func testIndependentZones() throws {
        let args = try LightingConfiguration.sunset.arguments()
        XCTAssertTrue(args.contains("F38D37"))
        XCTAssertTrue(args.contains("AD44EA"))
    }

    func testOffDoesNotRequireAColor() throws {
        let config = LightingConfiguration(effect: .off, upperHex: "INVALID", lowerHex: "INVALID")
        XCTAssertEqual(try config.arguments(), ["solid", "0"])
    }

    func testColorRejectsShellMetacharacters() {
        XCTAssertThrowsError(try LightingConfiguration.checkedHex("64E1FF;rm -rf ~"))
        XCTAssertThrowsError(try LightingConfiguration.checkedHex("nope"))
        XCTAssertNoThrow(try LightingConfiguration.checkedHex("#64e1ff"))
    }

    func testBounds() {
        XCTAssertThrowsError(try LightingConfiguration(effect: .solid, upperHex: "64E1FF", lowerHex: "64E1FF", brightness: 101).arguments())
        XCTAssertThrowsError(try LightingConfiguration(effect: .pulse, upperHex: "64E1FF", lowerHex: "64E1FF", speed: -1).arguments())
    }

    func testDynamicEffectsUseDocumentedModes() throws {
        let config = LightingConfiguration(effect: .wave, upperHex: "64E1FF", lowerHex: "AD44EA", speed: 35)
        let args = try config.arguments()
        XCTAssertEqual(args, ["-u", "-b", "80", "-s", "35", "wave", "-l", "-b", "80", "-s", "35", "wave"])
    }
}
