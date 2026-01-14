# Standard: Verify Active Code Location

## Problem (Bug 32 - 2025-12-21)

Es existierten zwei parallele Implementierungen:
- `WorkoutsView.swift` - alte, unbenutzte Version
- `WorkoutTab.swift` - aktive Version (verwendet in ContentView.swift)

Stundenlange Debugging-Arbeit an der falschen Datei.

## Pflicht-Check vor jeder Code-Änderung

**BEVOR du Code änderst, prüfe IMMER:**

```bash
# 1. Welche View wird in ContentView.swift verwendet?
grep -n "Tab\|View" "Meditationstimer iOS/ContentView.swift" | head -20

# 2. Gibt es Duplikate der Klasse/Struct die du ändern willst?
grep -rn "struct MyView\|class MyClass" "Meditationstimer iOS/"
```

## Checkliste

| Check | Befehl |
|-------|--------|
| Welche View ist aktiv? | `grep "Tab\|View" ContentView.swift` |
| Gibt es Duplikate? | `grep -rn "struct XYZ" .` |
| Wird meine Datei überhaupt verwendet? | `grep -rn "MyFileName" .` |

## Warnsignale

- Dateiname enthält "View" aber es gibt auch eine "Tab" Variante
- Logs erscheinen nicht obwohl Code korrekt aussieht
- Änderungen haben keinen Effekt

## Konsequenz bei Verstoß

Stunden verschwendet, User frustriert, Tokens verbrannt.

---

**Erstellt nach Bug 32 - Free Workout Sound funktionierte nicht weil falsche Datei bearbeitet wurde.**
