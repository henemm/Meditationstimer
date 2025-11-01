# 📘 FEATURE SPEC — Sound-Presets für Atem-Meditation

**Target Project:** `Lean Health Timer`
**Environment:** iOS 18 / Xcode 26 / SwiftUI
**Feature Scope:** Atem Tab (Phase 1), später Offen + Workouts
**Goal:** Auswahl verschiedener Klangpakete/Sound-Themes für Atem-Meditationen mit Settings-Integration.

---

## 🧩 1. Context Overview

Die App hat aktuell:
- **Atem-Tab** mit Breathing-Presets (Box 4-4-4-4, 4-0-6-0, etc.)
- **4 Audio-Cues** für Atemphasen:
  - `einatmen.caf`
  - `eingeatmet-halten.caf`
  - `ausatmen.caf`
  - `ausgeatmet-halten.caf`
- **GongPlayer Service** (nested in AtemView) für Audio-Playback
- **soundName(for: Phase)** Mapping in SessionEngine

**Problem:**
- Nutzer können Sound-Style nicht anpassen
- Nur ein festes Sound-Set verfügbar
- Unterschiedliche Vorlieben für "markante" vs. "sanfte" Cues

---

## 🎯 2. Objective

Ermögliche Auswahl zwischen verschiedenen Sound-Themes für Atem-Cues.

**MVP (Phase 1):**
- 5 Sound-Themes: **Markant** 🔔, **Marimba** 🎵, **Harfe** 🪕, **Gitarre** 🎸, **E-Piano** 🎹
- Globale Auswahl in Settings (kein Per-Session Override)
- Preview-Button zum Sound-Testen
- Beschreibungstext für jedes Theme
- Nur **Atem-Tab** (nicht Offen/Workouts)

**Zukunft (Phase 2):**
- Erweiterung auf Offen-Tab (Gong-Varianten)
- Erweiterung auf Workouts-Tab (Countdown-Sounds)

---

## ⚙️ 3. Technical Requirements

### 3.1 Data Model

**SoundTheme Enum** (in AtemView.swift oder separates Model)

```swift
enum AtemSoundTheme: String, Codable, CaseIterable {
    case markant = "markant"
    case marimba = "marimba"
    case harfe = "harfe"
    case gitarre = "gitarre"
    case epiano = "epiano"

    var displayName: String {
        switch self {
        case .markant: return "Markant"
        case .marimba: return "Marimba"
        case .harfe: return "Harfe"
        case .gitarre: return "Gitarre"
        case .epiano: return "E-Piano"
        }
    }

    var emoji: String {
        switch self {
        case .markant: return "🔔"
        case .marimba: return "🎵"
        case .harfe: return "🪕"
        case .gitarre: return "🎸"
        case .epiano: return "🎹"
        }
    }

    var description: String {
        switch self {
        case .markant: return "Klare, deutliche Signale"
        case .marimba: return "Warme, hölzerne Klänge"
        case .harfe: return "Sanfte, fließende Töne"
        case .gitarre: return "Akustische Zupftöne"
        case .epiano: return "Weiche, elektronische Klänge"
        }
    }
}
```

**AppStorage Key:**
```swift
@AppStorage("atemSoundTheme") var selectedTheme: AtemSoundTheme = .markant
```

---

### 3.2 Audio File Naming Convention

**Strategie:** Theme-Prefix Naming (kompakt)

**Struktur:**
```
<theme>-<phase-suffix>.caf

Phase-Suffixe:
  in       → Einatmen
  inhold   → Halten nach Einatmen
  out      → Ausatmen
  outhold  → Halten nach Ausatmen
```

**Beispiele:**
```
markant-in.caf
markant-inhold.caf
markant-out.caf
markant-outhold.caf

marimba-in.caf
marimba-inhold.caf
marimba-out.caf
marimba-outhold.caf

harfe-in.caf
gitarre-in.caf
epiano-in.caf
... (jeweils 4 Files pro Theme)
```

**Total Audio Files (MVP):**
- **20 .caf Files** (5 Themes × 4 Phasen)
- User erstellt alle Files selbst (AIFF → CAF Konvertierung, siehe unten)

**Location:**
- `Meditationstimer iOS/Media/AtemSounds/` (neue Untergruppe)

---

### 3.3 Sound Playback Logic

**Aktueller Code (AtemView.swift:391-398):**
```swift
func soundName(for phase: Phase) -> String {
    switch phase {
    case .inhale: return "einatmen"
    case .holdIn: return "eingeatmet-halten"
    case .exhale: return "ausatmen"
    case .holdOut: return "ausgeatmet-halten"
    }
}
```

