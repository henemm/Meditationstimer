# Lokalisierungs-Workflow für Meditationstimer

**Erstellt:** 23. November 2025
**Ziel:** Konsistente DE↔EN Lokalisierung mit dem localizer Agent

---

## Schritt-für-Schritt Prozess

### 0. ⚠️ KRITISCH: ALLE Feature-Dateien finden

**BEVOR du irgendetwas lokalisierst, MUSS dieser Schritt erfolgen!**

```bash
# ALLE Dateien zum Feature finden
grep -ri "featurename" --include="*.swift" -l

# Beispiel für "Countdown":
grep -ri "countdown" --include="*.swift" -l
```

**Warum kritisch?**
- Ein Feature besteht oft aus MEHREREN Dateien (Settings + View + Model)
- Nur die offensichtliche Datei zu lokalisieren reicht NICHT
- Countdown-Fehler vom 23.11.2025: Settings lokalisiert, OverlayView vergessen!

**Typische Feature-Struktur:**
| Komponente | Beispiel-Datei | Enthält Strings? |
|------------|----------------|------------------|
| Settings | SettingsSheet.swift | ✓ Labels, Descriptions |
| View/UI | CountdownOverlayView.swift | ✓ Status-Texte, Buttons |
| Model | Timer.swift | Evtl. State-Namen |
| Tab-Integration | OffenView.swift | Evtl. Hinweise |

### 1. Scope definieren
- Was soll lokalisiert werden? (UI-Texte, Übungsnamen, Beschreibungen)
- **Welche Dateien sind betroffen? (aus Schritt 0!)**
- Wie viele Strings ungefähr?

### 2. Localizer Agent starten
```
Task mit subagent_type: "localizer"

Prompt-Template:
"Lokalisiere [BEREICH] für [FEATURE/BUG].
1. Lies [DATEI] und finde alle zu lokalisierenden Strings
2. Erstelle eine vollständige DE→EN Übersetzungstabelle
3. Erstelle das JSON-Format für Localizable.xcstrings
4. Liste alle Code-Änderungen auf (NSLocalizedString, LocalizedStringKey)"
```

### 3. Agent-Ergebnis verifizieren
Der Agent kann Strings übersehen! Immer mit grep/code prüfen:

```bash
# Alle hardcoded Strings in einer Datei finden
grep -n 'Text("[^"]*")' DateiName.swift

# Alle name:-Werte extrahieren
grep -o 'name: "[^"]*"' DateiName.swift | sort | uniq

# NSLocalizedString-Verwendung prüfen
grep -c "NSLocalizedString" DateiName.swift
```

### 4. Übersetzungsdatei erstellen
Immer eine Dokumentation anlegen unter `DOCS/translations-[feature].md`:

```markdown
# [Feature] Lokalisierung

| Deutsch | English |
|---------|---------|
| Text 1 | Translation 1 |
| Text 2 | Translation 2 |
```

### 5. Localizable.xcstrings aktualisieren
Per Python-Script (für viele Einträge):

```python
import json

with open('Localizable.xcstrings', 'r') as f:
    data = json.load(f)

# Neue Einträge hinzufügen
translations = {
    "Deutsch": "English",
    # ...
}

for de, en in translations.items():
    if de not in data['strings']:
        data['strings'][de] = {
            "localizations": {
                "de": {"stringUnit": {"state": "translated", "value": de}},
                "en": {"stringUnit": {"state": "translated", "value": en}}
            }
        }

with open('Localizable.xcstrings', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
```

### 6. Code anpassen

**Für UI-Texte (SwiftUI):**
```swift
// Vorher (nicht lokalisiert):
Text(variable)

// Nachher (lokalisiert):
Text(LocalizedStringKey(variable))
```

**Für Business-Logic Strings:**
```swift
// Vorher:
let text = "Deutscher Text"

// Nachher:
let text = NSLocalizedString("key", value: "Deutscher Text", comment: "Context")
```

### 7. Build & Test
```bash
# Build prüfen
xcodebuild -scheme "Lean Health Timer" build

# EN-Version testen
# Scheme "Lean Health Timer (EN)" auswählen
```

---

## Checkliste für Lokalisierung

- [ ] Localizer Agent gestartet
- [ ] Agent-Ergebnis mit grep verifiziert
- [ ] Übersetzungsdatei in DOCS/ erstellt
- [ ] Localizable.xcstrings aktualisiert
- [ ] Code angepasst (LocalizedStringKey / NSLocalizedString)
- [ ] Build erfolgreich
- [ ] EN-Version im Simulator getestet
- [ ] ACTIVE-todos.md aktualisiert

---

## Häufige Fallstricke

### 1. Text(stringVariable) wird NICHT lokalisiert
```swift
// FALSCH - wird nicht lokalisiert:
Text(phase.name)

// RICHTIG - wird lokalisiert:
Text(LocalizedStringKey(phase.name))
```

### 2. String-Interpolation bricht Lokalisierung
```swift
// FALSCH:
Text("Übung \(number) von \(total)")

// RICHTIG:
Text(String(format: NSLocalizedString("Exercise %d of %d", comment: ""), number, total))
```

### 3. Localizer Agent findet nicht alles
- Immer mit grep verifizieren
- Dynamisch generierte Strings können übersehen werden
- Strings in anderen Dateien (z.B. Models) prüfen

### 4. ⚠️ Feature hat MEHRERE Dateien (Countdown-Fehler 23.11.2025)
```
❌ FALSCH: Nur SettingsSheet.swift lokalisiert
✅ RICHTIG: ALLE Dateien zum Feature finden (grep -ri "countdown")
           → SettingsSheet.swift (Settings)
           → CountdownOverlayView.swift (UI) ← wurde vergessen!
```
**Regel:** IMMER Schritt 0 (Feature-Dateien finden) ausführen!

---

## Bestehende Lokalisierungen

| Feature | Datei | Status |
|---------|-------|--------|
| Übungsnamen | translations-exercise-names.md | ✅ 46 Einträge |
| Übungstexte (effect/instructions) | ExerciseDatabase.swift | ✅ 86 Keys |
| UI-Texte | diverse | ✅ >300 Keys |

---

## Siehe auch
- `DOCS/translations-exercise-names.md` - Übungsnamen DE→EN
- `DOCS/feature-exercise-localization.md` - Bug 19 Spec
- `.claude/agents/localizer.md` - Agent-Definition
