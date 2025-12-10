# AI Agent Instructions

This project uses **Agent OS** for standards and **OpenSpec** for spec-driven development.

## Quick Start

| Task | Command | Agent |
|------|---------|-------|
| Fix a bug | `/bug [description]` | bug-investigator |
| Plan feature | `/feature [name]` | feature-planner |
| Run tests | `/test` | test-runner |
| Add localization | `/localize` | localizer |
| UI test checklist | `/ui-test` | ui-test-guide |

## Standards

All coding standards are in `.agent-os/standards/`:

| Category | Standards |
|----------|-----------|
| `global/` | analysis-first, scoping-limits, documentation-rules |
| `swiftui/` | lifecycle-patterns, localization, state-management |
| `healthkit/` | date-semantics, data-consistency |
| `audio/` | completion-handlers |
| `testing/` | unit-tests, ui-testing |

**Read relevant standards before making changes!**

## OpenSpec Workflow

### Creating a New Feature

1. **Create proposal:**
   ```
   mkdir -p openspec/changes/[feature-name]
   ```

2. **Add files:**
   - `proposal.md` - What and why
   - `tasks.md` - Implementation checklist
   - `specs/[domain]/spec.md` - Spec delta

3. **Review with user** until aligned

4. **Implement** based on approved spec

5. **Archive:**
   ```bash
   openspec archive [feature-name]
   ```

### Spec Format

```markdown
## Requirements

### Requirement: [Name]
The system SHALL [behavior].

#### Scenario: [Name]
- GIVEN [context]
- WHEN [action]
- THEN [outcome]
```

## Bug Fix Workflow

1. Use `/bug [description]` or bug-investigator agent
2. Follow Analysis-First principle
3. Find root cause with CERTAINTY
4. Document in DOCS/ACTIVE-todos.md
5. Implement fix (max 4-5 files, +/-250 LoC)
6. Run tests: 66 must pass
7. Say "Fix implementiert, bitte auf Device testen"

**NEVER say "fixed" or "complete" - only USER can verify!**

## Key Rules

### From Analysis-First Standard

- Trace COMPLETE data flow, not fragments
- Identify root cause with CERTAINTY before fixing
- No trial-and-error
- Spec-First: Never implement without specification

### From Documentation Rules

- Never use checkmarks without user verification
- Check for existing systems before building new
- Update DOCS/ACTIVE-todos.md immediately after work

### From Scoping Limits

- Max 4-5 files per change
- Max +/-250 lines of code
- Functions <= 50 lines
- No side effects outside ticket

## Feature Categories

Design UI based on category:

| Category | UI Approach |
|----------|-------------|
| Primary (Meditation, Workouts) | Prominent, explicit |
| Support (Streaks, Calendar) | Visible but secondary |
| Passive (Notifications) | Unterschwellig |

**Ask which category before designing!**

## Localization

- Primary: German (DE)
- Secondary: English (EN)
- File: `Localizable.xcstrings`
- Always test both languages

## Testing

- 66 Unit Tests must pass before commit
- UI tests: one at a time, wait for feedback
- Document results in ACTIVE-todos.md

## Project Structure

```
.agent-os/
├── standards/     # Coding standards
├── agents/        # Specialized agents
└── workflows/     # Bug fix, feature, release

openspec/
├── project.md     # Project context
├── specs/         # Feature specifications
├── changes/       # Active proposals
└── archive/       # Completed changes

DOCS/
├── ACTIVE-todos.md    # Current bugs/tasks
├── ACTIVE-roadmap.md  # Planned features
└── bug-index.md       # Bug patterns
```

## Reference Files

- `CLAUDE.md` - Project guide
- `~/.claude/CLAUDE.md` - Global rules
- `.agent-os/standards/*` - All standards
- `openspec/specs/*` - Feature specifications
