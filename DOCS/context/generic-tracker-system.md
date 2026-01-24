# Context: Generic Tracker System

## Request Summary
User wants the Generic Tracker System fully implemented according to spec at `openspec/specs/features/generic-tracker-system.md`. The spec exists but implementation is incomplete - current code has hardcoded NoAlc instead of using the generic system.

## Problem Analysis

### What Exists (Partial Implementation)
✅ **TrackerModels.swift (Services/)** - COMPLETE
- All Generic Tracker System components implemented
- TrackerLevel, TrackerValueType, SuccessCondition, RewardConfig, DayAssignment, StorageStrategy
- StreakCalculator with forward iteration algorithm
- Tracker @Model with generic properties (levelsData, rewardConfigData, etc.)
- TrackerLog @Model
- TrackerPreset with NoAlc preset

✅ **TrackerManager.swift (Services/)** - COMPLETE
- calculateStreakResult() uses StreakCalculator
- CRUD operations for trackers
- Logging functionality

### What's Missing/Wrong

❌ **TrackerTab.swift** - HARDCODED NOALC
- NoAlc is hardcoded as special case (lines 100-127)
- Uses NoAlcManager.shared instead of generic Tracker system
- Labels are hardcoded: "Steady", "Easy", "Wild"
- Should use generic TrackerRow with LevelSelectionView

❌ **NoAlc Not Using Generic System**
- NoAlcManager.swift is separate implementation
- Should be migrated to use Tracker with levels configuration
- NoAlc should appear in `trackers` Query, not as special case

❌ **Mood Tracker Missing**
- Spec (line 168-174) defines Mood levels preset
- TrackerModels.swift has `TrackerLevel.moodLevels` (line 168-174)
- But no TrackerPreset for Mood in TrackerPreset.all
- User screenshot shows only NoAlc, Mood missing

❌ **Label Localization**
- Screenshot shows: "Kaum", "Überschaubar", "Party"
- Spec says: "Steady", "Easy", "Wild"
- TrackerLevel.labelKey should map to German strings
- Localizable.xcstrings needs entries

## Related Files

| File | Relevance | Status |
|------|-----------|--------|
| `Services/TrackerModels.swift` | Core models - COMPLETE | ✅ Ready |
| `Services/TrackerManager.swift` | Manager - COMPLETE | ✅ Ready |
| `Services/NoAlcManager.swift` | Legacy - needs migration | ❌ Migrate |
| `Meditationstimer iOS/Tabs/TrackerTab.swift` | UI - HARDCODED | ❌ Fix |
| `Meditationstimer iOS/Tracker/LevelSelectionView.swift` | Generic level selector | ✅ Ready |
| `Meditationstimer iOS/Tracker/TrackerRow.swift` | Generic tracker row | ✅ Ready |
| `Meditationstimer iOS/Tracker/AddTrackerSheet.swift` | Add tracker UI | ? Check |
| `Meditationstimer iOS/Localizable.xcstrings` | Translations | ❌ Add |

## Existing Patterns

### Tracker Creation Pattern
```swift
// From TrackerPreset.createTracker()
let tracker = Tracker(name, icon, type, trackingMode, ...)
tracker.levels = levels  // Set generic config
tracker.rewardConfig = rewardConfig
tracker.dayAssignmentRaw = "cutoffHour:18"
context.insert(tracker)
```

### Tracker Display Pattern
```swift
// TrackerTab should use this pattern
@Query(filter: #Predicate<Tracker> { $0.isActive }, sort: \Tracker.createdAt)
private var trackers: [Tracker]

ForEach(trackers) { tracker in
    TrackerRow(tracker: tracker) { /* edit action */ }
}
```

### Level-Based Tracker Logging
```swift
// LevelSelectionView handles level selection
LevelSelectionView(tracker: tracker)
// Calls TrackerManager.logEntry(for: tracker, value: level.id, ...)
```

## Dependencies

### Upstream (What Generic System Uses)
- SwiftData for @Model persistence
- HealthKit for storage strategy `.healthKit()` / `.both()`
- TrackerManager for CRUD + logging
- StreakCalculator for streak computation

