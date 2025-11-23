# Usability Improvements - Concept Document

**Status:** Planungsphase
**Erstellt:** 12. November 2025
**Priorität:** Mittel
**Aufwand:** ~3-5 Stunden

---

## Überblick

Verbesserung der Benutzerführung durch:
1. **Info-Buttons (ⓘ)** für Erklärungen zu Tabs/Sheets
2. **Kachel-Headers** für bessere visuelle Hierarchie
3. **Internationalisierung** vorbereiten für zukünftige englische Übersetzung

---

## 1. Info-Button Pattern

### Design-Prinzip
Konsistente Info-Buttons an zentralen Stellen, die Sheets mit Erklärungen öffnen:
- **Icon:** SF Symbol `info.circle` (oder `info.circle.fill`)
- **Platzierung:** Top-right oder neben Header-Text
- **Interaktion:** Tap → Sheet mit Erklärung (`.presentationDetents([.medium])`)
- **Stil:** `.symbolRenderingMode(.hierarchical)`, `.foregroundStyle(.secondary)`

### SwiftUI Komponente (Wiederverwendbar)

```swift
struct InfoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .font(.title3)
        }
    }
}
```

### Info-Sheet Pattern

```swift
struct InfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let usageTips: [LocalizedStringKey]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Icon + Title
                    VStack(spacing: 12) {
                        Image(systemName: iconName)
                            .font(.system(size: 48))
                            .foregroundStyle(.blue)
                        Text(title)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)

                    // Description
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    // Usage Tips
                    if !usageTips.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("So funktioniert's:")
                                .font(.headline)

                            ForEach(usageTips.indices, id: \.self) { index in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "\(index + 1).circle.fill")
                                        .foregroundStyle(.blue)
                                    Text(usageTips[index])
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
```

---

## 2. Spezifische Implementierungen

### 2.1 Offen-Tab Info Button

**Platzierung:** Top-right in OffenView (Navigation Toolbar)

**Icon:** `hands.sparkles` (Meditation Symbol)

**Inhalt:**
- **Titel:** "Offene Meditation"
- **Beschreibung:** "Die offene Meditation bietet dir einen flexiblen Timer mit zwei Phasen: Meditation und Besinnung. Du bestimmst die Dauer und kannst dich voll auf deine Praxis konzentrieren."
- **Nutzungstipps:**
  1. "Wähle die Dauer für beide Phasen"
  2. "Phase 1: Meditation (mit Gong-Start)"
  3. "Phase 2: Besinnung/Reflexion (mit Gong-Übergang)"
  4. "Gong-Ende signalisiert das Sitzungsende"
  5. "Aktivität wird automatisch in Apple Health geloggt"

**Code-Location:** `Meditationstimer iOS/Tabs/OffenView.swift`

### 2.2 Frei-Tab Info Button

**Platzierung:** Top-right in WorkoutsView (Navigation Toolbar)

**Icon:** `figure.run` (Workout Symbol)

**Inhalt:**
- **Titel:** "Freies Workout"
- **Beschreibung:** "Das freie Workout ermöglicht dir eigene HIIT-Programme zu erstellen oder vordefinierte Programme zu nutzen. Mit Audio-Cues und Live Activity auf dem Lock Screen."
- **Nutzungstipps:**
  1. "Wähle ein vordefiniertes Programm oder erstelle eigenes"
  2. "Belastungsphasen werden mit Audio-Signalen begleitet"
  3. "Rest-Phasen zeigen dir die nächste Übung"
  4. "Live Activity auf Lock Screen und Dynamic Island"
  5. "Workout wird automatisch in Apple Health geloggt"

**Code-Location:** `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift`

### 2.3 NoAlc-Sheet Info Button

**Platzierung:** Top-right neben "NoAlc-Tagebuch" Header (im Compact Mode)

**Icon:** `drop.fill` (Alkohol-Tropfen Symbol)

**Inhalt:**
- **Titel:** "NoAlc-Tagebuch"
- **Beschreibung:** "Tracke deinen Alkoholkonsum und baue Streaks auf. Jeden Tag kannst du dein Trinkverhalten einstufen – von Steady bis Wild."
- **Nutzungstipps:**
  1. "👍 Steady: Kein Alkohol oder moderat"
  2. "🫠 Easy: Mehr als geplant, aber kontrolliert"
  3. "🥴 Wild: Deutlich über Plan oder unkontrolliert"
  4. "7 Steady-Tage = 1 Reward (kann Easy-Tag heilen)"
  5. "Aktivität wird in Apple Health geloggt"

