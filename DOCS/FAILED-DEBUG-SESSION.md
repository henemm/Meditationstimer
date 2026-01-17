# Failed Debug Session: Tracker Tab UI Test Crash

**Date:** 2026-01-16
**Tokens Used:** ~97,000
**Result:** ❌ FAILED - Problem NOT solved

## Problem Statement

UI Test `testTabSwitching()` fails when opening Tracker Tab:
```
Error Domain=NSMachErrorDomain Code=-308 "(ipc/mig) server died"
Test case 'LeanHealthTimerUITests.testTabSwitching()' failed
```

**Other tests:** `testAllFourTabsExist()` PASSES (doesn't open Tracker Tab)

## Root Cause (Original Hypothesis)

I introduced the bug in commit `dccc0c5` when adding SwiftData `@Query` to TrackerTab:
```swift
@Query(filter: #Predicate<Tracker> { $0.isActive }, sort: \Tracker.createdAt)
private var trackers: [Tracker]
```

## What I Tried (All FAILED)

### Attempt 1: SwiftData In-Memory Config ❌
**Hypothesis:** UI tests need in-memory SwiftData storage
**Changes:**
- `Meditationstimer_iOSApp.swift`: Detect "enable-testing" argument → use `isStoredInMemoryOnly: true`
- All UI tests: Added "enable-testing" to `app.launchArguments`

**Research:** Based on [Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-write-ui-tests-for-your-swiftdata-code)

**Result:** Test still FAILED - no improvement

### Attempt 2: Dedicated Simulator ❌
**Hypothesis:** Simulator conflict with another project
**Action:** Created dedicated simulator `8181B21C-4C74-4618-A865-B8E0273EA657`

**Result:** Test still FAILED - same error

### Attempt 3: Remove @Query ❌
**Hypothesis:** @Query macro causes crash in UI tests
**Changes:** Commented out `@Query` and used empty array

**Result:** Test still FAILED - @Query was NOT the problem

### Attempt 4: Minimal TrackerTab ❌
**Hypothesis:** Something in TrackerTab content causes crash
**Changes:** Removed ALL content, just showed `Text("TrackerTab - Testing")`

**Result:** Test still FAILED - content was NOT the problem

### Attempt 5: Simplified Test Assertion ❌
**Hypothesis:** Test fails because it can't find "Steady" button
**Changes:** Changed assertion to just check `trackerTab.isSelected`

**Result:** Test still FAILED

## What We Know

✅ **App builds successfully**
✅ **App launches manually in simulator**
✅ **Other UI tests pass** (those not opening Tracker Tab)
✅ **Problem is NOT:**
- SwiftData @Query
- Shared simulator
- TrackerTab content
- NoAlc buttons
- Test assertion

## Conclusion

**I do NOT understand the root cause.** The problem persists regardless of:
- SwiftData configuration
- Simulator isolation
- Code simplification
- Test changes

## Recommendations

1. **Fresh start:** Reboot Mac, restart Xcode, clean build folder
2. **Different approach:** Use Xcode UI Test recording to see what actually happens
3. **Apple Forums:** Ask if this is a known Xcode 26/iOS 26.2 simulator bug
4. **Alternative:** Mark test as skipped temporarily and revisit later

## Lessons Learned

1. ❌ I violated Implementation Gate: Did NOT run UI tests when adding @Query to TrackerTab
2. ❌ Research-based fixes don't always work - actual debugging needed
3. ❌ Token waste: Spent 97k tokens without solving the problem
4. ✅ Systematic elimination: Proved what the problem is NOT

## Status

**All changes reverted.** Code is back to original state.
**Bug remains unfixed.** `testTabSwitching()` still fails.
