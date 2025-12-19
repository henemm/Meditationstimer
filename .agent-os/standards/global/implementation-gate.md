# Implementation Gate - MANDATORY Pre-Implementation Checklist

## KRITISCH: Diese Checkliste MUSS vor JEDER Implementierung durchlaufen werden!

**Dieses Gate ist BLOCKIEREND. Keine Ausnahmen. Keine Abkürzungen.**

---

## Wann gilt dieses Gate?

| Situation | Gate erforderlich? |
|-----------|-------------------|
| Feature-Implementierung | **JA - IMMER** |
| Bug-Fix (mehr als 1 Zeile) | **JA** |
| Refactoring | **JA** |
| Triviale Typos (1 Zeile) | Nein |
| Dokumentations-Änderungen | Nein |

---

## PRE-IMPLEMENTATION GATE CHECKLIST

### Phase 1: BEFORE Writing Any Code

```
[ ] 1. ANALYSE abgeschlossen
    - Root Cause identifiziert (bei Bugs)
    - Requirements verstanden (bei Features)
    - Betroffene Dateien bekannt

[ ] 2. TESTS DEFINIERT
    - Unit Tests: GIVEN/WHEN/THEN formuliert
    - XCUITests: Automatisierte UI-Tests geplant (PFLICHT!)
    - ⚠️ Manuelle Checklisten sind KEIN Ersatz für XCUITests!

[ ] 3. BESTEHENDE TESTS AUSGEFÜHRT
    - xcodebuild test ausgeführt
    - Alle 66+ Tests GRÜN
    - Baseline dokumentiert: "Tests vor Änderung: X/Y bestanden"

[ ] 4. NEUE TESTS GESCHRIEBEN (TDD RED Phase)
    - Unit Tests existieren und SCHLAGEN FEHL (LeanHealthTimerTests/)
    - XCUITests existieren für neue UI (LeanHealthTimerUITests/)
    - Tests prüfen die gewünschte Funktionalität
    - ⚠️ KEINE manuellen Checklisten statt echtem Code!
```

### Phase 2: AFTER Writing Code

```
[ ] 5. ALLE TESTS AUSGEFÜHRT (TDD GREEN Phase)
    - xcodebuild test ausgeführt
    - ALLE Tests GRÜN (neue + bestehende)
    - Keine Regressionen

[ ] 6. BUILD ERFOLGREICH
    - xcodebuild build ohne Errors
    - Keine Warnings in geänderten Dateien

[ ] 7. XCUITests GESCHRIEBEN UND GRÜN
    - Automatisierte Tests in LeanHealthTimerUITests/
    - Tests laufen im Simulator durch
    - xcodebuild test -only-testing:LeanHealthTimerUITests GRÜN
```

---

## ENFORCEMENT: Wie Claude dieses Gate einhalten MUSS

### Bei jedem Feature/Bug-Fix:

1. **STOPP** bevor du Code schreibst
2. **PRÜFE** diese Checkliste
3. **FÜHRE** bestehende Tests aus
4. **SCHREIBE** neue Tests (wenn nötig)
5. **ERST DANN** implementiere

### Verpflichtende Ausgabe vor Implementierung:

```markdown
## Pre-Implementation Gate Check ✓

| Check | Status |
|-------|--------|
| Analyse abgeschlossen | ✅ |
| Tests definiert | ✅ |
| Bestehende Tests grün | ✅ (66/66) |
| Neue Tests geschrieben | ✅ / ⏭️ (nicht nötig) |

**Gate PASSED - Implementierung kann beginnen**
```

### Bei Verletzung:

Wenn Claude Code schreibt OHNE dieses Gate zu durchlaufen:
- Henning MUSS intervenieren
- Implementierung wird gestoppt
- Gate wird nachgeholt

---

## Ausnahmen

**KEINE.** Auch nicht bei:
- "Ist nur eine kleine Änderung"
- "Das ist offensichtlich"
- "Tests sind overkill für das"
- "Ich mache das nachher"

---

## Lessons Learned

**2025-12-19: Phase 2.4-2.6 Tracker UI**
- Claude hat TrackerTab UI implementiert mit:
  - Unit Tests ✅
  - Build erfolgreich ✅
  - **ABER: Manuelle Checklisten statt XCUITests** ❌
- **Problem:** "UI-Test-Anweisungen" wurde als manuelle Markdown-Tabellen interpretiert
- **Folge:** Gate-Standard verschärft - XCUITests sind PFLICHT, keine manuellen Checklisten!

**2025-12-15: Phase 1.1 Tab Navigation**
- Claude hat TabView umgebaut ohne:
  - Bestehende Tests auszuführen
  - Neue Tests zu schreiben
  - UI-Test-Anweisungen vor Implementierung zu erstellen
- **Folge:** Gate-Standard eingeführt