**Code-Location:** `Meditationstimer iOS/NoAlcLogSheet.swift`

**Implementierung:**
```swift
// In NoAlcLogSheet.swift, compact mode header
HStack {
    Text("NoAlc-Tagebuch")
        .font(.title3)
        .fontWeight(.semibold)

    InfoButton {
        showInfo = true
    }
}
.sheet(isPresented: $showInfo) {
    InfoSheet(
        title: "NoAlc-Tagebuch",
        description: "noalc.info.description",
        usageTips: [
            "noalc.info.tip1",
            "noalc.info.tip2",
            "noalc.info.tip3",
            "noalc.info.tip4",
            "noalc.info.tip5"
        ]
    )
}
```

### 2.4 Settings Inline-Texte

**Design-Entscheidung:** Inline-Texte (`.font(.caption)` + `.foregroundStyle(.secondary)`) statt Info-Buttons

**Begründung:**
- Konsistent mit bestehendem Pattern in SettingsSheet.swift
- Settings-Bereiche brauchen nur 1-2 Sätze Erklärung
- Kein Overhead für Sheets/State-Management nötig

**Code-Location:** `Meditationstimer iOS/SettingsSheet.swift`

---

#### 2.4.1 Tägliche Ziele in Minuten

**Platzierung:** Section Header (Line 41)

**Bestehender Text:** Keiner

**Neuer Inline-Text:**
```swift
Section(header: Text("Tägliche Ziele in Minuten")) {
    Text("Setze deine täglichen Ziele für Meditation und Workouts. Der Fortschritt wird als teilgefüllte Kreise im Kalender angezeigt.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.bottom, 8)

    // ... existing pickers ...
}
```

**Erklärung:** Was sind tägliche Ziele und wo sieht man den Fortschritt?

---

#### 2.4.2 Hintergrundsounds

**Platzierung:** Section "Hintergrundsounds" (Line 74)

**Bestehender Text (Line 84):**
```swift
Text("Wähle einen Hintergrundsound und aktiviere ihn für Offen und/oder Atem.")
```

**Ergänzung:**
```swift
Section(header: Text("Hintergrundsounds")) {
    Picker("Ambient-Sound", selection: ambientSound) {
        // ... picker items ...
    }

    Text("Wähle einen Hintergrundsound (Regen, Feuer, etc.) und aktiviere ihn für Offen-Meditation und/oder Atem-Übungen. Der Sound läuft während der gesamten Session.")
        .font(.caption)
        .foregroundStyle(.secondary)

    Toggle("Für Offen (freie Meditation) aktivieren", isOn: $ambientSoundOffenEnabled)
        .disabled(ambientSound.wrappedValue == .none)

    Toggle("Für Atem (Atemübungen) aktivieren", isOn: $ambientSoundAtemEnabled)
        .disabled(ambientSound.wrappedValue == .none)

    // ... existing preview button ...
}
```

**Erklärung:** Wo wirken Hintergrundsounds (Offen + Atem)?

---

#### 2.4.3 Hintergrundsound Einstellungen

**Platzierung:** Section "Hintergrundsound Einstellungen" (Line 112)

**Bestehender Text (Line 118):**
```swift
Text("Stelle zuerst die Systemlautstärke mit dem Gong ein. Die Lautstärke des Hintergrundgeräuschs ist relativ zum Gong.")
```

**Beibehaltung:** Text ist bereits gut und selbsterklärend. Keine Änderung nötig.

---

#### 2.4.4 Atem-Sounds 🎵

**Platzierung:** Section Header (Line 134)

**Änderung 1:** Emoji entfernen
```swift
// VORHER:
Section(header: Text("Atem-Sounds 🎵")) {

// NACHHER:
Section(header: Text("Atem-Sounds")) {
```

**Bestehender Text (Line 145):**
```swift
Text(selectedAtemTheme.description)  // z.B. "Sanfte Glockentöne für Einatmen, Ausatmen, Halten"
```

