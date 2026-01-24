---
entity_id: generic-tracker-system-implementation
type: feature
created: 2026-01-17
status: draft
workflow: generic-tracker-system
---

# Generic Tracker System - Full Implementation

- [ ] Approved for implementation

## Purpose

Complete the implementation of the Generic Tracker System by migrating NoAlc from its proprietary implementation to the generic Tracker system. This unifies all trackers (NoAlc, Mood, and future custom trackers) under one flexible architecture based on `openspec/specs/features/generic-tracker-system.md`.

**What:** Remove hardcoded NoAlc UI, add missing Mood preset, migrate existing NoAlc data
**Why:** Enables extensible tracker system where any tracker type is configuration-driven instead of code-driven

## Scope

### Files to Modify (6)

| File | LoC Change | Description |
|------|------------|-------------|
| `Services/TrackerModels.swift` | +45 | Add Mood preset, fix NoAlc label keys |
| `Meditationstimer iOS/Tabs/TrackerTab.swift` | -70 | Remove hardcoded NoAlc card + buttons |
| `Meditationstimer iOS/Localizable.xcstrings` | +60 | Add German translations for levels |
| `Meditationstimer iOS/Meditationstimer_iOSApp.swift` | +15 | Add migration check on launch |
| `Services/NoAlcManager.swift` | +5 | Add deprecation notice, keep for migration |
| `LeanHealthTimerUITests/LeanHealthTimerUITests.swift` | +25 | Update UI tests for generic TrackerTab |

### Files to Create (2)

| File | LoC | Description |
|------|-----|-------------|
| `Services/TrackerMigration.swift` | +180 | NoAlc data migration manager |
| `LeanHealthTimerTests/TrackerMigrationTests.swift` | +120 | Migration tests |

### Files to Deprecate (1)

| File | Action | Reason |
|------|--------|--------|
| `Meditationstimer iOS/NoAlcLogSheet.swift` | Keep, mark unused | Replaced by LevelSelectionView |

**Total:** +380 LoC added, -70 LoC removed = **+310 LoC net**

**Risk Level:** MEDIUM (data migration complexity)

---

## Implementation Details

### Phase 1: Add Missing Presets & Fix Labels

#### 1.1 Add Mood Preset to TrackerPreset.all

**File:** `Services/TrackerModels.swift`

**Location:** Line 490-601 (TrackerPreset.all array)

**Add:**
```swift
// After NoAlc preset (line 600), before closing bracket:
,
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

#### 1.2 Fix NoAlc Label Keys

**File:** `Services/TrackerModels.swift`

**Location:** Line 161-165 (TrackerLevel.noAlcLevels)

**Change:**
```swift
// OLD:
TrackerLevel(id: 0, key: "steady", icon: "💧", labelKey: "Steady", streakEffect: .success),
TrackerLevel(id: 1, key: "easy", icon: "✨", labelKey: "Easy", streakEffect: .needsGrace),
TrackerLevel(id: 2, key: "wild", icon: "💥", labelKey: "Wild", streakEffect: .needsGrace)

// NEW:
TrackerLevel(id: 0, key: "steady", icon: "💧", labelKey: "NoAlc.Steady", streakEffect: .success),
TrackerLevel(id: 1, key: "easy", icon: "✨", labelKey: "NoAlc.Easy", streakEffect: .needsGrace),
TrackerLevel(id: 2, key: "wild", icon: "💥", labelKey: "NoAlc.Wild", streakEffect: .needsGrace)
```

#### 1.3 Add Localization Strings

**File:** `Meditationstimer iOS/Localizable.xcstrings`

**Add:**
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
    "extractionState": "manual",
    "localizations": {
      "de": { "stringUnit": { "state": "translated", "value": "Überschaubar" } },
      "en": { "stringUnit": { "state": "translated", "value": "Easy" } }
    }
  },
  "NoAlc.Wild": {
    "extractionState": "manual",
    "localizations": {
      "de": { "stringUnit": { "state": "translated", "value": "Party" } },
      "en": { "stringUnit": { "state": "translated", "value": "Wild" } }
    }
  },
  "Mood.Awful": {
    "extractionState": "manual",
    "localizations": {
      "de": { "stringUnit": { "state": "translated", "value": "Mies" } },
      "en": { "stringUnit": { "state": "translated", "value": "Awful" } }
    }
  },
  "Mood.Bad": {
    "extractionState": "manual",
    "localizations": {
      "de": { "stringUnit": { "state": "translated", "value": "Schlecht" } },
      "en": { "stringUnit": { "state": "translated", "value": "Bad" } }
    }
  },
  "Mood.Okay": {
    "extractionState": "manual",
    "localizations": {
      "de": { "stringUnit": { "state": "translated", "value": "Okay" } },
      "en": { "stringUnit": { "state": "translated", "value": "Okay" } }
    }
  },
  "Mood.Good": {
    "extractionState": "manual",
    "localizations": {
      "de": { "stringUnit": { "state": "translated", "value": "Gut" } },
      "en": { "stringUnit": { "state": "translated", "value": "Good" } }
    }
  },
  "Mood.Great": {
    "extractionState": "manual",
    "localizations": {
      "de": { "stringUnit": { "state": "translated", "value": "Super" } },
      "en": { "stringUnit": { "state": "translated", "value": "Great" } }
    }
  }
}
```

