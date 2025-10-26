# Meditationstimer Documentation

Detailed technical documentation for developers working on Meditationstimer.

---

## Quick Links

- **[Main Project Guide](../CLAUDE.md)** – Start here for overview and quick reference
- **[Global Collaboration Rules](~/.claude/CLAUDE.md)** – Workflow and development standards

---

## Documentation Files

### 📐 [architecture.md](architecture.md)
Complete architecture overview, design principles, and project structure.

**Topics:**
- System architecture diagram
- Key design principles
- Architectural decisions & rationale
- Complete project structure
- Files by responsibility

### 🧩 [components.md](components.md)
Detailed reference for all major components and services.

**Topics:**
- TwoPhaseTimerEngine (timer state machine)
- HealthKitManager (health data integration)
- LiveActivityController (Dynamic Island)
- StreakManager (streak calculation)
- GongPlayer (audio playback)
- Platform-specific components (iOS/watchOS)

### 🔄 [workflows.md](workflows.md)
State management patterns and data flow documentation.

**Topics:**
- Timer session flow (Offen tab)
- Watch app flow
- Data persistence patterns
- Multi-target code sharing
- Data synchronization strategy

### 🧪 [testing-guide.md](testing-guide.md)
Comprehensive testing and debugging guide.

**Topics:**
- Test suite overview (58+ tests)
- Setting up test target in Xcode
- Running tests (Xcode + command line)
- Writing new tests
- Debug logging
- Common testing scenarios

### 🛠️ [development-guide.md](development-guide.md)
Common development tasks and code recipes.

**Topics:**
- Adding new meditation timers
- Adding audio cues
- Accessing HealthKit data
- Updating Live Activities
- Detecting ownership conflicts
- Build & release commands
- Code snippets

### 🔊 [audio-system.md](audio-system.md)
Complete audio system documentation.

**Topics:**
- iOS audio system (GongPlayer + BackgroundAudioKeeper)
- Workouts audio (SoundPlayer + speech synthesis)
- watchOS haptic feedback
- Audio file guidelines
- Troubleshooting
- Advanced patterns

### 📱 [platform-notes.md](platform-notes.md)
Platform-specific requirements and differences.

**Topics:**
- iOS platform (16.1+)
- watchOS platform (9.0+)
- Widget Extension
- Cross-platform shared code
- Platform capabilities (Info.plist)
- Testing notes per platform

---

## How to Use This Documentation

### For New Developers

1. Read **[CLAUDE.md](../CLAUDE.md)** for project overview
2. Read **[architecture.md](architecture.md)** to understand system design
3. Read **[components.md](components.md)** for component deep-dive
4. Refer to **[development-guide.md](development-guide.md)** for common tasks

### For Specific Tasks

- **Adding features:** See [development-guide.md](development-guide.md)
- **Fixing bugs:** See [testing-guide.md](testing-guide.md) and [workflows.md](workflows.md)
- **Audio work:** See [audio-system.md](audio-system.md)
- **Platform issues:** See [platform-notes.md](platform-notes.md)

### For Architecture Changes

- Update **[architecture.md](architecture.md)** with design decisions
- Update **[components.md](components.md)** if components change
- Update **[CLAUDE.md](../CLAUDE.md)** if key patterns change

---

## Documentation Maintenance

**When to Update:**

- **New features:** Document in relevant file + update main CLAUDE.md
- **Architecture changes:** Update architecture.md + main CLAUDE.md
- **New components:** Add to components.md
- **Bug fixes:** Update testing-guide.md if test coverage added
- **Platform changes:** Update platform-notes.md

**Keep it DRY:**

- Main CLAUDE.md = high-level overview + quick reference
- DOCS/ = detailed deep-dives
- Avoid duplicating content across files

---

## Version History

- **Initial split:** 2025-10-26 – Separated from monolithic CLAUDE.md
- Global rules moved to `~/.claude/CLAUDE.md`
- Project overview streamlined in `CLAUDE.md` (300 lines)
- Detailed docs in `/DOCS/` (~400 lines each)

---

**For global collaboration rules, see `~/.claude/CLAUDE.md`**