**Neuer Code (Theme-aware):**
```swift
@AppStorage("atemSoundTheme") private var soundTheme: AtemSoundTheme = .markant

func soundName(for phase: Phase) -> String {
    let suffix: String
    switch phase {
    case .inhale: suffix = "in"
    case .holdIn: suffix = "inhold"
    case .exhale: suffix = "out"
    case .holdOut: suffix = "outhold"
    }
    return "\(soundTheme.rawValue)-\(suffix)"
}
```

**Beispiel-Ausgaben:**
- `soundName(for: .inhale)` → `"markant-in"`
- `soundName(for: .holdOut)` → `"gitarre-outhold"`

**GongPlayer bleibt unverändert** (sucht automatisch .caf/.wav/.mp3)

---

### 3.4 Settings UI Integration

**Location:** SettingsSheet.swift (oder inline in ContentView Settings)

**UI Design:**

```swift
@StateObject private var previewPlayer = GongPlayer()
@AppStorage("atemSoundTheme") private var selectedTheme: AtemSoundTheme = .markant

Section(header: Text("Atem-Sounds 🎵")) {
    // Theme Picker
    Picker("Sound-Theme", selection: $selectedTheme) {
        ForEach(AtemSoundTheme.allCases, id: \.self) { theme in
            HStack {
                Text(theme.emoji)
                Text(theme.displayName)
            }
            .tag(theme)
        }
    }
    .pickerStyle(.menu)

    // Beschreibungstext
    Text(selectedTheme.description)
        .font(.caption)
        .foregroundColor(.secondary)

    // Preview-Button
    Button(action: {
        previewPlayer.play(named: "\(selectedTheme.rawValue)-in")
    }) {
        HStack {
            Image(systemName: "play.circle.fill")
            Text("Sound testen")
        }
    }
}
```

**Features:**
- Picker mit Emoji + Name für alle 5 Themes
- Beschreibung (dynamisch basierend auf gewähltem Theme)
- Preview-Button (spielt `<theme>-in.caf` ab)

---

## 📦 4. Implementation Plan

### Phase 1: MVP (5 Themes)

**Code-Änderungen:**

| File | Changes | LoC |
|------|---------|-----|
| `AtemView.swift` | • Add `AtemSoundTheme` enum (5 cases + displayName/emoji/description)<br>• Add `@AppStorage("atemSoundTheme")`<br>• Update `soundName(for:)` in both SessionEngine copies | ~60 |
| `SettingsSheet.swift` | • Add Sound-Theme Picker Section<br>• Add Preview-Button<br>• Add Description Text | ~35 |
| **Total** | | **~95 LoC** |

**Audio Assets (User-Aufgabe):**

**Schritt 1: AIFF → CAF Konvertierung**

```bash
# macOS Terminal: Im Ordner mit AIFF-Files

# Einzelne Datei:
afconvert -f caff -d LEI16 markant-in.aiff markant-in.caf

# Batch-Konvertierung (alle AIFF → CAF):
for file in *.aiff; do
  afconvert -f caff -d LEI16 "$file" "${file%.aiff}.caf"
done
```

**Schritt 2: Xcode Integration**

1. In Xcode: Rechtsklick auf `Media/` → "New Group" → `AtemSounds`
2. Drag & Drop alle 20 .caf Files in `Media/AtemSounds/`
3. Verify: Checkbox "Add to targets: Lean Health Timer" ✅
4. Build Phases → Copy Bundle Resources: Verify alle 20 Files listed

**File-Liste (Total: 20 Files):**
```
markant-in.caf, markant-inhold.caf, markant-out.caf, markant-outhold.caf
marimba-in.caf, marimba-inhold.caf, marimba-out.caf, marimba-outhold.caf
harfe-in.caf, harfe-inhold.caf, harfe-out.caf, harfe-outhold.caf
gitarre-in.caf, gitarre-inhold.caf, gitarre-out.caf, gitarre-outhold.caf
epiano-in.caf, epiano-inhold.caf, epiano-out.caf, epiano-outhold.caf
```

---

### Phase 2: Erweiterung (Zukunft)

**Erweiterung auf andere Tabs:**
- **Offen-Tab:** Gong-Varianten (`gong-<theme>.caf`, `gong-dreimal-<theme>.caf`, etc.)
- **Workouts-Tab:** Countdown-Sounds (separates Theme-System oder kombiniert)

**Scope:** Pro Tab-Erweiterung ~40-60 LoC

---

## 🧪 5. Testing Strategy

### Unit Tests

**Nicht erforderlich** (keine Business Logic, nur UI + Asset Loading)

### Manual Testing

**Test-Checkliste:**

1. **Settings:**
   - [ ] Picker zeigt alle Themes
   - [ ] Theme-Wechsel wird gespeichert (AppStorage persistence)
   - [ ] Emoji + Name korrekt angezeigt

