# Feature: Workout-Übungen Lokalisierung & Vollständigkeit

**Status:** Geplant
**Priorität:** Mittel
**Geschätzter Aufwand:** Klein-Mittel (~150-200 LoC, 2 Dateien)

---

## Zusammenfassung

Übungsnamen in HIIT-Workouts sind komplett englisch, obwohl zuvor eine sinnvolle Mischung existierte. Deutsche Begriffe wo üblich (z.B. "Hüftkreisen"), Englisch als Fallback (z.B. "Push-Ups", "Burpees"). Zusätzlich fehlen Übungen (z.B. "Leg Swing Right").

---

## Ist-Zustand

### Betroffene Datei
`Services/WorkoutModels.swift` (einzige Datei mit Übungsdefinitionen)

### Aktuelle Lokalisierung
**Keine!** Namen sind hardcoded als String-Literale:
```swift
WorkoutPhase(name: "Jumping Jacks", duration: 30, isWork: true, description: "...")
```

### Probleme
1. **Alle Namen Englisch** - auch wo deutsche Begriffe üblich sind
2. **Fehlende Übung:** "Leg Swing Right" fehlt im "Jogging Warm-up" (nur Left vorhanden, Zeile 387)
3. **Info-Sheet Texte** (description) ebenfalls nur Englisch

### Systematische Prüfung Left/Right-Paare

| Programm | Übung | Left | Right | Status |
|----------|-------|:----:|:-----:|--------|
| Core Power | Side Plank | ✓ | ✓ | OK |
| Balance Training | Single-Leg Deadlift | ✓ | ✓ | OK |
| Balance Training | Bulgarian Split Squats | ✓ | ✓ | OK |
| **Jogging Warm-up** | **Leg Swing** | ✓ | ❌ | **FEHLT!** |
| Post-Run Stretching | Quadriceps Stretch | ✓ | ✓ | OK |
| Post-Run Stretching | Hamstring Stretch | ✓ | ✓ | OK |
| Post-Run Stretching | Hip Flexor Stretch | ✓ | ✓ | OK |
| Post-Run Stretching | Calf Stretch | ✓ | ✓ | OK |

---

## Vorgeschlagene Übersetzungsstrategie

| Englisch | Deutsch | Begründung |
|----------|---------|------------|
| Jumping Jacks | Hampelmann | Gängiger deutscher Begriff |
| High Knees | Kniehebelauf | Etablierter Fitness-Begriff |
| Squats | Kniebeugen | Standard deutsch |
| Mountain Climbers | Bergsteiger | Etabliert im Fitness |
| Lunges | Ausfallschritte | Standard deutsch |
| **Burpees** | **Burpees** | Kein deutsches Äquivalent |
| Plank | Planke | Geklärt: Deutsch |
| Jump Squats | Sprungkniebeugen | Kombi |
| Neck Rolls | Nackenkreisen | Standard deutsch |
| Shoulder Circles | Schulterkreisen | Standard deutsch |
| Arm Circles | Armkreisen | Standard deutsch |
| Hip Circles | Hüftkreisen | Standard deutsch |
| Leg Swing | Beinschwingen | Standard deutsch |
| Side Stretch | Seitliche Dehnung | Standard deutsch |
| Forward Fold | Vorbeuge | Yoga-Begriff |
| Push-Ups | Liegestütze | Standard deutsch |
| Tricep Dips | Trizeps-Dips | Halb-deutsch |
| Wall Sit | Wandsitzen | Standard deutsch |
| **Crunches** | **Crunches** | Kein gutes deutsches Wort |
| Superman Hold | Superman-Halten | Bekannter Name |

---

## Anforderungen

- [ ] Fehlende Übung hinzufügen: "Leg Swing Right" nach "Leg Swing Left" in **Jogging Warm-up** (Zeile 387-388)
- [ ] Übungsnamen lokalisieren mit `String(localized:)`
- [ ] Beschreibungen (Info-Sheets) lokalisieren
- [ ] Strings in Localizable.xcstrings eintragen

---

## Technische Umsetzung

### Schritt 1: Fehlende Übung
```swift
// In Morning Stretch nach "Leg Swing Left":
WorkoutPhase(name: String(localized: "exercise.leg_swing_right"), ...)
```

### Schritt 2: Lokalisierung einführen
```swift
// VORHER:
WorkoutPhase(name: "Jumping Jacks", ...)

// NACHHER:
WorkoutPhase(name: String(localized: "exercise.jumping_jacks"), ...)
```

### Schritt 3: Localizable.xcstrings
```json
"exercise.jumping_jacks": {
  "localizations": {
    "de": { "stringUnit": { "value": "Hampelmann" } },
    "en": { "stringUnit": { "value": "Jumping Jacks" } }
  }
}
```

---

## Betroffene Dateien

| Datei | Änderung |
|-------|----------|
| `Services/WorkoutModels.swift` | Lokalisierte Strings + fehlende Übung |
| `Localizable.xcstrings` | ~40 neue String-Keys |

---

## Test-Plan

1. App auf Deutsch: Übungsnamen prüfen (Kniebeugen, Hampelmann, etc.)
2. App auf Englisch: Englische Namen prüfen
3. Morning Stretch: "Beinschwingen rechts" vorhanden?
4. Info-Sheets: Deutsche Beschreibungen in DE App

---

## Geklärte Fragen

1. **"Plank":** → "Planke" (Deutsch) ✓
2. **Fehlende Übungen:** Systematisch geprüft - nur "Leg Swing Right" im Jogging Warm-up fehlt ✓
