# Unit Testing Standards

## Automated Testing Protocol

**MANDATORY:** Run tests before every commit that touches business logic.

## When to Run Tests

| Scenario | Required |
|----------|----------|
| Changes to Services/ | ALWAYS |
| Changes to Models/ | ALWAYS |
| Fixing deprecated APIs | ALWAYS |
| Refactoring | ALWAYS |
| Pure UI changes | Recommended |

## How to Run Tests

```bash
xcodebuild test \
  -project Meditationstimer.xcodeproj \
  -scheme "MeditationstimerTests" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## Expected Results

- **66 passing tests** (current count)
- Test files in `Tests/`:
  - `StreakManagerTests.swift` (14 tests)
  - `HealthKitManagerTests.swift` (24 tests)
  - `NoAlcManagerTests.swift` (10 tests)
  - `SmartReminderEngineTests.swift` (15 tests)
  - `MockHealthKitManagerTests.swift` (2 tests)
  - `LeanHealthTimerTests.swift` (1 test)
- Build + Test time: ~30-60 seconds

## Zero Tolerance Policy

**If tests fail:**
1. DO NOT commit broken code
2. Fix the regression immediately
3. Re-run tests until green
4. Only then proceed with commit

## Test Coverage Areas

- **StreakManager:** Streak calculation, reward progression
- **HealthKitManager:** Data fetching, filtering, logging
- **NoAlcManager:** Streak logic, Easy/Steady day handling
- **SmartReminderEngine:** Notification scheduling

## Writing New Tests

When adding new business logic:
1. Write test FIRST (Test-Driven Development)
2. Test edge cases explicitly
3. Use descriptive test names
4. Keep tests independent (no shared state)
