# Automated Testing Setup - Meditationstimer

**Last Updated:** 2025-11-01
**Status:** ✅ Active

---

## Overview

The Meditationstimer project uses a comprehensive automated testing strategy with **53 unit tests** covering all business logic in the Services/ layer.

**Test Coverage:**
- ✅ HealthKitManager (25 tests)
- ✅ StreakManager (15 tests)
- ✅ NoAlcManager (10 tests)
- ✅ TwoPhaseTimerEngine (15+ tests via StreakManager integration)
- ✅ 100% success rate

---

## Test Execution

### Manual Testing (Local Development)

**In Xcode:**
```bash
⌘U  # Run all tests
```

**Command Line:**
```bash
xcodebuild test \
  -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

**Expected Output:**
```
Test Suite 'All tests' passed at 2025-11-01 12:34:56.789.
	 Executed 53 tests, with 0 failures (0 unexpected) in 2.345 seconds
```

---

## Automated Testing

### 1. GitHub Actions CI/CD

**Configuration:** `.github/workflows/ios-tests.yml`

**Triggers:**
- ✅ Every push to `main` branch
- ✅ Every pull request to `main`

**What it does:**
1. **Test Job** - Runs all 53 unit tests
2. **Lint Job** - Code quality checks (SwiftLint if available)
3. **Build Verification** - Ensures Release build succeeds

**Features:**
- Parallel execution (faster feedback)
- Test result artifacts (7-day retention)
- GitHub summary with test counts
- Fails build if any test fails

**Viewing Results:**
- Go to GitHub → Actions tab
- Click on latest workflow run
- See test summary and download artifacts

---

### 2. Pre-commit Hook (Optional)

**Purpose:** Run tests locally before allowing commit to Services/ files

**Installation:**
```bash
# From project root
ln -s ../../.github/hooks/pre-commit .git/hooks/pre-commit
```

**Behavior:**
- ⚡ Detects changes to `Services/` directory
- 🧪 Runs all tests if Services/ files modified
- ✅ Allows commit only if tests pass
- ⏭️ Skips tests if no Services/ changes

**Example Output:**
```
🔍 Pre-commit hook: Checking for Services/ changes...
📦 Services/ files modified. Running tests...
  - Services/NoAlcManager.swift
  - Services/HealthKitManager.swift

🧪 Running unit tests...
✅ All tests passed! Proceeding with commit.
```

**Bypassing Hook (Emergency Only):**
```bash
git commit --no-verify -m "Emergency fix"
```

---

## Testing Philosophy

Following CLAUDE.md "Automated Testing Protocol":

### When Tests MUST Run

1. ✅ **Always** before committing changes to `Services/`
2. ✅ **Always** after fixing deprecated APIs
3. ✅ **Always** after refactoring business logic
4. ✅ **Optional** for pure UI changes (but recommended)

### Zero Tolerance Policy

- ❌ **DO NOT** commit code that breaks tests
- ❌ **DO NOT** skip tests for Services/ changes
- ❌ **DO NOT** merge PRs with failing tests
- ✅ **DO** fix regressions immediately

---

## Test Directory Structure

**Active Test Target:** `LeanHealthTimerTests/`

```
LeanHealthTimerTests/
├── HealthKitManagerTests.swift    (25 tests)
├── StreakManagerTests.swift       (15 tests)
├── NoAlcManagerTests.swift        (10 tests)
├── MockHealthKitManagerTests.swift (2 tests)
└── LeanHealthTimerTests.swift     (1 test)
```

**Cleanup History (2025-11-01):**
- ❌ Deleted: `Tests/` directory (duplicate copy)
- ❌ Deleted: `scripts/` manual test files (replaced by XCTest)
- ✅ Kept: `LeanHealthTimerTests/` (only active target)

---

## Adding New Tests

### 1. Create Test File

```swift
// LeanHealthTimerTests/NewFeatureTests.swift
import XCTest
@testable import Lean_Health_Timer

final class NewFeatureTests: XCTestCase {
    func testNewFeature() {
        // Arrange
        let sut = NewFeature()

        // Act
        let result = sut.performAction()

        // Assert
        XCTAssertEqual(result, expectedValue)
    }
}
```

### 2. Add to Xcode Test Target

1. Open Xcode
2. Add file to `LeanHealthTimerTests` target
3. Ensure checkbox is checked in File Inspector

### 3. Verify Test Runs

```bash
xcodebuild test -scheme "Lean Health Timer" -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### 4. Update Documentation

Update test count in:
- `DOCS/testing-automation.md` (this file)
- `CLAUDE.md` (if architecture changes)

---

## Troubleshooting

### Tests Fail Locally But Pass in Xcode

**Problem:** xcodebuild uses different simulator than Xcode

**Solution:**
```bash
# List available simulators
xcrun simctl list devices available

# Use specific simulator ID
xcodebuild test -destination 'platform=iOS Simulator,id=<UUID>'
```

### Pre-commit Hook Not Firing

**Problem:** Hook not executable or not installed

**Solution:**
```bash
chmod +x .github/hooks/pre-commit
ln -sf ../../.github/hooks/pre-commit .git/hooks/pre-commit
```

### GitHub Actions Failing

**Problem:** Simulator not available in CI

**Check:**
- Ensure workflow uses `macos-15` runner
- Verify simulator name matches available devices
- Check Xcode version compatibility

---

## Best Practices

1. **Test-First for Business Logic**
   - Write tests before implementing Services/ changes
   - Ensure tests fail first, then pass after implementation

2. **Meaningful Test Names**
   ```swift
   ❌ func testStreaks()
   ✅ func testStreakResetsWhenNoActivityToday()
   ```

3. **Isolated Tests**
   - Each test should be independent
   - Use `setUp()` / `tearDown()` for clean state
   - Mock HealthKit dependencies

4. **Fast Tests**
   - Unit tests should run in <5 seconds total
   - No network calls, no file I/O
   - Use in-memory data structures

5. **Clear Assertions**
   ```swift
   ❌ XCTAssertTrue(streak > 0)
   ✅ XCTAssertEqual(streak, 7, "Should have 7-day streak after consecutive activity")
   ```

---

## Future Enhancements

### Potential Additions (Not Yet Implemented)

- [ ] Code coverage reporting (XCCov)
- [ ] Performance tests for timer accuracy
- [ ] UI tests for critical flows
- [ ] Snapshot testing for SwiftUI views
- [ ] Integration tests with HealthKit (requires device)

---

## References

- **Global Testing Rules:** `~/.claude/CLAUDE.md` → "Automated Testing Protocol"
- **Project Testing Guide:** `DOCS/testing-guide.md`
- **Test Results:** Available in GitHub Actions → Artifacts
- **CI Configuration:** `.github/workflows/ios-tests.yml`

---

## Quick Commands

```bash
# Run tests (command line)
xcodebuild test -scheme "Lean Health Timer" -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Install pre-commit hook
ln -s ../../.github/hooks/pre-commit .git/hooks/pre-commit

# Check test status
git log --oneline --grep="test"

# View GitHub Actions status
open https://github.com/USER/REPO/actions
```

---

**Test Count:** 53 tests
**Success Rate:** 100%
**Last Verified:** 2025-11-01