### Downstream (What Uses Generic System)
- TrackerTab.swift - main UI
- TrackerRow.swift - individual tracker display
- LevelSelectionView.swift - level selection UI
- AddTrackerSheet.swift - create new trackers
- ErfolgeTab.swift - may show tracker streaks
- CalendarView.swift - may show tracker data

## Existing Specs

**PRIMARY SPEC (TO IMPLEMENT):**
- `openspec/specs/features/generic-tracker-system.md` - **Current spec - Generic Tracker System**

**LEGACY SPECS (TO BE REPLACED):**
- `openspec/specs/features/trackers.md` - **OLD spec - SwiftData Tracker (pre-generic)**
- `openspec/specs/features/noalc-tracker.md` - **OLD spec - NoAlc specific (to be migrated)**

**SUPPORTING SPECS:**
- `openspec/specs/features/smart-reminders.md` - SmartReminder integration
- `openspec/specs/features/streaks-rewards.md` - Reward calculation details
- `.agent-os/standards/healthkit/date-semantics.md` - Forward iteration requirement

## Risks & Considerations

### 🔴 HIGH RISK: Data Migration
- Existing NoAlc HealthKit data must be preserved
- Users may have years of NoAlc logs
- Migration must map old ConsumptionLevel enum to new TrackerLevel IDs
- **Mitigation:** Test migration thoroughly, backup before release

### 🟡 MEDIUM RISK: UI Breaking Changes
- TrackerTab currently has hardcoded NoAlc card
- Removing it may break user muscle memory
- **Mitigation:** Keep visual design similar, just make it data-driven

### 🟡 MEDIUM RISK: Localization
- Spec uses English labels ("Steady", "Easy", "Wild")
- Screenshot shows German labels ("Kaum", "Überschaubar", "Party")
- Need to coordinate with Localizable.xcstrings
- **Mitigation:** Add all labelKeys to localization file

### 🟢 LOW RISK: Streak Calculation
- StreakCalculator already implements spec algorithm
- Forward iteration with reward handling
- Well-tested (StreakManagerTests.swift exists)
- **Mitigation:** Keep existing calculator, just wire it up

## Implementation Plan Overview

### Phase 1: Add Missing Presets
- Add Mood TrackerPreset to TrackerPreset.all
- Add Energy TrackerPreset (optional, per spec line 177-181)
- Add localization keys for all levels

### Phase 2: Migrate TrackerTab UI
- Remove hardcoded NoAlc card
- Use generic TrackerRow for all trackers (including NoAlc)
- Ensure LevelSelectionView handles NoAlc correctly

### Phase 3: NoAlc Data Migration
- Create migration check (first launch after update)
- Read existing HealthKit NoAlc data
- Create Tracker instance with NoAlc preset config
- Migrate SmartReminders (ActivityType.noalc → .tracker(id))
- Preserve streak and rewards state

### Phase 4: Cleanup
- Deprecate NoAlcManager.swift (keep for migration)
- Update ActivityType enum to support .tracker(UUID)
- Update documentation

### Phase 5: Testing
- Unit tests for preset creation
- UI tests for Tracker Tab with multiple trackers
- Migration tests with sample NoAlc data
- Streak calculation tests with new presets

## Questions for Analysis Phase

1. **Migration Strategy:** How to preserve existing NoAlc user data?
2. **Default Trackers:** Should NoAlc/Mood be created by default for new users?
3. **ActivityType Extension:** How to extend ActivityType for SmartReminders?
4. **UI Test Coverage:** What level of UI testing is needed for Tracker Tab?
5. **Localization Keys:** What's the naming convention (e.g., "noalc.steady" vs "Steady")?

---

## Analysis

### Affected Files (with changes)