2. **Audio Playback:**
   - [ ] "Markant" Theme: Bisherige Sounds spielen korrekt
   - [ ] "Sanft" Theme: Neue Sounds spielen korrekt
   - [ ] Alle 4 Phasen (einatmen, halten-ein, ausatmen, halten-aus) getestet
   - [ ] Fallback bei fehlendem Sound (silent, kein Crash)

3. **Session Flow:**
   - [ ] Preset starten → Theme wird korrekt verwendet
   - [ ] Theme während laufender Session ändern → nächste Session verwendet neues Theme
   - [ ] Kein Einfluss auf Timer-Logik (nur Audio betroffen)

4. **Upgrade-Szenario:**
   - [ ] App-Update mit umbenannten Sounds: Alte Sessions funktionieren weiter
   - [ ] Default-Theme "Markant" für Bestandsnutzer

**Device Testing:**
- iPhone (iOS 18+)
- iPad (optional, falls supported)
- Simulator (Audio-Wiedergabe verifizieren)

---

## 📋 6. File Changes Summary

**Neue Files:**
- `DOCS/feature-sound-presets.md` (dieses Dokument)
- `Meditationstimer iOS/Media/AtemSounds/` (Verzeichnis)

**Geänderte Files:**
- `Meditationstimer iOS/Tabs/AtemView.swift` (~60 LoC)
- `Meditationstimer iOS/SettingsSheet.swift` (~35 LoC)

**Audio Assets:**
- 20 neue .caf Files (User liefert via AIFF→CAF Konvertierung)

**Total Scope:** ~95 LoC, 20 Audio-Assets, 1 neues Verzeichnis

---

## 🚧 7. Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Audio-Dateien fehlen** | App spielt keine Sounds ab | GongPlayer hat silent fallback (kein Crash) |
| **Bundle-Größe wächst** | App-Download größer (+~3-5 MB) | .caf Format ist kompakt; 20 Files akzeptabel |
| **Theme-Namen lokalisieren?** | Nur Deutsche UI | MVP OK; Phase 2: Localizable.strings |
| **AIFF→CAF Konvertierung fehlerhaft** | Verzerrte Sounds, Knackser | afconvert mit `-d LEI16` (getestet, standard) |
| **User liefert falsche File-Namen** | Sound wird nicht gefunden | Build läuft trotzdem (silent fallback), aber Testing zeigt Fehler |

---

## 🎯 8. Success Metrics

**MVP gilt als erfolgreich, wenn:**
1. Build erfolgreich (keine Compile-Errors)
2. 5 Themes ("Markant", "Marimba", "Harfe", "Gitarre", "E-Piano") in Settings wählbar
3. Theme-Wechsel ändert Audio in Atem-Sessions (alle 4 Phasen)
4. Preview-Button spielt korrekten Sound ab
5. Beschreibungstext zeigt sich korrekt
6. Kein Audio-Fehler im Log (silent fallback funktioniert bei fehlenden Files)

**Definition of Done:**
- Code compiliert ✅
- Manual Testing Checklist durchlaufen ✅
- Commit mit Conventional Commits ✅
- ACTIVE-roadmap.md geupdatet ✅

**Zukunft (Phase 2):**
- Erweiterung auf Offen + Workouts Tabs

---

## 🗂️ 9. Implementation Checklist

**Vor Implementation:**
- [x] User approval dieser Spec
- [x] Audio-Files Naming Convention geklärt (theme-in.caf, theme-inhold.caf, etc.)
- [x] AIFF→CAF Konvertierungsanleitung dokumentiert
- [ ] User erstellt 20 Audio-Files (AIFF → CAF)

**Während Implementation (Claude):**
- [ ] Create `Media/AtemSounds/` Verzeichnis in Xcode
- [ ] `AtemSoundTheme` Enum erstellen (5 cases + displayName/emoji/description)
- [ ] `soundName(for:)` in beiden SessionEngine Instanzen updaten
- [ ] Settings Picker + Preview-Button + Description hinzufügen
- [ ] Build testen (ohne Audio-Files, nur Code-Struktur)

**Audio Integration (User):**
- [ ] 20 .caf Files in `Media/AtemSounds/` Drag & Drop (Xcode)
- [ ] Verify: "Add to targets: Lean Health Timer" ✅
- [ ] Build Phases → Copy Bundle Resources: alle 20 Files listed

**Nach Implementation:**
- [ ] Manual Testing (alle Checkboxen in Sektion 5)
- [ ] Commit mit Convention: `feat: Add sound theme selection for Atem meditation (5 themes)`
- [ ] Update ACTIVE-roadmap.md (Feature "Klangpakete/-Presets" löschen)

---

**Status:** ✅ Spec approved, ready for implementation
**Nächster Schritt:** Implementation starten
