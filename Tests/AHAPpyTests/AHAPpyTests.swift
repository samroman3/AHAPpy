import XCTest
@testable import AHAPpy

final class AHAPpyOptionsTests: XCTestCase {
    func testDefaultOptionProfilesDiffer() {
        let sfx = HapticManager.Options.sfxDefaults
        let music = HapticManager.Options.musicDefaults
        XCTAssertNotEqual(sfx.windowDuration, music.windowDuration)
        XCTAssertNotEqual(sfx.transientThreshold, music.transientThreshold)
    }
}
