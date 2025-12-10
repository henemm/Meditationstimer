# Breathing Exercises (Atem-Tab)

## Overview

Guided breathing exercises with customizable patterns, ambient sounds, and visual guidance.

## Requirements

### Requirement: Breathing Patterns
The system SHALL support multiple breathing patterns.

#### Scenario: Pattern Selection
- WHEN user selects breathing pattern
- THEN inhale/exhale/hold durations are configured
- AND visualization adjusts to pattern

#### Scenario: Available Patterns
| Pattern | Inhale | Hold | Exhale | Hold |
|---------|--------|------|--------|------|
| 4-7-8 | 4s | 7s | 8s | - |
| Box | 4s | 4s | 4s | 4s |
| Relaxing | 4s | - | 6s | - |

### Requirement: Visual Guidance
The system SHALL provide visual breathing guidance.

#### Scenario: Animation
- WHEN breathing phase changes
- THEN visual element animates (expand/contract)
- AND phase label updates (Einatmen/Halten/Ausatmen)

### Requirement: Audio Guidance
The system SHALL provide audio cues.

#### Scenario: Voice Cues
- WHEN inhale phase begins
- THEN "Einatmen" audio plays
- WHEN exhale phase begins
- THEN "Ausatmen" audio plays
- WHEN hold phase begins
- THEN "Halten" audio plays

### Requirement: Ambient Sounds
The system SHALL support ambient background sounds.

#### Scenario: Sound Selection
- WHEN user selects ambient sound
- THEN background audio plays during session
- AND volume is adjustable

### Requirement: Session Configuration
The system SHALL allow session customization.

#### Scenario: Repetition Selection
- WHEN user sets repetitions
- THEN breathing cycles repeat that many times
- AND progress indicator shows current/total

### Requirement: Audio Completion
The system SHALL properly sequence audio cleanup.

#### Scenario: End Gong Not Cut Off
- WHEN session ends
- THEN end gong plays completely
- AND ambient sound stops AFTER gong finishes
- AND uses AVAudioPlayerDelegate completion callback

## Technical Notes

- Completion handler pattern for audio sequencing
- DispatchWorkItem for delayed cleanup with cancellation
- Extra 0.5s safety buffer after gong completion
