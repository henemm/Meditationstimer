# Implementation Guide: Phase 1.1 - Tab Navigation Refactoring

## Ziel

Die bestehende 4-Tab-Struktur (Offen, Atem, Frei, Workouts) in die neue 4-Tab-Struktur (Meditation, Workout, Tracker, Erfolge) umwandeln.

**Keine Funktionalität geht verloren** - bestehende Views werden nur neu angeordnet.

---

## Aktuelle Struktur (IST)

```
ContentView.swift
├── AppTab enum: offen, atem, frei, workouts
├── TabView(selection: $selectedTab)
│   ├── Tab 1: OffenView        → "Open" (figure.mind.and.body)
│   ├── Tab 2: AtemView         → "Breathe" (wind)
│   ├── Tab 3: WorkoutProgramsView → "Workouts" (figure.strengthtraining.traditional)
│   └── Tab 4: WorkoutsView     → "Free" (flame)
└── Calendar: Modal (nicht Tab)
```

**Dateien:**
- `Meditationstimer iOS/ContentView.swift` - Haupt-TabView
- `Meditationstimer iOS/Tabs/OffenView.swift` - Freie Meditation
- `Meditationstimer iOS/Tabs/AtemView.swift` - Atemübungen
- `Meditationstimer iOS/Tabs/WorkoutsView.swift` - Freies HIIT
- `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` - Workout-Programme
- `Meditationstimer iOS/CalendarView.swift` - Kalender (Modal)

---

## Ziel-Struktur (SOLL)

```
ContentView.swift
├── AppTab enum: meditation, workout, tracker, erfolge
├── TabView(selection: $selectedTab)
│   ├── Tab 1: MeditationTab    → "Meditation" (figure.mind.and.body)
│   │   └── ScrollView
│   │       ├── OffenView (top, prominent)
│   │       └── AtemPresetsSection (below, scrollable)
│   │
│   ├── Tab 2: WorkoutTab       → "Workout" (flame)
│   │   └── ScrollView
│   │       ├── WorkoutsView (top, prominent) [Freies HIIT]
│   │       └── WorkoutProgramsSection (below, scrollable)
│   │
│   ├── Tab 3: TrackerTab       → "Tracker" (chart.bar.fill)
│   │   └── Placeholder (Phase 2)
│   │       └── NoAlc-Section (wenn vorhanden)
│   │
│   └── Tab 4: ErfolgeTab       → "Erfolge" (trophy.fill)
│       └── VStack
│           ├── StreakHeader
│           └── CalendarView
```

---

## Schritt-für-Schritt Anleitung

### Schritt 1: AppTab Enum aktualisieren

**Datei:** `ContentView.swift`

```swift
// ALT
enum AppTab: String, CaseIterable {
    case offen, atem, frei, workouts
}

// NEU
enum AppTab: String, CaseIterable {
    case meditation, workout, tracker, erfolge
}
```

### Schritt 2: Neue Tab-Views erstellen

**Neue Dateien erstellen in `Meditationstimer iOS/Tabs/`:**

#### 2.1 MeditationTab.swift

```swift
import SwiftUI

struct MeditationTab: View {
    @EnvironmentObject var timerEngine: TwoPhaseTimerEngine
    @EnvironmentObject var streakManager: StreakManager

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Freie Meditation (bestehende OffenView-Logik)
                FreeMeditationSection()

                Divider()
                    .padding(.horizontal)

                // Atemübungen Presets
                BreathingPresetsSection()
            }
            .padding(.bottom, 100) // Space for tab bar
        }
    }
}

// Wrapper um bestehende OffenView-Logik
struct FreeMeditationSection: View {
    var body: some View {
        // TODO: OffenView-Content hier einbetten
        // NICHT OffenView als ganzes - nur den Content
    }
}

// Wrapper um bestehende AtemView-Preset-Liste
struct BreathingPresetsSection: View {
    var body: some View {
        // TODO: Atem-Presets hier einbetten
    }
}
```

#### 2.2 WorkoutTab.swift

```swift
import SwiftUI

struct WorkoutTab: View {
    @EnvironmentObject var streakManager: StreakManager

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Freies Workout (bestehende WorkoutsView-Logik)
                FreeWorkoutSection()

                Divider()
                    .padding(.horizontal)

                // Workout-Programme
                WorkoutProgramsSection()
            }
            .padding(.bottom, 100)
        }
    }
}
```

#### 2.3 TrackerTab.swift (Placeholder)

```swift
import SwiftUI

struct TrackerTab: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // NoAlc Section (wenn bereits implementiert)
                // TODO: NoAlc hierher verschieben

                // Placeholder für Phase 2
                ContentUnavailableView(
                    "Tracker",
                    systemImage: "chart.bar.fill",
                    description: Text("Coming in Phase 2")
                )
            }
        }
    }
}
```

#### 2.4 ErfolgeTab.swift

```swift
import SwiftUI

struct ErfolgeTab: View {
    @EnvironmentObject var streakManager: StreakManager

    var body: some View {
        VStack(spacing: 0) {
            // Streak Header
            StreakHeaderView()

            // Calendar (bestehende CalendarView)
            CalendarView()
        }
    }
}

struct StreakHeaderView: View {
    @EnvironmentObject var streakManager: StreakManager

    var body: some View {
        HStack {
            StreakBadge(emoji: "🧘", days: streakManager.meditationStreak)
            StreakBadge(emoji: "💪", days: streakManager.workoutStreak)
            StreakBadge(emoji: "🍀", days: streakManager.noAlcStreak)
            StreakBadge(emoji: "⭐", days: streakManager.rewards)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}
```