| File | Change Type | Description | Risk |
|------|-------------|-------------|------|
| **UI Layer** |
| `Meditationstimer iOS/Tabs/TrackerTab.swift` | MODIFY | Remove hardcoded NoAlc card (lines 87-127), use generic TrackerRow for all trackers | LOW |
| `Meditationstimer iOS/NoAlcLogSheet.swift` | DELETE (later) | Deprecated by LevelSelectionView, keep for migration period | LOW |
| `Meditationstimer iOS/Localizable.xcstrings` | MODIFY | Add German translations for level labels | LOW |
| **Service Layer** |
| `Services/TrackerModels.swift` | MODIFY | Add Mood preset to TrackerPreset.all, fix NoAlc labels | LOW |
| `Services/NoAlcManager.swift` | DEPRECATE | Keep for data migration, mark as @available(*, deprecated) | MEDIUM |
| **Migration** |
| `Services/TrackerMigration.swift` | CREATE | New migration manager for NoAlc data | HIGH |
| `Meditationstimer iOS/Meditationstimer_iOSApp.swift` | MODIFY | Add migration check on app launch | MEDIUM |
| **Tests** |
| `LeanHealthTimerTests/NoAlcMigrationTests.swift` | CREATE | Test NoAlc→Tracker migration | HIGH |
| `LeanHealthTimerUITests/LeanHealthTimerUITests.swift` | MODIFY | Update TrackerTab UI tests for generic system | MEDIUM |

### Scope Assessment

- **Files to modify:** 6
- **Files to create:** 2
- **Files to deprecate:** 1
- **Estimated LoC:** +350 / -150 (net +200)
- **Risk Level:** MEDIUM (migration complexity)

### Technical Approach

#### 1. Add Missing Presets (Phase 1)
```swift
// In TrackerModels.swift TrackerPreset.all
TrackerPreset(
    name: "Mood",
    localizedName: "Stimmung",
    icon: "😊",
    type: .good,
    trackingMode: .levels,
    healthKitType: "HKStateOfMind",
    dailyGoal: nil,
    category: .levelBased,
    levels: TrackerLevel.moodLevels,
    rewardConfig: nil,
    dayAssignmentRaw: nil
)
```

#### 2. Fix NoAlc Labels (Phase 1)
Change NoAlc preset labels from English to match screenshot:
- "Steady" → labelKey "NoAlc.Steady" (DE: "Kaum")
- "Easy" → labelKey "NoAlc.Easy" (DE: "Überschaubar")
- "Wild" → labelKey "NoAlc.Wild" (DE: "Party")

#### 3. Remove Hardcoded NoAlc from TrackerTab (Phase 2)
```swift
// DELETE noAlcCard computed property (lines 101-127)
// DELETE noAlcButton() function (lines 56-75)
// DELETE showingNoAlcLog state
// DELETE NoAlcLogSheet() sheet

// Result: All trackers (including NoAlc) rendered via TrackerRow
```

#### 4. Data Migration (Phase 3)
```swift
// New: TrackerMigration.swift
class TrackerMigration {
    func migrateNoAlcIfNeeded(context: ModelContext) async throws {
        // Check if NoAlc Tracker already exists
        let descriptor = FetchDescriptor<Tracker>(
            predicate: #Predicate { $0.name == "NoAlc" }
        )
        if try context.fetch(descriptor).first != nil {
            return // Already migrated
        }

        // 1. Read existing HealthKit NoAlc data
        let noAlcData = try await NoAlcManager.shared.fetchHistoricalData()

        // 2. Create NoAlc Tracker from preset
        let tracker = TrackerPreset.all.first(where: { $0.name == "NoAlc" })!.createTracker()
        context.insert(tracker)

        // 3. Migrate logs
        for (date, level) in noAlcData {
            let log = TrackerLog(
                timestamp: date,
                value: level.rawValue, // 0=steady, 4=easy, 6=wild
                tracker: tracker
            )
            context.insert(log)
        }

        // 4. Migrate streak/rewards state
        // (Recalculated automatically by StreakCalculator)

        try context.save()
    }
}
```

#### 5. Localization (Phase 4)
Add to `Localizable.xcstrings`:
```json
{
  "NoAlc.Steady": {
    "extractionState": "manual",
    "localizations": {
      "de": { "stringUnit": { "state": "translated", "value": "Kaum" } },
      "en": { "stringUnit": { "state": "translated", "value": "Steady" } }
    }
  },
  "NoAlc.Easy": {
    "de": { "stringUnit": { "value": "Überschaubar" } },
    "en": { "stringUnit": { "value": "Easy" } }
  },
  "NoAlc.Wild": {
    "de": { "stringUnit": { "value": "Party" } },
    "en": { "stringUnit": { "value": "Wild" } }
  },
  "Mood.Awful": { ... },
  "Mood.Bad": { ... },
  // ... etc for all mood levels
}
```

