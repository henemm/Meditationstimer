# Feature Workflow

## Overview

Features follow Spec-First development integrated with OpenSpec.

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

### 4. Create OpenSpec Proposal

```bash
# In openspec/changes/
mkdir -p openspec/changes/[feature-name]
```

Create:
- `proposal.md` - What and why
- `tasks.md` - Implementation checklist
- `specs/[domain]/spec.md` - Spec delta

### 5. Review & Approve

- Present spec to user
- Iterate until aligned
- Get explicit approval before coding

### 6. Implement

**Constraints:**
- Follow approved spec exactly
- Max 4-5 files per change
- Max +/-250 LoC
- Functions <= 50 LoC

### 7. Test

```bash
xcodebuild test -project Meditationstimer.xcodeproj \
  -scheme "MeditationstimerTests" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### 8. Archive Change

```bash
openspec archive [feature-name]
```

This merges spec delta into source specs.

### 9. Update Documentation

- [ ] DOCS/ACTIVE-roadmap.md (update status)
- [ ] openspec/specs/ (auto-updated by archive)
- [ ] Test instructions for Henning

## Feature Categories

Design UI based on category:

| Category | UI Approach |
|----------|-------------|
| Primary | Prominent, explicit interaction |
| Support | Visible but secondary |
| Passive | Unterschwellig, notification-driven |

## Anti-Patterns

- **No spec:** Starting to code without written spec
- **Duplicate system:** Building new when similar exists
- **Wrong category:** Prominent UI for passive feature
- **Scope creep:** Adding unrequested functionality
- **Green checkmarks:** Claiming "complete" without user verification
