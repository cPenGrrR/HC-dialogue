import XCTest
@testable import HumanDialogueClient

final class HumanDialogueClientTests: XCTestCase {
    func testServerConfigDefaultValues() {
        let config = ServerConfig.default
        XCTAssertFalse(config.baseURL.isEmpty)
        XCTAssertFalse(config.webSocketURL.isEmpty)
        XCTAssertFalse(config.rtcRoomId.isEmpty)
    }
}