---

### Phase 2: Remove Hardcoded NoAlc UI

#### 2.1 Remove NoAlc Card from TrackerTab

**File:** `Meditationstimer iOS/Tabs/TrackerTab.swift`

**Remove:**
- Lines 56-75: `noAlcButton()` function
- Lines 87-88: `noAlcCard` in trackersSection
- Lines 100-127: `noAlcCard` computed property
- Line 25: `@State private var showingNoAlcLog = false`
- Lines 44-46: `.sheet(isPresented: $showingNoAlcLog) { NoAlcLogSheet() }`

**Result:**
```swift
// TrackerTab.swift after cleanup
struct TrackerTab: View {
    @EnvironmentObject var streakManager: StreakManager
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Tracker> { $0.isActive }, sort: \Tracker.createdAt)
    private var trackers: [Tracker]

    @State private var showingAddTracker = false
    @State private var trackerToEdit: Tracker?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    trackersSection
                    addTrackerCard
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddTracker) {
                AddTrackerSheet()
            }
            .sheet(item: $trackerToEdit) { tracker in
                TrackerEditorSheet(tracker: tracker)
            }
        }
    }

    private var trackersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("Trackers", comment: "Trackers section header"))
                .font(.title3)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            // ALL trackers (including NoAlc) rendered generically
            ForEach(trackers) { tracker in
                TrackerRow(tracker: tracker) {
                    trackerToEdit = tracker
                }
            }
        }
    }

    // addTrackerCard unchanged
}
```

---

### Phase 3: Data Migration

#### 3.1 Create TrackerMigration.swift

**File:** `Services/TrackerMigration.swift` (NEW)

