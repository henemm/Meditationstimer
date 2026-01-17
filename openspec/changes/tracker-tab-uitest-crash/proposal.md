# TrackerTab crasht in UI Tests (SwiftData In-Memory Config fehlt)

## Problem

Der UI-Test `testTabSwitching()` schlägt fehl wenn der Tracker Tab geöffnet wird:
- **Fehler:** `"(ipc/mig) server died"` - App crasht während UI-Test
- **Root Cause:** SwiftData `ModelContainer` verwendet persistente Disk-Storage auch für UI Tests
- **Betroffen:** Nur UI Tests - normale App-Nutzung funktioniert

### Warum crasht es?

TrackerTab.swift verwendet SwiftData `@Query`:
```swift
@Query(filter: #Predicate<Tracker> { $0.isActive }, sort: \\Tracker.createdAt)
private var trackers: [Tracker]
```

Diese Query greift auf die SwiftData-Datenbank zu. In UI Tests MUSS SwiftData **in-memory** laufen, nicht auf Disk - sonst crasht die App beim Zugriff.

### Research

Bestätigt durch:
- [Hacking with Swift: How to write UI tests for your SwiftData code](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-write-ui-tests-for-your-swiftdata-code)
- [Apple Developer Forums: SwiftData @Query crashes](https://forums.developer.apple.com/forums/thread/738145)

**Best Practice:** UI Tests müssen mit sauberem in-memory Container starten, sonst gibt es alte Daten und Konflikte.

## Lösung

Zwei Änderungen erforderlich:

### 1. App: In-Memory Config für UI Tests

**Datei:** `Meditationstimer iOS/Meditationstimer_iOSApp.swift`

**Vorher (Zeile 29-36):**
```swift
init() {
    do {
        let schema = Schema([Tracker.self, TrackerLog.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)  // ❌ Immer Disk
        modelContainer = try ModelContainer(for: schema, configurations: [config])
    } catch {
        fatalError("Failed to create ModelContainer: \(error)")
    }
}
```

**Nachher:**
```swift
init() {
    // Detect UI test mode
    var inMemory = false
    #if DEBUG
    if CommandLine.arguments.contains("enable-testing") {
        inMemory = true
    }
    #endif

    do {
        let schema = Schema([Tracker.self, TrackerLog.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)  // ✅ In-memory für Tests
        modelContainer = try ModelContainer(for: schema, configurations: [config])
    } catch {
        fatalError("Failed to create ModelContainer: \(error)")
    }
}
```

### 2. Tests: Launch Argument hinzufügen

**Datei:** `LeanHealthTimerUITests/LeanHealthTimerUITests.swift`

**Alle Tests mit `app.launchArguments` erweitern:**

**Vorher (Zeile 16, 34, 46, etc.):**
```swift
app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
```

**Nachher:**
```swift
app.launchArguments = ["enable-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
```

**Betroffen:** Alle Test-Methoden die `app.launch()` aufrufen (~10 Tests)

## Betroffene Dateien

| Datei | Änderung | LoC |
|-------|----------|-----|
| `Meditationstimer iOS/Meditationstimer_iOSApp.swift` | In-memory Config für UI Tests | +7/-1 |
| `LeanHealthTimerUITests/LeanHealthTimerUITests.swift` | Launch Argument "enable-testing" hinzufügen | ~10 Zeilen (jeder Test) |

**Geschätzt:** +17/-11 LoC

## Test Plan

### Automated Tests (TDD RED)

Der existierende Test **MUSS nach Fix GRÜN werden**:
- [ ] `testTabSwitching()` - VORHER: FAILED ❌ / NACHHER: PASSED ✅

### Alle existierenden UI Tests prüfen

Nach dem Fix müssen ALLE UI Tests weiterhin funktionieren:
- [ ] `testAllFourTabsExist()`
- [ ] `testMeditationTabIsDefaultSelected()`
- [ ] `testTabSwitching()` ← **Dieser war broken**
- [ ] `testMeditationViewShowsDauerLabelInGerman()`
- [ ] `testMeditationViewShowsAusklangLabelInGerman()`
- [ ] Alle weiteren UI Tests in der Datei

### Manual Tests (App-Funktionalität prüfen)

Sicherstellen dass normale App-Nutzung NICHT beeinträchtigt ist:
- [ ] Tracker Tab öffnen in normaler App → Funktioniert
- [ ] Tracker hinzufügen → Wird gespeichert (persistiert nach App-Neustart)
- [ ] NoAlc-Tracker nutzen → Logs werden in HealthKit geschrieben
- [ ] App neu starten → Tracker sind noch da (Disk-Storage funktioniert)

**Warum wichtig?** Wir dürfen NICHT in-memory für Production-App aktivieren!

## Acceptance Criteria

- [ ] `testTabSwitching()` ist GRÜN ✅
- [ ] Alle anderen UI Tests sind GRÜN ✅
- [ ] Production App speichert Tracker persistent (nicht in-memory)
- [ ] Nach App-Neustart sind Tracker-Daten noch vorhanden

## Risiken

**LOW RISK:**
- Änderung ist isoliert (`#if DEBUG` Guard)
- Nur UI-Test-Mode betroffen
- Production-App unverändert
- Standard-Pattern aus Apple/Swift Community

## Nicht betroffen

- Logik von TrackerTab bleibt unverändert
- SwiftData Modelle (Tracker, TrackerLog) bleiben gleich
- NoAlcManager bleibt unverändert
- Alle anderen Services unverändert
