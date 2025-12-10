# Meditationstimer - Project Context

## Overview

Meditationstimer is a meditation and wellness app built with SwiftUI for iOS 18.5+ and watchOS 9.0+.

## Tech Stack

| Component | Technology |
|-----------|------------|
| Language | Swift 6.2 |
| Framework | SwiftUI |
| IDE | Xcode 26 |
| Min iOS | 18.5 |
| Min watchOS | 9.0 |

## Integrations

- **HealthKit** - Activity tracking, mindfulness logging
- **ActivityKit** - Live Activities, Dynamic Island
- **AVFoundation** - Audio playback (gongs, ambient sounds)
- **WatchConnectivity** - Watch/iPhone sync

## Architecture

Multi-target, horizontally-layered:
- **iOS App** - Main meditation/workout UI
- **watchOS App** - Companion with heart rate
- **Widget Extension** - Live Activities

Shared services in `/Services/`:
- TwoPhaseTimerEngine
- HealthKitManager
- StreakManager
- GongPlayer

## Conventions

### Coding Standards

Reference `.agent-os/standards/` for:
- **Analysis-First Principle** (global/analysis-first.md)
- **Scoping Limits** (global/scoping-limits.md) - Max 4-5 files, +/-250 LoC
- **SwiftUI Patterns** (swiftui/lifecycle-patterns.md)
- **HealthKit Dates** (healthkit/date-semantics.md)

### Commit Format

Conventional Commits:
- `feat:` - New features
- `fix:` - Bug fixes
- `refactor:` - Code restructuring
- `test:` - Test changes
- `docs:` - Documentation
- `chore:` - Maintenance

### Localization

- **Primary:** German (DE)
- **Secondary:** English (EN)
- All user-visible strings must be localized

## Feature Categories

| Category | Description | UI Approach |
|----------|-------------|-------------|
| Primary | Meditation, Breathing, Workouts | Prominent, explicit |
| Support | Streaks, Calendar, Stats | Visible but secondary |
| Passive | Smart Notifications | Unterschwellig, notification-driven |

## OpenSpec Workflow

1. **Create Proposal:** `openspec/changes/[name]/proposal.md`
2. **Define Tasks:** `openspec/changes/[name]/tasks.md`
3. **Spec Delta:** `openspec/changes/[name]/specs/[domain]/spec.md`
4. **Review & Iterate** with user
5. **Implement** based on approved spec
6. **Archive:** `openspec archive [name]`