**Ergänzung:**
```swift
Section(header: Text("Atem-Sounds")) {
    Picker("Sound-Theme", selection: $selectedAtemTheme) {
        // ... picker items ...
    }

    Text("Atem-Sounds begleiten deine Atemübungen mit Audio-Cues (Einatmen, Ausatmen, Halten). Wähle ein Theme, das zu deiner Praxis passt.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.bottom, 4)

    Text(selectedAtemTheme.description)
        .font(.caption)
        .foregroundStyle(.secondary)

    // ... existing test button ...
}
```

**Erklärung:** Worauf beziehen sich Atem-Sounds (Atemübungen, nicht Meditation)?

---

#### 2.4.5 Workout-Programme

**Platzierung:** Section "Workout-Programme" (Line 159)

**Bestehender Text (Line 163):**
```swift
Text("Verwendet die Systemsprache für Ansagen (Deutsch/Englisch).")
```

**Ergänzung:**
```swift
Section(header: Text("Workout-Programme")) {
    Toggle("Übungsnamen ansagen", isOn: $speakExerciseNames)

    Text("Aktiviere diese Option, um Übungsnamen vor jeder neuen Übung per Sprachausgabe anzusagen. Verwendet die Systemsprache (Deutsch/Englisch).")
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

**Erklärung:** Was passiert, wenn der Schalter aktiviert wird?

---

#### 2.4.6 Smart Reminders

**Platzierung:** Vor NavigationLink (Line 169)

**Bestehender Text:** Nur `.help()` tooltip (Line 171)

**Ergänzung:**
```swift
Section {
    Text("Intelligente Erinnerungen, die automatisch storniert werden, wenn du die Aktivität bereits durchgeführt hast. Nutzt HealthKit zur Aktivitätserkennung.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.bottom, 8)

    NavigationLink(destination: SmartRemindersView()) {
        Label("Smart Reminders", systemImage: "bell.badge")
    }

    NavigationLink(destination: SmartReminderDebugView()) {
        Label("Smart Reminder Debug", systemImage: "ant.circle")
    }
}
```

**Erklärung:** Was macht Smart Reminders besonders (automatische Stornierung)?

---

## 3. Kachel-Headers

### 3.1 "Offen" Tile → "Offene Meditation"

**Location:** `ContentView.swift` (falls dort Kacheln definiert sind) oder `OffenView.swift`

**Design:**
- **Text:** "Offene Meditation"
- **Font:** `.headline` oder `.title3`
- **Color:** `.secondary` (gleicher Grauton wie "Meditation" und "Besinnung" Labels)
- **Platzierung:** Oberhalb der Timer-Komponenten

**Layout-Anpassung:**
- Kachel/Tile leicht vergrößern (z.B. +20-30px height), um Platz für Header zu schaffen
- Header bekommt eigenen VStack mit spacing

**Code-Beispiel:**
```swift
VStack(spacing: 16) {
    // HEADER
    Text("Offene Meditation")
        .font(.title3)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)

    // Existing Timer UI
    // ...
}
.padding()
.background(.ultraThinMaterial)
.cornerRadius(20)
```

### 3.2 "Frei" Tile → "Freies Workout"

**Location:** `WorkoutProgramsView.swift` oder Tab-Container

**Design:**
- **Text:** "Freies Workout"
- **Font:** `.headline` oder `.title3`
- **Color:** `.secondary`
- **Platzierung:** Oberhalb der Workout-Programme

**Gleiche Layout-Anpassung wie Offen-Tile**

---

## 4. Internationalisierung (i18n)

### 4.1 Strategie

**SwiftUI LocalizedStringKey verwenden:**
```swift
// Statt:
Text("Offene Meditation")