**Content:**
```swift
//
//  TrackerMigration.swift
//  Meditationstimer
//
//  Created by Claude on 17.01.2026.
//
//  Migrates legacy NoAlc data to Generic Tracker System.
//

import Foundation
import SwiftData
import HealthKit

/// Manages migration from legacy NoAlc system to Generic Tracker System
final class TrackerMigration {
    static let shared = TrackerMigration()

    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current

    private init() {}

    // MARK: - NoAlc Migration

    /// Migrates NoAlc from NoAlcManager to Generic Tracker System
    /// - Parameter context: SwiftData ModelContext
    /// - Throws: Migration errors
    func migrateNoAlcIfNeeded(context: ModelContext) async throws {
        // Check if NoAlc Tracker already exists
        let descriptor = FetchDescriptor<Tracker>(
            predicate: #Predicate { $0.name == "NoAlc" }
        )

        if let existing = try context.fetch(descriptor).first {
            print("[Migration] NoAlc Tracker already exists (id: \(existing.id))")
            return
        }

        print("[Migration] Starting NoAlc migration...")

        // 1. Create NoAlc Tracker from preset
        guard let noAlcPreset = TrackerPreset.all.first(where: { $0.name == "NoAlc" }) else {
            throw MigrationError.presetNotFound("NoAlc")
        }

        let tracker = noAlcPreset.createTracker()
        context.insert(tracker)

        // 2. Fetch historical HealthKit data
        let noAlcData = try await fetchNoAlcHistoricalData()
        print("[Migration] Found \(noAlcData.count) NoAlc HealthKit entries")

        // 3. Create TrackerLog entries for each HealthKit entry
        for (date, levelValue) in noAlcData {
            let log = TrackerLog(
                timestamp: date,
                value: levelValue, // 0=steady, 4=easy, 6=wild (matches ConsumptionLevel.rawValue)
                syncedToHealthKit: true,
                tracker: tracker
            )
            context.insert(log)
        }

        // 4. Save context
        try context.save()

        print("[Migration] NoAlc migration complete: \(noAlcData.count) logs migrated")
    }

    /// Fetches all NoAlc data from HealthKit
    private func fetchNoAlcHistoricalData() async throws -> [(Date, Int)] {
        guard let alcoholType = HKObjectType.quantityType(forIdentifier: .numberOfAlcoholicBeverages) else {
            throw MigrationError.healthKitTypeUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: alcoholType,
                predicate: nil,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                // Map HealthKit samples to (date, levelValue) tuples
                let data = samples.map { sample -> (Date, Int) in
                    let value = Int(sample.quantity.doubleValue(for: .count()))
                    return (sample.startDate, value)
                }

                continuation.resume(returning: data)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Default Trackers

    /// Creates default trackers (NoAlc + Mood) if none exist
    func createDefaultTrackersIfNeeded(context: ModelContext) throws {
        let descriptor = FetchDescriptor<Tracker>()
        let existingCount = try context.fetchCount(descriptor)

        guard existingCount == 0 else {
            print("[Migration] Trackers already exist, skipping default creation")
            return
        }

        print("[Migration] Creating default trackers (NoAlc + Mood)...")

        // Create NoAlc
        if let noAlcPreset = TrackerPreset.all.first(where: { $0.name == "NoAlc" }) {
            let noAlc = noAlcPreset.createTracker()
            context.insert(noAlc)
        }

        // Create Mood
        if let moodPreset = TrackerPreset.all.first(where: { $0.name == "Mood" }) {
            let mood = moodPreset.createTracker()
            context.insert(mood)
        }

        try context.save()
        print("[Migration] Default trackers created")
    }

    enum MigrationError: LocalizedError {
        case presetNotFound(String)
        case healthKitTypeUnavailable

        var errorDescription: String? {
            switch self {
            case .presetNotFound(let name):
                return "Preset '\(name)' not found in TrackerPreset.all"
            case .healthKitTypeUnavailable:
                return "HealthKit alcohol type unavailable"
            }
        }
    }
}
```

#### 3.2 Add Migration Trigger

**File:** `Meditationstimer iOS/Meditationstimer_iOSApp.swift`

**Add after @Environment declarations:**
```swift
.task {
    // Run migration on first launch after update
    let migrationKey = "hasRunGenericTrackerMigration_v2.9.0"
    if !UserDefaults.standard.bool(forKey: migrationKey) {
        do {
            try await TrackerMigration.shared.migrateNoAlcIfNeeded(context: modelContext)
            try TrackerMigration.shared.createDefaultTrackersIfNeeded(context: modelContext)
            UserDefaults.standard.set(true, forKey: migrationKey)
            print("[App] Generic Tracker migration complete")
        } catch {
            print("[App] Migration error: \(error)")
            // Continue anyway - NoAlcManager fallback still works
        }
    }
}
```

#### 3.3 Deprecate NoAlcManager

**File:** `Services/NoAlcManager.swift`

**Add at top of class:**
```swift
@available(*, deprecated, message: "Use Tracker with NoAlc preset. This manager is kept only for migration compatibility.")
final class NoAlcManager {
    // ... existing code unchanged
}
```

---

### Phase 4: Update UI Tests

#### 4.1 Update TrackerTab UI Tests

**File:** `LeanHealthTimerUITests/LeanHealthTimerUITests.swift`

**Modify existing test (if exists) or add:**
```swift
/// Test that TrackerTab displays generic trackers (including NoAlc) without crashes
func testTrackerTabDisplaysMultipleTrackers() throws {
    let app = XCUIApplication()
    app.launch()

    // Handle HealthKit permissions (reuse existing logic)
    handleHealthKitPermissions(app)

    // Navigate to Tracker tab
    let trackerTab = app.tabBars.buttons["Tracker"]
    XCTAssertTrue(trackerTab.waitForExistence(timeout: 5))
    trackerTab.tap()

    sleep(2)

    // Verify trackers are displayed generically
    // (NoAlc should appear as regular TrackerRow, not special card)
    XCTAssertTrue(app.staticTexts["NoAlc"].exists, "NoAlc tracker should exist")
    XCTAssertTrue(app.buttons["addTrackerButton"].exists, "Add Tracker button should exist")

    // Take screenshot
    let screenshot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = "TrackerTab_Generic_System"
    attachment.lifetime = .keepAlways
    add(attachment)
}
```

---

## Test Plan

### Automated Tests (TDD RED)