### Schritt 3: ContentView TabView aktualisieren

**Datei:** `ContentView.swift`

```swift
TabView(selection: $selectedTab) {
    MeditationTab()
        .tabItem {
            Label("Meditation", systemImage: "figure.mind.and.body")
        }
        .tag(AppTab.meditation)

    WorkoutTab()
        .tabItem {
            Label("Workout", systemImage: "flame")
        }
        .tag(AppTab.workout)

    TrackerTab()
        .tabItem {
            Label("Tracker", systemImage: "chart.bar.fill")
        }
        .tag(AppTab.tracker)

    ErfolgeTab()
        .tabItem {
            Label("Erfolge", systemImage: "trophy.fill")
        }
        .tag(AppTab.erfolge)
}
```

### Schritt 4: Deep Links / Notifications anpassen

**Datei:** `ShortcutHandler.swift`

Mapping aktualisieren:
- `offen` → `meditation`
- `atem` → `meditation` (mit Scroll-to-Presets)
- `frei` → `workout`
- `workouts` → `workout` (mit Scroll-to-Programs)

**Datei:** `ShortcutNotifications.swift`

```swift
// Notification Namen können bleiben, aber Handler anpassen
.startMeditationSession → selectedTab = .meditation
.startBreathingSession → selectedTab = .meditation + scroll to presets
.startWorkoutSession → selectedTab = .workout
```

### Schritt 5: Settings Tab-Namen aktualisieren

**Datei:** `SettingsSheet.swift`

Alle Referenzen zu "Offen Tab" / "Atem Tab" aktualisieren:
- "Enable for Open" → "Enable for Free Meditation"
- "Enable for Breathe" → "Enable for Breathing Exercises"

### Schritt 6: Lokalisierung

**Datei:** `Localizable.xcstrings`

Neue Strings hinzufügen:
```
"Meditation" = "Meditation"
"Workout" = "Workout"
"Tracker" = "Tracker"
"Erfolge" = "Erfolge" (DE) / "Achievements" (EN)
```

---

## Wichtige Hinweise

### Was NICHT ändern:
- OffenView.swift - Logik bleibt, wird nur eingebettet
- AtemView.swift - Logik bleibt, wird nur eingebettet
- WorkoutsView.swift - Logik bleibt, wird nur eingebettet
- WorkoutProgramsView.swift - Logik bleibt, wird nur eingebettet
- CalendarView.swift - Logik bleibt, wird in ErfolgeTab eingebettet
- TwoPhaseTimerEngine - Keine Änderungen
- HealthKitManager - Keine Änderungen
- StreakManager - Keine Änderungen

### Environment Objects:
MeditationTab braucht:
- `TwoPhaseTimerEngine`
- `StreakManager`

WorkoutTab braucht:
- `StreakManager`

TrackerTab braucht:
- `StreakManager` (später auch TrackerManager)

ErfolgeTab braucht:
- `StreakManager`

### Test-Checkliste nach Implementierung:
- [ ] App startet ohne Crash
- [ ] Meditation Tab zeigt freie Meditation + Atemübungen
- [ ] Workout Tab zeigt freies Workout + Programme
- [ ] Tracker Tab zeigt Placeholder
- [ ] Erfolge Tab zeigt Kalender
- [ ] Timer starten funktioniert (Meditation)
- [ ] Timer starten funktioniert (Workout)
- [ ] Atemübung starten funktioniert
- [ ] Workout-Programm starten funktioniert
- [ ] HealthKit Logging funktioniert
- [ ] Streaks werden angezeigt
- [ ] Deep Links funktionieren noch

---

## Dateien-Übersicht

### Neue Dateien:
1. `Meditationstimer iOS/Tabs/MeditationTab.swift`
2. `Meditationstimer iOS/Tabs/WorkoutTab.swift`
3. `Meditationstimer iOS/Tabs/TrackerTab.swift`
4. `Meditationstimer iOS/Tabs/ErfolgeTab.swift`

### Zu ändernde Dateien:
1. `ContentView.swift` - AppTab enum + TabView
2. `ShortcutHandler.swift` - Tab-Mapping
3. `SettingsSheet.swift` - Label-Texte
4. `Localizable.xcstrings` - Neue Strings

### Unveränderte Dateien:
- `OffenView.swift`
- `AtemView.swift`
- `WorkoutsView.swift`
- `WorkoutProgramsView.swift`
- `CalendarView.swift`
- Alle Service-Dateien

---

## Geschätzte Komplexität

| Schritt | Aufwand | Risiko |
|---------|---------|--------|
| 1. AppTab Enum | 5 min | Gering |
| 2. Neue Tab-Views | 60 min | Mittel |
| 3. ContentView TabView | 15 min | Gering |
| 4. Deep Links | 20 min | Mittel |
| 5. Settings Labels | 10 min | Gering |
| 6. Lokalisierung | 10 min | Gering |
| **Gesamt** | **~2 Stunden** | **Mittel** |

---

## Nach Abschluss

Wenn Phase 1.1 fertig ist:
1. Build testen (`xcodebuild`)
2. Unit Tests laufen lassen
3. Manuelle Tests auf Device
4. Commit: `feat: Refactor to 4-tab structure (Meditation, Workout, Tracker, Erfolge)`
5. Weiter mit Phase 1.2 (SwiftData Tracker Model)