// Verwenden:
Text("open_meditation.title")
// oder direkter SwiftUI-Ansatz:
Text("Offene Meditation")  // SwiftUI erkennt automatisch LocalizedStringKey
```

**String-Katalog erstellen:**
1. In Xcode: File → New → String Catalog
2. Name: `Localizable.xcstrings`
3. Location: Root des Projekts (neben Info.plist)

### 4.2 String-Katalog Struktur

**Localizable.xcstrings (JSON-Format):**
```json
{
  "sourceLanguage" : "de",
  "strings" : {
    "Offene Meditation" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Offene Meditation"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "needs_review",
            "value" : "Open Meditation"
          }
        }
      }
    },
    "Freies Workout" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Freies Workout"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "needs_review",
            "value" : "Free Workout"
          }
        }
      }
    }
  },
  "version" : "1.0"
}
```

### 4.3 Übersetzungsliste (Initial)

**Headers:**
- `"Offene Meditation"` → EN: `"Open Meditation"`
- `"Freies Workout"` → EN: `"Free Workout"`
- `"NoAlc-Tagebuch"` → EN: `"NoAlc Journal"`

**Info Sheet Titles:**
- `"Offene Meditation"` → EN: `"Open Meditation"`
- `"Freies Workout"` → EN: `"Free Workout"`
- `"NoAlc-Tagebuch"` → EN: `"NoAlc Journal"`

**Info Descriptions:**
- `"offen.info.description"` → DE: "Die offene Meditation bietet dir..."
  → EN: "Open meditation offers you a flexible timer..."
- `"frei.info.description"` → DE: "Das freie Workout ermöglicht dir..."
  → EN: "Free workout allows you to create..."
- `"noalc.info.description"` → DE: "Tracke deinen Alkoholkonsum..."
  → EN: "Track your alcohol consumption..."

**Info Tips:**
- `"offen.info.tip1"` → DE: "Wähle die Dauer für beide Phasen"
  → EN: "Choose duration for both phases"
- etc.

### 4.4 Implementierungs-Guidelines

**Regel 1: Alle sichtbaren Texte als LocalizedStringKey**
```swift
// ✅ CORRECT
Text("Offene Meditation")  // SwiftUI auto-converts to LocalizedStringKey

// ❌ WRONG
Text(String("Offene Meditation"))  // Expliziter String verhindert Lokalisierung
```

**Regel 2: String-Interpolation vorsichtig verwenden**
```swift
// ✅ CORRECT
Text("Streak: \(streakDays) Tage")  // Funktioniert, aber Translation muss gleiche Variablen-Position haben

// Better:
Text("streak.days", count: streakDays)  // Mit Plural-Rules
```

**Regel 3: Xcode String Extraction verwenden**
```bash
# Automatische Extraktion aller LocalizedStringKey in Code:
xcrun extractLocStrings -o Base.lproj *.swift
```

### 4.5 Spracherkennung

**Automatisch via System:**
```swift
// In App-Startup (no code needed, SwiftUI does automatically)
// User's device language setting determines which strings are shown

