# Feature: Countdown vor Start

**Status:** Geplant
**Priorität:** Nice-to-have
**Geschätzter Aufwand:** ~150-200 LoC, 3-4 Dateien

---

## Zusammenfassung

Optionaler Countdown zwischen dem Drücken auf "Start" und dem tatsächlichen Beginn einer Session. Gibt dem Nutzer Zeit zum Bereitmachen (Hinsetzen, Position einnehmen, Augen schließen).

---

## Anforderungen

### Funktional

| Anforderung | Beschreibung |
|-------------|--------------|
| **Scope** | Alle 4 Tabs: Offen, Atem, Workouts, Frei |
| **Einstellung** | Global in Settings (eine Einstellung für alle Tabs) |
| **Zeitbereich** | 1-20 Sekunden via Picker-Walze |
| **Default** | Aus (0 Sekunden / deaktiviert) |
| **Auftakt-Sound** | Nach Countdown-Ende, vor Session-Start |

### Auftakt-Sounds

| Tab | Sound |
|-----|-------|
| Offen (Meditation) | Gong |
| Atem (Atmung) | Gong |
| Workouts (Programme) | Auftakt-Sound (existiert bereits) |
| Frei (freies Workout) | Auftakt-Sound (existiert bereits) |

---

## UI-Konzept

### Settings

- Neue Sektion: "Countdown vor Start" (o.ä.)
- Picker-Walze wie bei anderen Zeiteinstellungen
- Optionen: Aus, 1s, 2s, ... 20s

### Countdown-Overlay (während Wartezeit)

1. **Ring:** Fortschrittsring rückwärts laufend (100% → 0%)
2. **Zahl:** Große Countdown-Zahl in der Mitte (3... 2... 1...)
3. **Hinweis:** Kurzer Text, warum verzögert wird
4. **Settings-Link:** Direkter Link zu der Einstellung (z.B. Zahnrad-Icon)

**Beispiel-Layout:**
```
        ╭─────────────╮
        │    ◯ Ring   │
        │      3      │  ← Countdown-Zahl
        │             │
        │  ⚙️ Ändern  │  ← Link zu Settings
        ╰─────────────╯
```

---

## Technische Notizen

### Neues UI-Element: CountdownOverlayView

Eigenständiges Overlay, unabhängig von bestehenden Fortschrittsringen:

```swift
Circle()
    .trim(from: 0, to: progress)  // progress: 1.0 → 0.0
    .animation(.linear(duration: countdownSeconds))
```

Geschätzt ~50 Zeilen.

### Integration in Tabs

Vor dem eigentlichen Session-Start:

```swift
// Pseudocode
func onStartTapped() {
    if countdownSeconds > 0 {
        showCountdownOverlay = true
        // Nach Countdown:
        playAuftaktSound()
        startSession()
    } else {
        playAuftaktSound()
        startSession()
    }
}
```

### AppStorage Key

```swift
@AppStorage("countdownBeforeStart") var countdownSeconds: Int = 0
```

---

## Geklärte Details

- **Countdown abbrechbar:** Ja (via X-Button oder ähnlich)
- **Ambient-Sound während Countdown:** Ja, startet bereits mit Countdown

---

## Betroffene Dateien (geschätzt)

| Datei | Änderung |
|-------|----------|
| `SettingsSheet.swift` | Neue Sektion mit Picker |
| `CountdownOverlayView.swift` | **NEU** - Overlay-Komponente |
| `OffenView.swift` | Integration vor Start |
| `AtemView.swift` | Integration vor Start |
| `WorkoutProgramsView.swift` | Integration vor Start |
| `WorkoutsFreeView.swift` | Integration vor Start |

---

## Akzeptanzkriterien

- [ ] Einstellung in Settings verfügbar (Aus / 1-20s)
- [ ] Countdown-Overlay erscheint bei Start (wenn aktiviert)
- [ ] Ring läuft rückwärts, Zahl zählt runter
- [ ] Link zu Settings im Overlay funktioniert
- [ ] Nach Countdown: Auftakt-Sound spielt
- [ ] Danach: Session startet normal
- [ ] Bei "Aus": Kein Countdown, direkter Start wie bisher
