# Feature: Exercise Info-Sheets Lokalisierung

## Bug-Referenz
**Bug 19:** Workouts-Tab Übungs-Info-Sheets auf Deutsch (in EN Version)

## Problemanalyse

### Aktueller Zustand
Die `ExerciseDatabase.swift` enthält **45 Übungen** mit jeweils:
- `name` (String) - Übungsname
- `effect` (String) - Wirkung/Effekt der Übung
- `instructions` (String) - Ausführungsanleitung

**Alle Strings sind hardcoded auf Deutsch.** In der EN-Version der App werden diese deutschen Texte unverändert angezeigt.

### Betroffene Datei
`Meditationstimer iOS/Services/ExerciseDatabase.swift` (Zeilen 1-342)

### Übungen nach Kategorie

| Kategorie | Anzahl | Beispiele |
|-----------|--------|-----------|
| Cardio/Full Body | 7 | Burpees, Mountain Climbers, High Knees |
| Core | 9 | Planke, Fahrrad-Crunches, Russian Twists |
| Legs | 13 | Kniebeugen, Ausfallschritte, Glute Bridges |
| Upper Body | 7 | Liegestütze, Diamond-Liegestütze, Pike-Liegestütze |
| Stretching | 11 | Quadrizeps-Dehnung, Hamstring-Dehnung |
| Warmup/Mobility | 2 | Beinpendel, Hüftkreisen |
| **Gesamt** | **45** | |

### Zu übersetzende Strings

| Feld | Zeichen pro Übung (Ø) | Gesamt |
|------|------------------------|--------|
| effect | ~150 Zeichen | ~6.750 Zeichen |
| instructions | ~300 Zeichen | ~13.500 Zeichen |
| **Gesamt** | | **~20.000 Zeichen** |

**Übersetzungs-Aufwand:** 90 Strings (45 Übungen × 2 Textfelder)

## Lösungsansatz

### Option A: NSLocalizedString (Empfohlen)
```swift
ExerciseInfo(
    name: "Burpees",  // Name kann Englisch bleiben
    category: .fullBody,
    effect: NSLocalizedString(
        "exercise.burpees.effect",
        value: "Ganzkörper-Übung, die nahezu alle Muskelgruppen aktiviert...",
        comment: "Effect description for Burpees exercise"
    ),
    instructions: NSLocalizedString(
        "exercise.burpees.instructions",
        value: "1) Stehe aufrecht 2) Gehe in die Hocke...",
        comment: "Instructions for Burpees exercise"
    )
)
```

**Vorteile:**
- Konsistent mit bestehender Lokalisierungsstrategie (xcstrings)
- Build-Zeit Validierung
- Standard iOS Pattern

### Option B: Computed Properties mit Locale-Check
```swift
var localizedEffect: String {
    let key = "exercise.\(name.lowercased()).effect"
    return NSLocalizedString(key, comment: "")
}
```

**Nachteil:** Erfordert Umbau der gesamten ExerciseInfo Struktur

## Implementierungsschritte

### Phase 1: Code-Änderungen (ExerciseDatabase.swift)
1. [ ] Alle 45 `effect` Strings mit NSLocalizedString wrappen
2. [ ] Alle 45 `instructions` Strings mit NSLocalizedString wrappen
3. [ ] Konsistente Key-Naming-Konvention: `exercise.[name].[effect|instructions]`

### Phase 2: Lokalisierung (Localizable.xcstrings)
1. [ ] 90 neue Keys hinzufügen (45 × 2)
2. [ ] Deutsche Übersetzungen aus aktuellem Code übernehmen
3. [ ] Englische Übersetzungen hinzufügen

### Phase 3: Englische Übersetzungen
Die deutschen Texte müssen ins Englische übersetzt werden. Beispiel:

**Deutsch:**
> Ganzkörper-Übung, die nahezu alle Muskelgruppen aktiviert: Beine, Core, Brust, Schultern, Arme. Verbessert Ausdauer, Explosivkraft und kardiovaskuläre Fitness.

**Englisch:**
> Full-body exercise that activates nearly all muscle groups: legs, core, chest, shoulders, arms. Improves endurance, explosive power, and cardiovascular fitness.

## Aufwandsschätzung

| Aspekt | Schätzung |
|--------|-----------|
| Code-Änderungen | 2-3 Stunden (90 NSLocalizedString wraps) |
| Deutsche Strings | 0 (bereits vorhanden) |
| Englische Übersetzungen | 3-4 Stunden (~20.000 Zeichen) |
| xcstrings-Einträge | 1 Stunde (90 Keys) |
| Testing | 1 Stunde |
| **Gesamt** | **7-9 Stunden** |

## Komplexität: Mittel

- **Dateien:** 2 (ExerciseDatabase.swift + Localizable.xcstrings)
- **Änderungen:** ~180 Zeilen (90 NSLocalizedString wraps)
- **Risiko:** Niedrig (keine Logik-Änderungen)
- **Abhängigkeiten:** Keine

## Test-Anweisungen

Nach Implementierung:
1. App in **EN-Version** starten
2. Workout-Tab öffnen
3. Workout aufklappen → Info-Button (ⓘ) tippen
4. **Erwartung:** `effect` und `instructions` auf Englisch
5. App in **DE-Version** starten
6. Gleiche Schritte → **Erwartung:** Texte auf Deutsch

## Acceptance Criteria

- [ ] Alle 45 `effect` Strings sind lokalisiert
- [ ] Alle 45 `instructions` Strings sind lokalisiert
- [ ] EN-Version zeigt englische Info-Sheets
- [ ] DE-Version zeigt deutsche Info-Sheets (unverändert)
- [ ] Build erfolgreich ohne Warnings
- [ ] Keine fehlenden Übersetzungen (xcstrings complete)

## Offene Fragen an Henning

1. **Übungsnamen:** Sollen diese auch lokalisiert werden? (z.B. "Burpees" bleibt, aber "Kniebeugen" → "Squats" in EN)

2. **Priorität:** Ist dieses Feature für Release 2.8 wichtig, oder kann es warten?

3. **Übersetzungsqualität:** Soll ich die englischen Übersetzungen generieren, oder bevorzugst du einen professionellen Übersetzer?
