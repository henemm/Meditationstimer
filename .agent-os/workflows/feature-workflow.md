# Feature Workflow

## Overview

Features follow **TDD (Test-Driven Development)** with the Red-Green-Refactor cycle.

**PFLICHT:** Siehe `.agent-os/standards/testing/tdd-workflow.md`

**MANDATORY CHECKPOINTS:** Steps marked with ⛔ are BLOCKING.
You MUST complete them before proceeding. No exceptions.

```
┌────────────────────────────────────────────────────────────────┐
│                    TDD: RED-GREEN-REFACTOR                      │
│                                                                 │
│  ⛔ RED      →  ⛔ GREEN    →    REFACTOR   →  (repeat)        │
│  Test FAILS     Test PASSES     Code clean                      │
│  (Step 5)       (Step 8)        (optional)                      │
└────────────────────────────────────────────────────────────────┘
```

## Workflow Steps

### 1. Feature Request
- User describes what they want
- Understand the "why" (user value)
- Clarify category: Primary / Support / Passive

### 2. Check Existing Systems

**CRITICAL - Before designing:**
```bash
# Search for related systems
grep -r "Reminder" --include="*.swift"
grep -r "Notification" --include="*.swift"
```

Ask: "I see [existing system X], should I extend that or build new?"

### 3. Use Feature-Planner Agent
```
/feature [name]
```

The agent will:
- Understand requirements
- Check existing systems
- Create specification
- Add to roadmap

### 4. Define Acceptance Criteria

Write `openspec/changes/[feature-name]/tests.md`:
```markdown
# Acceptance Tests: [Feature Name]

## Unit Tests
- [ ] GIVEN... WHEN... THEN...

## XCUITests
- [ ] DE: [UI verification]
- [ ] EN: [UI verification]

## Manual Tests (Henning)
- [ ] [Real device tests]
```

### ⛔ 5. Write Tests FIRST - RED Phase (MANDATORY)

**TDD Schritt 1: Tests schreiben die FEHLSCHLAGEN**

1. **XCUITests schreiben** (für UI-Änderungen):
   ```swift
   // LeanHealthTimerUITests/FeatureNameTests.swift
   func testFeatureBehavior() throws {
       let app = XCUIApplication()
       app.launchArguments = ["-AppleLanguages", "(de)"]
       app.launch()

       // Test schreiben der FEHLSCHLAGEN wird
       XCTAssertTrue(app.staticTexts["Erwarteter Text"].exists)
   }
   ```

2. **Unit Tests schreiben** (für Logik):
   ```swift
   func testBusinessLogic() throws {
       // GIVEN / WHEN / THEN
   }
   ```

3. **Tests ausführen - MÜSSEN ROT sein:**
   ```bash
   xcodebuild test -project Meditationstimer.xcodeproj \
     -scheme "Lean Health Timer" \
     -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
     -only-testing:LeanHealthTimerUITests
   ```

**⛔ BLOCKER:** Test MUSS fehlschlagen! Wenn grün → Test ist wertlos!

### 6. Create OpenSpec Proposal

Create in `openspec/changes/[feature-name]/`:
- `proposal.md` - What and why
- `tasks.md` - Implementation checklist
- `specs/[domain]/spec.md` - Spec delta

### 7. Review & Approve

- Present spec to user
- Iterate until aligned
- Get explicit approval before coding

### 8. Implement - GREEN Phase

**TDD Schritt 2: Minimalen Code schreiben bis Tests GRÜN sind**

**Constraints:**
- Follow approved spec exactly
- Max 4-5 files per change
- Max +/-250 LoC
- Functions <= 50 LoC
- **NUR implementieren was Tests verlangen** - keine Extras!

### ⛔ 9. Run ALL Tests - GREEN Phase (MANDATORY)

**TDD Schritt 3: Tests MÜSSEN jetzt BESTEHEN**

```bash
# Unit Tests
xcodebuild test -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:LeanHealthTimerTests

# UI Tests (XCUITest)
xcodebuild test -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:LeanHealthTimerUITests
```

**⛔ BLOCKER:** Alle Tests MÜSSEN grün sein!

Wenn Tests fehlschlagen:
1. NICHT zu manuellen Tests übergehen
2. Code anpassen bis Tests grün
3. Keine "das teste ich später"-Ausreden

### 10. Refactor (Optional)

- Code aufräumen ohne Funktionsänderung
- Tests erneut ausführen → bleiben GRÜN
- Bei ROT → Änderungen rückgängig

### 11. Present to User for Manual Testing

**ONLY after ALL automated tests pass:**
- Present ONE test at a time
- Wait for user feedback
- Document results in ACTIVE-todos.md

### 12. Archive Change

```bash
openspec archive [feature-name]
```

This merges spec delta into source specs.

### 13. Update Documentation

- [ ] DOCS/ACTIVE-roadmap.md (update status)
- [ ] openspec/specs/ (auto-updated by archive)
- [ ] Remove openspec/changes/[feature-name]/ after merge

## TDD Checkpoint Summary

| Step | Phase | Checkpoint | Blocking? |
|------|-------|------------|-----------|
| 4 | - | Acceptance Criteria definiert | YES |
| 5 | RED | Tests geschrieben & fehlgeschlagen | ⛔ YES |
| 9 | GREEN | Alle Tests bestehen | ⛔ YES |
| 11 | - | User Manual Tests bestehen | ⛔ YES |

## Feature Categories

Design UI based on category:

| Category | UI Approach |
|----------|-------------|
| Primary | Prominent, explicit interaction |
| Support | Visible but secondary |
| Passive | Unterschwellig, notification-driven |

## Anti-Patterns

❌ **Test NACH Code** → Tests prüfen nur bestehenden Code
❌ **Grüne Tests ohne vorheriges Rot** → Test beweist nichts
❌ **Simulator-Screenshots statt XCUITest** → Keine automatische Verifikation
❌ **Tests überspringen** → Bugs bei User
❌ **No spec:** Starting to code without written spec
❌ **Duplicate system:** Building new when similar exists
❌ **Scope creep:** Adding unrequested functionality
