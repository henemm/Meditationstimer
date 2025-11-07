# Release v2.7.0 - Workout Programs & Exercise Database

**Release Date:** November 7, 2025
**Type:** Minor Release

---

## 🚀 Major New Features

### Workout Programs Feature
- **HIIT Workout Presets:** Comprehensive library of pre-configured HIIT workout programs
- **Exercise Database:** 43 documented exercises with detailed instructions, proper form guidance, and safety notes
- **Interactive Exercise Info:** Tap (i) icons to view exercise details, alternatives, and common mistakes
- **Bilateral Exercise Support:** Exercises automatically split into left/right sides for balanced training
- **Pause & Resume:** Full pause functionality with visual feedback and workout state preservation
- **Calendar Integration:** Day detail sheet shows workout history with exercise-specific breakdowns

### Enhanced Audio Experience
- **Separate Background Sound Controls:** Independent activation for "Offen" (meditation) and "Atem" (breathing)
- **Centralized Sound Picker:** Single sound selection with per-tab toggles for cleaner UX
- **Improved Workout Audio:** Enhanced auftakt (start) sound scheduling after pause/resume

### NoAlc Tracking Improvements
- **Calendar Integration:** NoAlc entries now visible in day detail sheet alongside meditation/workout data
- **Smart Reminder Fixes:** NoAlc reminders can be permanently deleted and correctly cancel after logging

---

## 🎨 User Interface Improvements

### CalendarView Modernization
- Refactored to use modern NavigationView pattern
- Standard iOS UI components for better consistency
- Improved day detail navigation

### Background Sounds UI Redesign
- Central ambient sound picker (White Noise, Rain, Ocean Waves, Forest)
- Two toggle switches: "Für Offen aktivieren" and "Für Atem aktivieren"
- Clearer visual hierarchy and simplified settings flow

### Workout Program UI Polish
- During REST phase, only show next exercise (removed redundant current exercise display)
- Info buttons remain visible during pause for easy reference
- Larger touch targets for (i) icons with fixed infinite loop bug
- Removed confusing "Fertig" button and ProgressView from Frei (custom) workout completion

---

## 🐛 Bug Fixes

### Critical Fixes
1. **NoAlc Reminder Deletion:** Reminders can now be permanently removed without auto-recreation
2. **HealthKit Background Logging:** Workout data now saves correctly even when app is backgrounded
3. **Smart Reminder Cancellation:** NoAlc reminders properly cancel after activity is logged

### Workout Program Fixes
4. **REST Phase Display:** Shows only next exercise during rest (no more duplicate current exercise)
5. **Pause Info Button:** Exercise info remains accessible when workout is paused
6. **Auftakt Sound Recovery:** Start sound correctly schedules after resuming from pause
7. **Touch Target Fixes:** (i) icon infinite loop resolved, touch areas enlarged for better accessibility

### Audio Fixes
8. **Frei Workout Completion:** Removed non-functional UI elements from custom workout end screen

---

## 📝 Documentation Updates

- Removed completed "Hintergrundsounds" feature from ACTIVE-roadmap.md (Feature 2 completed)
- Updated exercise database with comprehensive form guidance and safety notes

---

## 🔧 Technical Improvements

- Split bilateral exercises automatically maintain left/right balance
- Improved HealthKit workout energy burn calculations
- Enhanced audio player state management for pause/resume scenarios
- Correct breath preset recommended usage mapping

---

## 📊 Statistics

- **22 commits** since v2.6.0
- **8 new features** added
- **8 bugs** fixed
- **43 exercises** documented
- **Multiple UI components** modernized

---

## 🎯 Migration Notes

### For Users
- Background sound settings have moved to a centralized picker with per-tab toggles
- NoAlc reminders deleted in previous versions will NOT auto-recreate
- Workout programs now show cleaner UI during rest phases

### For Developers
- CalendarView now uses NavigationView instead of legacy navigation patterns
- Background sound activation split into `ambientSoundOffenEnabled` and `ambientSoundAtemEnabled` AppStorage keys
- Exercise database available via `ExerciseDatabase.exercises` static property

---

## 🔮 What's Next

See [ACTIVE-roadmap.md](DOCS/ACTIVE-roadmap.md) for upcoming features.

---

**Full Changelog:** [v2.6.0...v2.7.0](https://github.com/henemm/Meditationstimer/compare/v2.6.0...v2.7.0)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