#### Migration Tests (`LeanHealthTimerTests/TrackerMigrationTests.swift`)

- [ ] **Test 1: Migrate Empty NoAlc Data**
  - GIVEN no HealthKit NoAlc data exists
  - WHEN migrateNoAlcIfNeeded() runs
  - THEN NoAlc Tracker is created with 0 logs
  - EXPECTED: FAIL initially (TrackerMigration.swift doesn't exist)

- [ ] **Test 2: Migrate NoAlc with Historical Data**
  - GIVEN 10 HealthKit NoAlc entries (various levels)
  - WHEN migrateNoAlcIfNeeded() runs
  - THEN NoAlc Tracker exists with 10 TrackerLog entries
  - AND log values match HealthKit values (0, 4, 6)
  - EXPECTED: FAIL initially

- [ ] **Test 3: Skip Migration if Tracker Exists**
  - GIVEN NoAlc Tracker already exists in database
  - WHEN migrateNoAlcIfNeeded() runs
  - THEN no duplicate Tracker is created
  - AND no new logs are added
  - EXPECTED: FAIL initially

- [ ] **Test 4: Streak Calculation After Migration**
  - GIVEN migrated NoAlc data with steady/easy/wild patterns
  - WHEN StreakCalculator runs
  - THEN streak and rewards are correctly calculated
  - AND matches previous NoAlcManager streak logic
  - EXPECTED: FAIL initially

- [ ] **Test 5: Create Default Trackers**
  - GIVEN empty database (no trackers)
  - WHEN createDefaultTrackersIfNeeded() runs
  - THEN NoAlc and Mood trackers are created
  - EXPECTED: FAIL initially

#### Model Tests

- [ ] **Test 6: Mood Preset Exists**
  - GIVEN TrackerPreset.all array
  - WHEN searching for "Mood" preset
  - THEN preset exists with 5 mood levels
  - AND HealthKit type is "HKStateOfMind"
  - EXPECTED: FAIL initially (Mood preset doesn't exist yet)

- [ ] **Test 7: NoAlc Labels Localized**
  - GIVEN NoAlc TrackerLevel
  - WHEN accessing localizedLabel
  - THEN German shows "Kaum"/"Überschaubar"/"Party"
  - AND English shows "Steady"/"Easy"/"Wild"
  - EXPECTED: FAIL initially (labels not in Localizable.xcstrings)

### Manual Tests

- [ ] **Manual 1: TrackerTab Visual Inspection**
  - Open app on device with existing NoAlc data
  - Navigate to Tracker Tab
  - Verify: NoAlc appears as generic tracker row (not special card)
  - Verify: Mood tracker appears
  - Verify: "Add Tracker" button works

- [ ] **Manual 2: NoAlc Level Selection**
  - Tap on NoAlc tracker
  - Verify: LevelSelectionView opens with "Kaum"/"Überschaubar"/"Party" buttons
  - Log "Kaum" entry
  - Verify: Today's status shows "💧 Kaum"
  - Verify: Streak is preserved from previous data

- [ ] **Manual 3: Mood Level Selection**
  - Tap on Mood tracker
  - Verify: LevelSelectionView opens with 5 mood levels
  - Log mood entry
  - Verify: Entry is saved to HealthKit (HKStateOfMind)

- [ ] **Manual 4: Migration on Clean Install**
  - Delete app
  - Reinstall
  - Launch app
  - Verify: NoAlc and Mood trackers are auto-created
  - Verify: No crash during migration

- [ ] **Manual 5: Migration with Existing Data**
  - Use device with 1+ year of NoAlc HealthKit data
  - Update to new version
  - Launch app
  - Verify: All historical NoAlc data appears in Tracker system
  - Verify: Streak matches previous value
  - Verify: Rewards are preserved

---

## Acceptance Criteria

### Functional Requirements

- [ ] **AC1:** NoAlc appears as generic Tracker (not hardcoded card)
- [ ] **AC2:** Mood tracker preset exists and can be created
- [ ] **AC3:** NoAlc labels show correct German translations ("Kaum"/"Überschaubar"/"Party")
- [ ] **AC4:** Existing NoAlc HealthKit data is migrated to Tracker system
- [ ] **AC5:** NoAlc streak and rewards are preserved after migration
- [ ] **AC6:** LevelSelectionView works for both NoAlc and Mood trackers
- [ ] **AC7:** New users get NoAlc + Mood trackers by default
- [ ] **AC8:** Migration runs only once (UserDefaults flag prevents re-run)

### Technical Requirements

- [ ] **AC9:** All unit tests pass (6 new tests in TrackerMigrationTests)
- [ ] **AC10:** All UI tests pass (1 updated test in LeanHealthTimerUITests)
- [ ] **AC11:** Build succeeds without warnings
- [ ] **AC12:** No memory leaks during migration
- [ ] **AC13:** NoAlcManager.swift marked as deprecated
- [ ] **AC14:** No breaking changes to existing Tracker functionality

### User Experience Requirements

- [ ] **AC15:** Migration completes in <5 seconds for typical user (100-500 NoAlc entries)
- [ ] **AC16:** No user action required during migration
- [ ] **AC17:** Visual design matches screenshot (NoAlc with 3 colored buttons)
- [ ] **AC18:** No data loss during migration (verified by manual testing)

---

## Risk Mitigation

### Data Loss Prevention

1. **Keep NoAlcManager as fallback:**
   - Mark as deprecated but don't delete
   - If migration fails, app continues using NoAlcManager
   - Logs error but doesn't crash

2. **Migration idempotency:**
   - Check if NoAlc Tracker exists before migrating
   - Use UserDefaults flag to prevent re-run
   - If migration runs twice, no duplicate data

3. **Thorough testing:**
   - Test with 0 entries, 10 entries, 1000+ entries
   - Test with various level patterns (steady/easy/wild)
   - Test streak edge cases (rewards at 7-day boundaries)

### Rollback Strategy

If migration fails catastrophically in production:

1. **Hotfix:** Revert to showing hardcoded NoAlc card (git revert UI changes)
2. **Keep data:** Migrated Tracker data remains (no data loss)
3. **Fix forward:** Debug migration issue, release v2.9.1

---

## Implementation Order

1. **Phase 1:** Presets & Labels (1-2h)
   - Add Mood preset
   - Fix NoAlc label keys
   - Add localization strings
   - ✅ Run tests: `Test 6` and `Test 7` should PASS

2. **Phase 2:** Remove Hardcoded UI (30min)
   - Remove NoAlc card from TrackerTab
   - ✅ Manual test: App still works, NoAlc missing

3. **Phase 3:** Migration (3-4h)
   - Create TrackerMigration.swift
   - Add migration trigger to App.swift
   - ✅ Run tests: `Test 1-5` should PASS
   - ✅ Manual test: Migration with sample data

4. **Phase 4:** UI Tests (30min)
   - Update TrackerTab UI test
   - ✅ All UI tests should PASS

5. **Phase 5:** Integration Testing (2-3h)
   - Test on device with real NoAlc history
   - Test clean install
   - Test streak calculation accuracy

---

## Dependencies

- ✅ `Services/TrackerModels.swift` - Generic system already implemented
- ✅ `Services/TrackerManager.swift` - CRUD operations ready
- ✅ `Services/StreakCalculator.swift` - Algorithm implemented
- ✅ `Meditationstimer iOS/Tracker/LevelSelectionView.swift` - Generic level UI ready
- ✅ `Meditationstimer iOS/Tracker/TrackerRow.swift` - Supports level-based trackers
- ⚠️ `Services/NoAlcManager.swift` - Need to keep for migration period
- ❌ `Services/TrackerMigration.swift` - NEW file (create in TDD RED)

---

## Open Questions for User

1. **Q: Should SmartReminders be migrated?**
   - Current: NoAlc uses ActivityType.noalc
   - Future: Should use ActivityType.tracker(UUID)
   - Decision needed: Migrate reminders or leave as-is for MVP?

2. **Q: Keep NoAlcLogSheet.swift?**
   - Status: Replaced by LevelSelectionView
   - Decision: Delete now or mark deprecated and delete later?

3. **Q: Migration failure UX?**
   - If migration throws error, should we:
     - A) Show alert to user
     - B) Silent fallback to NoAlcManager
     - C) Retry on next launch

---

## Post-Implementation

After this spec is approved and implemented:

- [ ] Update `DOCS/ACTIVE-roadmap.md` - Mark Generic Tracker System as "Abgeschlossen"
- [ ] Update `openspec/specs/features/generic-tracker-system.md` - Change status to "Implemented"
- [ ] Create release notes for v2.9.0
- [ ] Plan Phase 2 features (Activity Trackers: Water, Coffee, etc.)

---

**Estimated Time:** 7-10 hours total
**Risk Level:** MEDIUM (data migration)
**Priority:** HIGH (enables all future tracker features)
