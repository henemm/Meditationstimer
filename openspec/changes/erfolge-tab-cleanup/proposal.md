# Erfolge Tab Cleanup

## Problem

Der Erfolge Tab hat drei architektonische Probleme:

1. **Redundante Streak-Anzeige:** `StreakHeaderSection` oben zeigt dieselben Daten wie die Streak-Info-Sektion unten
2. **Verschachtelte Navigation:** CalendarView hat eigenen `NavigationView`, der mit `NavigationStack` aus ErfolgeTab kollidiert
3. **Sinnloser "Fertig" Button:** `dismiss()` tut nichts, weil CalendarView eingebettet ist (nicht als Sheet)

## Ursache

CalendarView wurde ursprünglich als modales Sheet entwickelt (mit eigenem NavigationView + "Fertig" Button). Bei der Tab-Refaktorierung (Phase 1.1) wurde sie direkt in ErfolgeTab eingebettet, aber die Sheet-Struktur nicht angepasst.

## Lösung

### 1. StreakHeaderSection entfernen (ErfolgeTab.swift)

Die komplette `StreakHeaderSection` und `CompactStreakBadge` Views entfernen, da die Streak-Informationen bereits in der unteren Sektion der CalendarView angezeigt werden.

### 2. isEmbedded Parameter (CalendarView.swift)

Neuen Parameter `isEmbedded: Bool = false` einführen:
- `isEmbedded = false` (Default): Mit NavigationView + Toolbar (für Sheet-Aufrufe)
- `isEmbedded = true`: Ohne NavigationView + Toolbar (für ErfolgeTab)

### 3. ErfolgeTab anpassen

`CalendarView(isEmbedded: true)` aufrufen.

## Betroffene Dateien

| Datei | Änderung |
|-------|----------|
| `ErfolgeTab.swift` | StreakHeaderSection entfernen, `isEmbedded: true` übergeben |
| `CalendarView.swift` | `isEmbedded` Parameter hinzufügen, bedingte Navigation |

## Nicht betroffen (keine Änderung nötig)

- `OffenView.swift` - nutzt CalendarView als Sheet (Default `isEmbedded: false`)
- `AtemView.swift` - nutzt CalendarView als Sheet
- `WorkoutProgramsView.swift` - nutzt CalendarView als Sheet

## Scoping

- **Dateien:** 2
- **LoC:** ~-50 (Entfernen > Hinzufügen)
- **Risiko:** Niedrig (rein UI-Cleanup, keine Logik-Änderung)
