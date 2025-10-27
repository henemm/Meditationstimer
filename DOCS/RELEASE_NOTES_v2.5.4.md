# Release Notes v2.5.4

**Release Date:** 27. Oktober 2025
**Type:** Patch Release (UI Improvements & Bug Fixes)

## 🎨 UI-Verbesserungen

### Settings Navigation
- **Modernisiert:** Settings verwenden jetzt `.fullScreenCover()` statt `.navigationDestination()`
- **Vollflächig:** Settings überlagern jetzt komplett die TabBar (kein versehentliches Tab-Switching mehr)
- **Fertig-Button:** Neuer "Fertig"-Button oben rechts zum Schließen hinzugefügt
- **Konsistent:** Gleiche Präsentation wie CalendarView

### Session Focus
- **TabBar versteckt:** Während aktiver Sessions (Offen/Atem/Workouts) ist die TabBar ausgeblendet
- **Toolbar konditionell:** Kalender/Settings Buttons nur im Idle-Zustand sichtbar
- **Verhindert Multi-Sessions:** User kann nicht versehentlich mehrere Sessions gleichzeitig starten

### WorkoutsView Fixes
- **X-Button Position:** Jetzt konsistent mit AtemView (ganz oben rechts, korrekte Positionierung)
- **Safe Area:** WorkoutRunnerView respektiert jetzt Safe Area
  - X-Button nicht mehr unter Dynamic Island (war unklickbar)
  - Nur Background ignoriert Safe Area (reicht unter Notch)
- **Ringe Farbe:** Progress-Ringe jetzt korrekt in workoutViolet (Gradient hell→dunkel)

## 🔧 Technische Änderungen

### CircularRing Component
- **Neuer Parameter:** `gradient: LinearGradient?` (optional)
- **Backward Compatible:** Default bleibt blue/cyan für OffenView/AtemView
- **Custom Gradients:** WorkoutsView kann jetzt workoutViolet Gradient übergeben

### Code Locations
- `SettingsSheet.swift` - Fertig-Button + @Environment(\.dismiss)
- `OffenView.swift`, `AtemView.swift`, `WorkoutsView.swift` - Toolbar/TabBar conditional hiding
- `WorkoutsView.swift` - X-Button overlay auf ZStack, Safe Area Fix, gradient Parameter
- `CircularRing.swift` - Optional gradient Parameter mit default

## ✅ Verifikation

**Build Status:** ✅ BUILD SUCCEEDED

**Zu testen:**
- [ ] Settings öffnen → vollflächig, "Fertig"-Button funktioniert
- [ ] Session starten (alle Tabs) → TabBar + Toolbar verschwinden
- [ ] X-Button WorkoutsView → korrekte Position, klickbar
- [ ] WorkoutsView Ringe → violett (nicht blau)
- [ ] OffenView/AtemView Ringe → blau (unverändert)

## 🐛 Bekannte Probleme

*Keine neuen Probleme in diesem Release*

## 📦 Commits in diesem Release

```
521986d docs: Update current-todos.md mit UI-Verbesserungen v2.5.4
d4e4381 fix: WorkoutsView Ringe jetzt korrekt in workoutViolet
1428d1d Revert "fix: CircularRing respektiert jetzt foregroundStyle von Parent"
443f8f0 fix: CircularRing respektiert jetzt foregroundStyle von Parent
24da649 fix: WorkoutRunnerView Safe Area respektieren
4266036 fix: X-Button Position in WorkoutsView korrigiert
b103686 fix: Fertig-Button zu SettingsSheet hinzugefügt
4231fc1 fix: UI-Konsistenz-Fixes für Settings, Kalender und X-Button
3bb4bae fix: Toolbar (Calendar/Settings) während Sessions verstecken
89c9e60 fix: TabBar während Sessions verstecken (alle Tabs)
```

## 📝 Nächste Schritte

- Device Testing auf iPhone mit Dynamic Island
- User Testing aller UI-Änderungen
- Feedback sammeln für weitere Verbesserungen
