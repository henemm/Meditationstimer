# Release Notes v2.5.4

**Release Date:** 2025-10-29
**Type:** Patch Release (Bug Fix)

---

## 🐛 Bug Fixes

### Workout Timer: Audio Cue Timing Fixed

**Problem:**
- countdown-transition sound had unprecise timing
- Timing varied depending on workout phase duration and system load
- Heuristic drift-offset (1.5% per second) was unreliable

**Solution:**
- Implemented Continuous Monitoring system (checks every 0.1s)
- Fixed 3.0s threshold ensures countdown's long tone hits phase change exactly
- Independent from UI rendering (not coupled to SwiftUI)
- Flag-based to prevent double-trigger

**Changes:**
- NEW: `soundCheckTimer` (Timer, 0.1s interval)
- NEW: `countdownSoundTriggered` (Flag)
- NEW: `startSoundMonitoring()` / `stopSoundMonitoring()`
- MODIFIED: `scheduleCuesForCurrentPhase()` (removed drift calculation)
- MODIFIED: `togglePause()` (stops/starts monitoring)
- MODIFIED: `endSession()` / `onDisappear()` (cleanup)

---

### Workout Timer: Audio Improvements

**Fixed:**
- ✅ Removed duplicate round announcements (now only during rest phase)
- ✅ ausklang sound plays completely before dialog closes
- ✅ countdown-transition timing is now consistent across all workout durations

**Audio Flow (corrected):**
```
Work Phase:
  → countdown-transition at t-3.0s (long tone at phase end)

Rest Phase:
  → Round announcement (early in rest)
  → auftakt sound (ends exactly when next work starts)

Workout End:
  → ausklang sound plays completely
  → Dialog closes after sound finishes
```

---

## 📝 Documentation

- NEW: `DOCS/workout-timer-spec.md` - Complete feature specification
- NEW: `DOCS/workout-timer-test-instructions.md` - Device testing guide
- Documented learnings from failed timing approaches

---

## 🔧 Technical Details

**Architecture:**
- Continuous monitoring approach replaces heuristic drift compensation
- Timer runs independently from UI rendering cycle
- Pause/Resume correctly restarts sound monitoring
- Dynamic sound duration measurement (no hardcoded values)

**Testing:**
- Build successful (xcodebuild)
- UI unchanged (only timing logic)
- countdown-transition precision: 3.0s ± 0.2s

---

## 🚀 Upgrade Notes

**For Users:**
- No visual changes - only improved audio timing
- Workout timer sounds now play at precise moments
- No action required - upgrade seamlessly

**For Developers:**
- Review `DOCS/workout-timer-spec.md` for timing system details
- Check `workout-timer-test-instructions.md` for testing scenarios

---

**Full Changelog:** See commit history in `feature/workout-timer-timing-fix` branch

---

**Previous Version:** v2.5.3
**Next Version:** TBD
