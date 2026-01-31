# HealthKit First Prinzip

## Regel

**PFLICHT:** Wenn ein passender HealthKit-Typ für einen Tracker existiert, MUSS HealthKit verwendet werden.

HealthKit ist die **Source of Truth** für alle Gesundheitsdaten. SwiftData-only (`local`) Storage ist **NUR erlaubt**, wenn kein passender HealthKit-Typ existiert.

---

## Begründung

1. **Interoperabilität:** User können Daten in anderen Apps sehen (Apple Health, Fitness)
2. **Datensicherheit:** HealthKit hat eigene Backup/Sync-Mechanismen
3. **Konsistenz:** Eine Source of Truth verhindert Daten-Divergenz
4. **User-Erwartung:** Gesundheitsdaten gehören in Apple Health

---

## Verfügbare HealthKit-Typen

| HealthKit Identifier | Tracker-Typ | Wert-Format |
|---------------------|-------------|-------------|
| `HKQuantityTypeIdentifierNumberOfAlcoholicBeverages` | NoAlc | 0, 4, 6 (Level) |
| `HKQuantityTypeIdentifierDietaryWater` | Wasser | ml |
| `HKQuantityTypeIdentifierDietaryCaffeine` | Kaffee | mg |
| `HKCategoryTypeIdentifierStateOfMind` | Stimmung/Mood | 1-5 |
| `HKCategoryTypeIdentifierSleepAnalysis` | Schlaf | Start/End |
| `HKCategoryTypeIdentifierMindfulSession` | Achtsamkeit | Duration |

---

## StorageStrategy Entscheidungsbaum

```
Neuer Tracker wird erstellt
         │
         ▼
Existiert passender HK-Typ?
         │
    ┌────┴────┐
    │ JA      │ NEIN
    ▼         ▼
.healthKit()  .local
oder          (erlaubt)
.both()
(PFLICHT)
```

---

## Wann `.local` erlaubt ist

- **Saboteur-Tracker:** Doomscrolling, Prokrastination (kein HK-Typ)
- **Custom Habits:** Benutzerdefinierte Tracker ohne Gesundheitsbezug
- **Gratitude/Journal:** Textbasierte Einträge

---

## Wann `.both()` statt `.healthKit()` verwenden

- Wenn lokaler Cache für Offline-Zugriff nötig ist
- Wenn zusätzliche Metadaten (Notes, Tags) gespeichert werden
- Wenn schnelle UI-Updates ohne HK-Query nötig sind

**Aber:** HealthKit bleibt Source of Truth, SwiftData ist nur Cache!

---

## Verstoß-Konsequenzen

Bei Verstoß gegen dieses Prinzip:
1. Code Review blockiert
2. Nachträgliche Migration erforderlich
3. Potenzielle Daten-Inkonsistenz

---

## Referenzen

- `openspec/specs/features/generic-tracker-system.md` - StorageStrategy Definition
- `openspec/specs/features/noalc-tracker.md` - HealthKit Integration Beispiel
- `.agent-os/standards/healthkit/data-consistency.md` - Konsistenz-Regeln
