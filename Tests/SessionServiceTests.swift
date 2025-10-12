import XCTest
@testable import Meditationstimer

final class SessionServiceTests: XCTestCase {
    func testSessionServiceStartReturnsHandle() {
        let spec = SessionSpec(kind: .atem, presetId: nil, presetName: "Test", ownerId: "TestOwner", startDate: Date(), endDate: Date().addingTimeInterval(30), sessionUUID: UUID())
        let handle = SessionService.shared.start(spec: spec)
        XCTAssertNotNil(handle)
        XCTAssertEqual(handle.sessionUUID, spec.sessionUUID)
        // initial state should be idle until the service processes the start request
        XCTAssertEqual({ () -> Bool in
            if case .idle = handle.state { return true } else { return false }
        }(), true)
    }
}
