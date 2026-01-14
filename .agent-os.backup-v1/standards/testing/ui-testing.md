# UI Testing Standards

## Manual UI Test Protocol

Henning tests on real device (iPhone/Apple Watch). Follow these rules:

## Rules for Test Sessions

1. **Go through ALL pending tests** - Don't ask "want to test more?"
2. **ONE test at a time** - Don't present all tests at once
3. **Wait for result** - Only proceed after Henning's feedback
4. **Document immediately** - Record Pass/Fail in ACTIVE-todos.md
5. **STOP on failure** - Don't continue, analyze the bug first
6. **Complete the list** - Only end when ALL tests are done

## Test Workflow

```
1. Read ACTIVE-todos.md -> collect all "Test pending" items
2. Present first test -> wait for result -> document -> next test
3. Only when list empty: "All tests completed"
```

## Test Documentation Format

In ACTIVE-todos.md:
```markdown
### Bug #XX: [Description]
- **Status:** GEFIXT (Test ausstehend)
- **Getestet:** 2025-11-25 - PASS
```

## Test Both Languages

**CRITICAL:** Every UI change must be tested in:
- German (DE) - Primary language
- English (EN) - Secondary language

## What to Test

For each UI change, verify:
1. Visual appearance matches spec
2. Interaction works as expected
3. Edge cases handled gracefully
4. No regressions in related features
5. Both portrait and landscape (if applicable)

## Preparing Test Instructions

When creating test instructions for Henning:
1. **Clear steps** - Exact sequence of actions
2. **Expected result** - What should happen
3. **Potential side effects** - Where to check for regressions
4. **Edge cases** - What unusual scenarios to try

## Example Test Instruction

```markdown
## Test: Workout REST Phase Pause Display

**Steps:**
1. Start any workout program
2. Wait for REST phase to begin
3. Tap pause button
4. Observe display

**Expected:**
- Shows "Als naechstes" (small font)
- Shows next exercise name (large font)
- NO current exercise shown (redundant)

**Edge Cases:**
- Try pausing at very start of REST
- Try pausing near end of REST

**Both Languages:** Test with DE and EN settings
```