### Migration Strategy - Detailed

**First Launch Detection:**
```swift
// In Meditationstimer_iOSApp.swift
.task {
    let migrationKey = "hasRunTrackerMigration_v2.9.0"
    if !UserDefaults.standard.bool(forKey: migrationKey) {
        try? await TrackerMigration.shared.migrateNoAlcIfNeeded(context: modelContext)
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
```

**Backward Compatibility:**
- Keep NoAlcManager.swift during migration period
- Mark as `@available(*, deprecated, message: "Use Tracker with NoAlc preset")`
- NoAlcLogSheet remains functional but hidden from UI

**Data Integrity:**
- All HealthKit NoAlc data is preserved
- Logs are copied (not moved) to Tracker system
- If migration fails, NoAlcManager still works

### Open Questions

- [x] **Q: Should NoAlc be created by default for new users?**
  → A: YES - create NoAlc Tracker on first launch (if no trackers exist)

- [x] **Q: Should Mood be created by default?**
  → A: YES - create both NoAlc + Mood as default trackers

- [ ] **Q: What happens to existing NoAlcLogSheet UI?**
  → A: User confirmation needed - delete or keep as fallback?

- [ ] **Q: Should SmartReminders be migrated?**
  → A: User confirmation needed - requires ActivityType.tracker(UUID) support

### Dependencies Trace

**TrackerTab** depends on:
- `TrackerManager` ← Already supports generic system ✅
- `StreakCalculator` ← Already implements spec algorithm ✅
- `LevelSelectionView` ← Already generic ✅
- `TrackerRow` ← Already supports level-based trackers ✅

**NoAlc Migration** depends on:
- `NoAlcManager.fetchHistoricalData()` ← Need to implement
- `HealthKitManager` ← Existing ✅
- `TrackerMigration` ← New file ⚠️

**Localization** depends on:
- `Localizable.xcstrings` ← Existing file, needs additions ⚠️

### Risk Assessment

🔴 **HIGH RISK: Data Migration**
- **Risk:** Users lose years of NoAlc history
- **Mitigation:**
  - Thorough testing with sample data
  - Keep NoAlcManager as fallback
  - Add migration rollback mechanism

🟡 **MEDIUM RISK: UI Breaking Change**
- **Risk:** Users confused by NoAlc moving to tracker list
- **Mitigation:**
  - Keep NoAlc at top of list (sort order)
  - Add onboarding tooltip "NoAlc is now a tracker"

🟡 **MEDIUM RISK: Label Mismatch**
- **Risk:** "Steady/Easy/Wild" vs "Kaum/Überschaubar/Party" confusion
- **Mitigation:**
  - Use labelKey system for proper localization
  - Test both DE and EN thoroughly

🟢 **LOW RISK: UI Implementation**
- **Risk:** TrackerRow doesn't handle levels correctly
- **Mitigation:** TrackerRow already implements level display ✅

### Implementation Order

**Phase 1: Presets & Labels (1-2 hours)**
1. Add Mood preset to TrackerPreset.all
2. Fix NoAlc labels (use labelKey)
3. Add localization strings

**Phase 2: Remove Hardcoded UI (30 min)**
1. Remove noAlcCard from TrackerTab
2. Remove NoAlcLogSheet references
3. Test with manual NoAlc Tracker creation

**Phase 3: Migration (3-4 hours)**
1. Implement TrackerMigration.swift
2. Add fetchHistoricalData() to NoAlcManager
3. Add migration trigger in App.swift
4. Test with sample NoAlc data

**Phase 4: Default Trackers (30 min)**
1. Create NoAlc + Mood on first launch (if no trackers)
2. Set proper sort order (NoAlc first)

**Phase 5: Testing & Validation (2-3 hours)**
1. Unit tests for migration
2. UI tests for TrackerTab with multiple trackers
3. Manual testing on device with real NoAlc history

**Total Estimated Time:** 7-10 hours

---

## Next Steps

1. ✅ Context gathered
2. ✅ Analysis complete
3. **→ Next: `/write-spec` to create detailed implementation specification**
4. Then: User approval
5. Then: TDD RED phase (write failing tests)
6. Finally: Implementation
