# Tasks: Round Announcement "X of Y"

## Implementation Checklist

### Phase 1: TDD RED (Tests zuerst)

- [ ] Unit Test für neues Format in `WorkoutSoundPlayerTests.swift` schreiben
- [ ] Test muss FEHLSCHLAGEN (RED) da Feature noch nicht implementiert

### Phase 2: Implementation

- [ ] `WorkoutSoundPlayer.swift`:
  - [ ] `playRound(_ number: Int, of total: Int)` Signatur ändern
  - [ ] Format-String auf `"Round %d of %d"` ändern

- [ ] `WorkoutsView.swift`:
  - [ ] Zeile ~420: Format auf `"Round %d of %d"` ändern
  - [ ] Zeile ~423: `playRound(nextRound, of: cfgRepeats)` anpassen

- [ ] `WorkoutTab.swift`:
  - [ ] Zeile ~700: Format auf `"Round %d of %d"` ändern, `totalRepeats` übergeben
  - [ ] Zeile ~721: Format auf `"Round %d of %d"` ändern, `totalRepeats` übergeben

- [ ] `WorkoutProgramsView.swift`:
  - [ ] Zeile ~1371: Format anpassen (hat bereits Übungsname, erweitern)

- [ ] `Localizable.xcstrings`:
  - [ ] Neuen Key `"Round %d of %d"` hinzufügen
  - [ ] Deutsche Übersetzung `"Runde %d von %d"` hinzufügen

### Phase 3: TDD GREEN

- [ ] Unit Tests ausführen - müssen GRÜN sein
- [ ] Build verifizieren

### Phase 4: Validation

- [ ] Manuelle Tests auf Device (Voice-Ausgabe prüfen)
- [ ] Deutsche Lokalisierung prüfen

## Geschätzte Änderungen

| Datei | +/- LoC |
|-------|---------|
| WorkoutSoundPlayer.swift | ~5 |
| WorkoutsView.swift | ~5 |
| WorkoutTab.swift | ~10 |
| WorkoutProgramsView.swift | ~5 |
| Localizable.xcstrings | ~5 |
| WorkoutSoundPlayerTests.swift | ~20 |
| **Total** | **~50** |
