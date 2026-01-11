# Tasks: UI-Konsistenz Überschriften

## Implementierungs-Checkliste

### MeditationTab.swift

- [ ] **Überschrift "Open Meditation" aus GlassCard herausziehen**
  - Zeile ~254-265: HStack mit Text + InfoButton vor `GlassCard` verschieben
  - Gleiche Struktur wie "Breathing Exercises" Section Divider (Zeile 100-107)

- [ ] **Formatierung anpassen**
  - `.font(.title3)` → `.font(.headline)`
  - `.textCase(.uppercase)` entfernen

- [ ] **Labels in Card: `.textCase(.uppercase)` entfernen**
  - "Duration" Label (Zeile ~277)
  - "Closing" Label (Zeile ~285)

### WorkoutTab.swift

- [ ] **Überschrift "Free Workout" aus GlassCard herausziehen**
  - Zeile ~244-256: HStack mit Text + InfoButton vor `GlassCard` verschieben
  - Gleiche Struktur wie "Workout Programs" Section Divider (Zeile 71-78)

- [ ] **Formatierung anpassen**
  - `.font(.title3)` → `.font(.headline)`
  - `.textCase(.uppercase)` entfernen

- [ ] **Labels in Card: `.textCase(.uppercase)` entfernen**
  - "Work" Label (Zeile ~267)
  - "Rest" Label (Zeile ~276)
  - "Repetitions" Label (Zeile ~285)
  - "Total Duration" Label (Zeile ~326)

### Verifizierung

- [ ] Build erfolgreich
- [ ] UI-Test: Überschriften korrekt positioniert
- [ ] UI-Test: Keine Großbuchstaben mehr
