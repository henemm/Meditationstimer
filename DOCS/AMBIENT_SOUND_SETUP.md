# Hintergrundsounds Setup-Anleitung

## ✅ Code ist fertig implementiert

Die Hintergrundsound-Funktionalität ist vollständig implementiert, aber **zwei manuelle Schritte in Xcode** sind nötig:

---

## 📁 Schritt 1: AmbientSoundPlayer.swift zum Target hinzufügen

**Problem:** Xcode kennt die neue Datei noch nicht → Build-Error

**Lösung:**
1. Öffne `Meditationstimer.xcodeproj` in Xcode
2. Im Project Navigator: Rechtsklick auf `Services/` Ordner
3. **"Add Files to Meditationstimer..."**
4. Wähle `Services/AmbientSoundPlayer.swift`
5. ✅ Haken bei **"Lean Health Timer"** Target setzen
6. "Add" klicken

**Alternative (falls Datei schon sichtbar):**
1. Wähle `AmbientSoundPlayer.swift` im Navigator
2. Rechte Sidebar → **File Inspector** (Ordner-Icon)
3. **Target Membership:** Haken bei "Lean Health Timer" setzen

---

## 🎵 Schritt 2: Audio-Dateien hinzufügen

Du musst **3 Audio-Dateien** ins Xcode-Projekt einfügen:

### Dateien (von dir bereitgestellt):
- `waves.caf` (oder `.mp3`)
- `spring.caf` (oder `.mp3`)
- `fire.caf` (oder `.mp3`)

### Voraussetzungen:
- **Loopable Sounds** (nahtloser Übergang am Ende → Anfang)
- Empfohlene Dauer: **30-60 Sekunden**
- Format: **.caf** bevorzugt (bester iOS-Support), alternativ **.mp3** oder **.wav**

### In Xcode hinzufügen:
1. Dateien in Xcode ziehen (auf Project Root oder Resources-Ordner)
2. **"Copy items if needed"** ✅ ankreuzen
3. **"Add to targets: Lean Health Timer"** ✅ ankreuzen
4. "Finish" klicken

**Testen:**
- Öffne **Product → Scheme → Edit Scheme**
- Run → Info → Build Configuration: **Debug**
- Falls Dateien fehlen: Console zeigt `[AmbientSound] Audio file not found: waves`

---

## 🧪 Test-Plan

Nach Setup testen:

### 1. Settings öffnen
- **Einstellungen → Hintergrundsounds**
- Picker zeigt: "Kein Sound", "Waves", "Spring", "Fire" ✅

### 2. Offen-Tab Test
- Settings: "Waves" auswählen
- Offen-Tab: Session starten
- **Erwartung:** Waves-Sound faded langsam ein (3s), dann Loop
- Gong spielt normal über Ambient
- Session beenden → Ambient faded aus (3s)

### 3. Atem-Tab Test
- Settings: "Spring" auswählen
- Atem-Tab: Preset starten
- **Erwartung:** Spring-Sound faded ein, loopt nahtlos
- Breathing-Cues (einatmen/ausatmen) spielen über Ambient
- Session beenden → Ambient faded aus

### 4. "Kein Sound" Test
- Settings: "Kein Sound"
- Session starten → **kein Ambient-Sound** ✅
- Nur Gongs/Cues hörbar

---

## 🎨 Feature-Details

### Lautstärke
- **Ambient: 45%** (angenehme Balance mit Gongs)
- **Gongs: 100%** (unverändert, kein Audio-Ducking)

### Cross-Fade Looping
- Player A spielt Sound
- Bei **T-7s** startet Player B (fade-in)
- Player A faded out während Player B faded in
- **7 Sekunden Überlappung** für nahtlosen Loop

### Start/Stop Transitions
- **Start:** 3s Fade-In
- **Stop:** 3s Fade-Out
- Kein abruptes Ein-/Ausschalten

---

## ⚠️ Troubleshooting

### Build-Fehler: "Cannot find 'AmbientSound' in scope"
→ **Schritt 1** nicht durchgeführt (Datei nicht zum Target hinzugefügt)

### "Audio file not found" in Console
→ **Schritt 2** nicht durchgeführt (Audio-Dateien fehlen im Bundle)

### Sound spielt nicht
- Prüfe Settings: Ist "Kein Sound" ausgewählt?
- Prüfe Device-Lautstärke
- Prüfe ob Audio-Datei korrekt benannt (z.B. `waves.caf`, nicht `Waves.caf`)

### Sound "hackt" oder springt
- Audio-Datei ist **nicht loopable** (Start/Ende passen nicht)
- Datei in Audio-Editor öffnen und nahtlosen Loop erstellen

---

## 📝 Nächste Schritte

1. **Schritt 1 + 2** in Xcode durchführen
2. **Build** (Cmd+B) → sollte erfolgreich sein
3. **Testen** mit allen 3 Sounds
4. **Feedback** geben, falls etwas nicht funktioniert

Bei Fragen: Beschreib das Problem mit Console-Logs!