// Optional: Manual override for testing
// (NOT recommended for production)
// UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
```

---

## 5. Implementierungs-Phasen

### Phase 1: Info-Button Infrastruktur
**Aufwand:** ~1 Stunde
**Dateien:**
- Neue Datei: `Meditationstimer iOS/Components/InfoButton.swift`
- Neue Datei: `Meditationstimer iOS/Components/InfoSheet.swift`

**Schritte:**
1. InfoButton.swift erstellen (wiederverwendbare Komponente)
2. InfoSheet.swift erstellen (generisches Sheet mit title/description/tips)
3. Build testen

### Phase 2: Offen-Tab + Frei-Tab Info Buttons
**Aufwand:** ~1 Stunde
**Dateien:**
- `Meditationstimer iOS/Tabs/OffenView.swift`
- `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift`

**Schritte:**
1. OffenView: InfoButton in Toolbar hinzufügen
2. OffenView: @State showInfo + .sheet(isPresented:)
3. OffenView: InfoSheet mit Offen-Content
4. Gleiche Schritte für WorkoutProgramsView
5. Build + UI-Test

### Phase 3: NoAlc-Sheet Info Button
**Aufwand:** ~30 Min
**Dateien:**
- `Meditationstimer iOS/NoAlcLogSheet.swift`

**Schritte:**
1. Header von Text zu HStack ändern (Text + InfoButton)
2. @State showInfo hinzufügen
3. .sheet(isPresented:) mit NoAlc-InfoSheet
4. Build + UI-Test

### Phase 4: Kachel-Headers
**Aufwand:** ~1 Stunde
**Dateien:**
- `Meditationstimer iOS/ContentView.swift` (oder wo Kacheln definiert sind)
- Möglicherweise `OffenView.swift` und `WorkoutProgramsView.swift` direkt

**Schritte:**
1. Identifiziere wo "Offen" und "Frei" Kacheln gerendert werden
2. Füge Header-Text oberhalb hinzu
3. Passe Kachel-Height an (+20-30px)
4. Konsistente Styling (Font, Color, Spacing)
5. Build + UI-Test

### Phase 5: Internationalisierung (Optional - Vorbereitung)
**Aufwand:** ~1 Stunde
**Dateien:**
- Neue Datei: `Localizable.xcstrings` (Root-Level)
- Alle betroffenen SwiftUI Views

**Schritte:**
1. String Catalog in Xcode erstellen
2. Alle neuen Texte als LocalizedStringKey markieren (explizit oder implizit)
3. String Catalog mit deutschen Strings füllen
4. Englische Übersetzungen als "needs_review" hinzufügen (Platzhalter)
5. Build testen in DE und EN (Simulator Language Settings)

**WICHTIG:** Diese Phase kann später erfolgen, wenn Mehrsprachigkeit tatsächlich implementiert wird. Für jetzt: Code so schreiben, dass SwiftUI Text() automatisch LocalizedStringKey verwendet.

---

## 6. Testing-Checkliste

**Nach jeder Phase:**
- [ ] Build erfolgreich (⌘B)
- [ ] UI korrekt gerendert (⌘R)
- [ ] Info-Buttons tappable
- [ ] Sheets öffnen/schließen ohne Crashes
- [ ] Text nicht abgeschnitten
- [ ] Spacing/Padding korrekt
- [ ] Dark Mode funktioniert

**Phase 5 zusätzlich:**
- [ ] Simulator Language auf EN wechseln → Texte erscheinen auf Englisch
- [ ] Zurück auf DE → Texte wieder auf Deutsch
- [ ] String-Variablen (z.B. Streak-Count) korrekt interpoliert

---

## 7. Risiken & Offene Fragen

**Risiken:**
- **Kachel-Layout:** Wo genau sind "Offen" und "Frei" Kacheln definiert? (ContentView? Oder direkt in OffenView/WorkoutProgramsView?)
- **String Catalog Komplexität:** Plural-Rules für Deutsch vs. Englisch unterschiedlich
- **Sheet-Stapeln:** Wenn User Info-Sheet öffnet während andere Sheets aktiv sind → z-order issues?

**Offene Fragen:**
1. Soll der Info-Button IMMER sichtbar sein, oder nur bei bestimmten States?
2. Info-Sheet Medium oder Large Detent? (Empfehlung: Medium mit .large als Option)
3. Soll Info-Sheet-Content scrollbar sein? (Empfehlung: Ja, mit ScrollView)
4. Mehrsprachigkeit jetzt implementieren oder nur vorbereiten? (Empfehlung: Vorbereiten via LocalizedStringKey, aber noch keine EN-Strings schreiben)

---

## 8. Success Criteria

**Definition of Done:**
- [ ] 3 Info-Buttons implementiert (Offen, Frei, NoAlc)
- [ ] 3 Info-Sheets mit sinnvollem Content
- [ ] 2 Kachel-Headers hinzugefügt ("Offene Meditation", "Freies Workout")
- [ ] Build erfolgreich
- [ ] Alle Info-Sheets öffnen/schließen korrekt
- [ ] User-Testing: "Verstehe ich jetzt besser, was jeder Tab macht?"
- [ ] Code vorbereitet für Internationalisierung (LocalizedStringKey verwendet)
- [ ] (Optional) Localizable.xcstrings mit DE + Platzhalter-EN erstellt

---

## 9. Rollout-Plan

**Commit-Strategie:**
1. Commit nach Phase 1: "feat: Add InfoButton and InfoSheet components"
2. Commit nach Phase 2: "feat: Add info buttons to Offen and Frei tabs"
3. Commit nach Phase 3: "feat: Add info button to NoAlc sheet"
4. Commit nach Phase 4: "feat: Add headers to Offen and Frei tiles"
5. Commit nach Phase 5: "feat: Prepare i18n with Localizable.xcstrings"

**User-Testing:**
- Nach Phase 2+3: User testet Info-Buttons auf Device
- Nach Phase 4: User prüft Kachel-Headers (Größe, Spacing, Lesbarkeit)
- Nach Phase 5: User testet Sprach-Wechsel (DE ↔ EN)

---

**Für Implementation-Details siehe:**
- SwiftUI Localization: https://developer.apple.com/documentation/swiftui/localizedstringkey
- String Catalogs: https://developer.apple.com/documentation/xcode/localizing-your-app
