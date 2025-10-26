# Testing & Debugging Guide

Complete guide for testing Meditationstimer.

---

## Test Suite Overview

The project includes comprehensive unit tests for critical business logic components.

### Unit Test Files

- `Tests/TwoPhaseTimerEngineTests.swift` – Timer state machine, phase transitions, time calculations (18 test cases)
- `Tests/StreakManagerTests.swift` – Streak calculation, rewards, persistence (15 test cases)
- `Tests/HealthKitManagerTests.swift` – Date calculations, activity filtering, mocks (25+ test cases)
- `Tests/AtemViewTests.swift` – Breathing exercise logic
- `Tests/LiveActivityControllerTests.swift` – Live Activity conflict scenarios

**Total Test Coverage:** 58+ test cases covering core business logic

---

## Setting Up Test Target

**⚠️ Important:** Test files exist in `Tests/` but need to be added to an Xcode test target:

1. Open `Meditationstimer.xcodeproj` in Xcode
2. Go to **File → New → Target**
3. Select **iOS Unit Testing Bundle**
4. Name it `MeditationstimerTests`
5. Add test files from `Tests/` directory to the new target
6. Set the main app target as a test dependency
7. Ensure `@testable import Meditationstimer` is enabled in build settings

---

## Running Tests

### In Xcode

```
Cmd+U (run all tests)
```

Or click the diamond icon next to:
- Test class (runs all tests in class)
- Test method (runs single test)

### From Command Line

**Run all tests:**
```bash
xcodebuild test \
  -project Meditationstimer.xcodeproj \
  -scheme "MeditationstimerTests" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

**Run specific test class:**
```bash
xcodebuild test \
  -project Meditationstimer.xcodeproj \
  -scheme "MeditationstimerTests" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:MeditationstimerTests/StreakManagerTests
```

**Run specific test method:**
```bash
xcodebuild test \
  -project Meditationstimer.xcodeproj \
  -scheme "MeditationstimerTests" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:MeditationstimerTests/StreakManagerTests/testStreakCalculation
```

---

## Test Coverage Areas

| Component | Tests | What's Tested |
|-----------|-------|---------------|
| **TwoPhaseTimerEngine** | 18 | State transitions, timer accuracy, date calculations, edge cases |
| **StreakManager** | 15 | Consecutive days, rewards (7-day intervals), persistence, gaps |
| **HealthKitManager** | 25+ | Month boundaries, leap years, activity filtering, duration calculations |
| **AtemView** | 4 | Phase mapping, duration calculations, preset validation |
| **LiveActivityController** | 1 | Ownership conflicts, force start |

---

## Writing New Tests

### Template for New Test

```swift
import XCTest
@testable import Meditationstimer

final class MyComponentTests: XCTestCase {
    var component: MyComponent!

    override func setUp() {
        super.setUp()
        component = MyComponent()
    }

    override func tearDown() {
        component = nil
        super.tearDown()
    }

    func testSomething() {
        // Arrange
        let input = "test"

        // Act
        let result = component.process(input)

        // Assert
        XCTAssertEqual(result, "expected")
    }
}
```

### Best Practices

- **Arrange-Act-Assert** pattern
- Test one thing per test method
- Use descriptive test names: `testStreakResetsAfterMissingDay`
- Mock external dependencies (HealthKit, UserDefaults)
- Test edge cases (empty data, boundary values, nil inputs)

---

## Debug Logging

Core services include detailed logging:

- `TwoPhaseTimerEngine` – App termination detection, timer state changes
- `LiveActivityController` – Activity lifecycle (start, update, end)
- `HealthKitManager` – HealthKit operations
- `GongPlayer` / `SoundPlayer` – Audio playback status
- `WorkoutsView.SoundPlayer` – Round announcements, speech synthesis

**Enable verbose logging:**
Check console output in Xcode when running on simulator or device.

---

## Preview Support

All views include SwiftUI previews. LiveActivityController detects preview mode and skips actual ActivityKit calls.

**Run previews in Xcode:**
- Canvas panel (Cmd+Option+Enter to toggle)
- Click "Resume" to load preview
- Modify preview code to test different states

---

## Common Testing Scenarios

### Testing Timer State Transitions

```swift
func testPhaseTransition() {
    let engine = TwoPhaseTimerEngine()
    engine.start(phase1Minutes: 1, phase2Minutes: 1)

    // Simulate time passing
    let expectation = XCTestExpectation(description: "Phase transition")
    DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
        XCTAssertTrue(engine.state.isPhase2)
        expectation.fulfill()
    }
    wait(for: [expectation], timeout: 65)
}
```

### Testing HealthKit Integration

Use mock HealthKit store:

```swift
class MockHealthKitStore: HKHealthStore {
    var savedSamples: [HKSample] = []

    override func save(_ object: HKObject, withCompletion completion: @escaping (Bool, Error?) -> Void) {
        savedSamples.append(object as! HKSample)
        completion(true, nil)
    }
}
```

### Testing Streak Calculation

```swift
func testStreakCalculation() {
    let manager = StreakManager()
    // Mock HealthKit data for consecutive days
    // Assert streak count matches expected value
}
```

---

## Debugging Tips

### Timer Not Updating

- Check if app is in foreground (timers only run in foreground)
- Verify `Timer.publish` is connected to `onReceive`
- Check for retain cycles (weak self in closures)

### HealthKit Not Logging

- Verify authorization granted
- Check app source filter
- Ensure minimum duration (2 minutes) met

### Live Activity Not Showing

- iOS 16.1+ required
- Physical device with Dynamic Island or iOS 17.2+ simulator
- Check `ActivityAuthorizationInfo().areActivitiesEnabled`

### Audio Not Playing

- Check audio files are in app bundle
- Verify file extensions (.caf, .wav, .mp3)
- Check volume and audio session configuration
