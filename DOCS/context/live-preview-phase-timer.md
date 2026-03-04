# Context: Live Preview – Phasen-Laufzeit anzeigen

## Request Summary
In der Live Activity (Dynamic Island + Lock Screen) soll neben der Gesamt-Laufzeit auch die Laufzeit der aktuellen Phase angezeigt werden.

## Ist-Zustand

### ContentState (Datenmodell)
**Datei:** `Meditationstimer iOS/MeditationActivityAttributes.swift`
```swift
struct ContentState: Codable, Hashable {
    var endDate: Date      // Ende der aktuellen Phase → Countdown
    var phase: Int         // 1 = Meditation/Work, 2 = Besinnung/Rest
    var ownerId: String?   // "OffenTab", "AtemTab", "WorkoutsTab"
    var isPaused: Bool
}
```

**Problem:** Kein Feld für Phase-Start, Phase-Dauer oder Session-Gesamtende.

### Wie wird `endDate` aktuell gesetzt?

| Tab | Phase 1 endDate | Phase 2 endDate | Zeigt also |
|-----|----------------|-----------------|-----------|
| **OffenTab** | `phase1EndDate` (Phase 1 Ende) | `engine.endDate` (Session Ende) | Per-Phase Countdown |
| **WorkoutsTab** | `sessionStart + sessionTotal` | `now + remaining total` | **Gesamt-Countdown** |
| **AtemTab** | (nicht implementiert) | — | — |

### Aktuelles Layout

**Lock Screen:** `[Phase-Icon] [Spacer] [Timer 40pt] [Spacer]`
**Dynamic Island Compact:** `[Phase-Icon 20pt] ... [Timer 12pt]`
**Dynamic Island Expanded:** `[Phase-Icon 52pt] ... [Timer 36pt]`

→ Es wird nur EIN Timer angezeigt (der `endDate` Countdown).

## Related Files

| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/MeditationActivityAttributes.swift` | ContentState Datenmodell – muss erweitert werden |
| `MeditationstimerWidget/MeditationActivityAttributes.swift` | **Widget-Kopie** – muss identisch geändert werden! |
| `MeditationstimerWidget/MeditationstimerWidgetLiveActivity.swift` | UI der Live Activity – Layout muss angepasst werden |
| `MeditationstimerWidget/LiveActivityTimerLogic.swift` | Autonome Phase-Berechnung für Widget |
| `Meditationstimer iOS/LiveActivityController.swift` | Controller – start/update Signatur erweitern |
| `Meditationstimer iOS/Tabs/OffenView.swift` | Caller – muss neue Daten mitgeben |
| `Meditationstimer iOS/Tabs/WorkoutTab.swift` | Caller – muss Phase-spezifische Daten mitgeben |

## Existing Patterns

1. **Timer-Darstellung:** `Text(endDate, style: .timer)` für live Countdown (OS-gesteuert, batterieschonend)
2. **Elapsed Time:** `Text(timerInterval: startDate...endDate, countsDown: false)` – Apple-Pattern für verstrichene Zeit
3. **Duale Achse:** ContentState ist < 4KB beschränkt (Push-fähig) – Felder sparsam halten
4. **Widget-Duplikat:** MeditationAttributes existiert in 2 Targets (iOS + Widget) – beide MÜSSEN synchron geändert werden

## Apple Layout-Constraints

| Präsentation | Max Höhe | Breite | Eignung für 2 Timer |
|---|---|---|---|
| **Lock Screen** | 160 pt | Voll | ✅ Genug Platz für 2 Zeilen |
| **DI Compact** | 36 pt (fix) | Sehr eng | ⚠️ Nur 1 Timer realistisch |
| **DI Expanded** | 144 pt | Voll | ✅ Platz für Bottom-Region |
| **DI Minimal** | ~37 pt | ~45 pt | ❌ Nur Icon |

## Dependencies

**Upstream (was unser Code nutzt):**
- ActivityKit Framework
- TwoPhaseTimerEngine (engine.phase1EndDate, engine.endDate, engine.startDate)

**Downstream (was unseren Code nutzt):**
- Widget Extension rendert ContentState
- LiveActivityTimerLogic berechnet Phasen autonom

## Risks & Considerations

1. **ContentState-Änderung ist Breaking:** Beide Targets (iOS + Widget) müssen synchron aktualisiert werden
2. **Compact DI hat kaum Platz:** Zweiter Timer dort vermutlich nicht möglich
3. **Pause-Handling:** Bei Pause muss auch der Phase-Timer korrekt einfrieren
4. **WorkoutsTab Phase-Wechsel:** Work/Rest-Intervalle wechseln häufig – viele Updates nötig
5. **`Text(_, style: .timer)` zählt NUR runter:** Für Elapsed Time brauchen wir `Text(timerInterval:countsDown:false)`

---

## Analysis

### Type
Feature

### Existing Specs
- `openspec/specs/integrations/live-activities.md` — Phase-Anzeige ist dort bereits als Requirement definiert (Line 46, 79-83), aber noch nicht implementiert
- `openspec/specs/features/meditation-timer.md` — TwoPhaseTimerEngine Datenquellen
- `openspec/specs/features/workouts.md` — Work/Rest-Phasen, phase indicator

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/MeditationActivityAttributes.swift` | MODIFY | +1 Feld: `phaseStartDate: Date` |
| `MeditationstimerWidget/MeditationActivityAttributes.swift` | MODIFY | Mirror: identische Änderung |
| `Meditationstimer iOS/LiveActivityController.swift` | MODIFY | Neue Parameter in start()/update() |
| `MeditationstimerWidget/MeditationstimerWidgetLiveActivity.swift` | MODIFY | UI: Phase-Timer in Lock Screen + Expanded DI |
| `Meditationstimer iOS/Tabs/OffenView.swift` | MODIFY | Caller: phaseStartDate übergeben (~5 Stellen) |
| `Meditationstimer iOS/Tabs/WorkoutTab.swift` | MODIFY | Caller: phaseStartDate übergeben (~2 Stellen) |

### Scope Assessment
- Files: 6 (leicht über 5er-Limit, aber Caller-Änderungen sind minimal: nur +1 Parameter)
- Estimated LoC: +35 / -5 (~40 LoC netto)
- Risk Level: LOW (keine Logik-Änderung, nur Datenanreicherung + UI)

### Technical Approach

**Empfehlung: `phaseStartDate` zum ContentState hinzufügen**

1. ContentState bekommt ein neues Feld `phaseStartDate: Date`
2. LiveActivityController übergibt es bei start() und update()
3. Widget nutzt Apples eingebauten Timer-Mechanismus:
   - Bestehend: `Text(endDate, style: .timer)` → Countdown (verbleibende Phase-Zeit)
   - Neu: `Text(timerInterval: phaseStartDate...endDate, countsDown: false)` → Elapsed (verstrichene Phase-Zeit)
4. Beide Timer laufen OS-gesteuert — keine zusätzlichen App-Updates nötig

**Warum diesen Ansatz:**
- Nur 1 neues Feld statt 2-3
- Apple `Text(timerInterval:)` ist batterieschonend (OS-gesteuert)
- Pause-Handling: Bei isPaused wird statischer Text angezeigt (bestehendes Pattern)

### Dependencies
- TwoPhaseTimerEngine: Alle Daten bereits verfügbar (startDate, phase1EndDate, endDate)
- Keine neuen Frameworks nötig
- Keine Service-Änderungen nötig

### Open Questions
- [ ] Soll die Phase-Laufzeit als "verstrichene Zeit" (hochzählend) oder als "Gesamt-Dauer der Phase" (statisch, z.B. "10:00") angezeigt werden?
- [ ] Layout-Frage: Wo genau soll der zweite Timer erscheinen? (unter dem Countdown? daneben?)
