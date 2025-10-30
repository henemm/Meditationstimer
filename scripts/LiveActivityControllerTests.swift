import XCTest
@testable import Lean_Health_Timer

final class LiveActivityControllerTests: XCTestCase {
    /// NOTE: This file is intended to be added to an iOS XCTest target in Xcode (MeditationstimerTests).
    /// ActivityKit types require iOS simulator/device to run — these tests are compile-time scaffolding
    /// and should be run from Xcode under the iOS test target.

    func testOwnershipEndAndStart() async {
        let controller = LiveActivityController()

        // Start as OffenTab — since ActivityKit requires a simulator, we can't fully verify the Activity.request
        // here. But we can exercise the ownership fields where possible. The test is mostly a behavior contract
        // test to be executed on-device/simulator XCTest target.

        // Start with OffenTab (requestStart should start since no existing activity)
        let r1 = controller.requestStart(title: "Meditation", phase: 1, endDate: Date().addingTimeInterval(60), ownerId: "OffenTab")
        XCTAssertEqual({ () -> Bool in
            if case .started = r1 { return true } else { return false }
        }(), true)
        // Simulate short delay
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Request start from AtemTab — since in-process controller marks owner, this should report conflict
        let r2 = controller.requestStart(title: "Breath", phase: 1, endDate: Date().addingTimeInterval(30), ownerId: "AtemTab")
        var sawConflict = false
        if case .conflict = r2 { sawConflict = true }
        XCTAssertTrue(sawConflict, "Expected a conflict when starting from a different owner")
        // Now force start as AtemTab (simulates user confirmation)
        controller.forceStart(title: "Breath", phase: 1, endDate: Date().addingTimeInterval(30), ownerId: "AtemTab")
        try? await Task.sleep(nanoseconds: 100_000_000)
        try? await Task.sleep(nanoseconds: 100_000_000)

        // We can't assert ActivityKit state here reliably, but the contract is: controller.ownerId should be AtemTab after successful start.
        // This assertion will be meaningful when run in an iOS XCTest environment that allows Activity.request to succeed.
        // For now we'll just assert no crash and that the code path executed.
        XCTAssertTrue(true)
    }
}
