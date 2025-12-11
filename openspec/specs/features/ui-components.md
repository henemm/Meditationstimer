# UI Components

## Overview

Reusable UI components used across the app including InfoButton/InfoSheet pattern, CountdownOverlay, CircularRing progress visualization, and GlassCard styling.

## Requirements

### Requirement: InfoButton Component
The system SHALL provide a reusable info button for contextual help.

#### Scenario: InfoButton Appearance
- GIVEN InfoButton is placed in view
- WHEN rendering
- THEN small info icon displays (ⓘ or info.circle)
- AND button is tappable
- AND size is appropriate for context

#### Scenario: InfoButton Tap Action
- GIVEN InfoButton is visible
- WHEN user taps button
- THEN provided action closure executes
- AND typically triggers InfoSheet presentation

#### Scenario: InfoButton Styling
- GIVEN InfoButton renders
- WHEN displaying
- THEN uses secondary foreground color
- AND has appropriate hit area for touch

### Requirement: InfoSheet Component
The system SHALL provide a reusable info sheet for explanations.

#### Scenario: InfoSheet Structure
- GIVEN InfoSheet is presented
- WHEN rendering
- THEN title displays at top
- AND description text follows
- AND usage tips list displays (if provided)

#### Scenario: InfoSheet Content
- GIVEN InfoSheet receives parameters
- WHEN initializing
- THEN title: String is required
- AND description: String is required
- AND usageTips: [String] is optional

#### Scenario: InfoSheet Styling
- GIVEN InfoSheet renders
- WHEN displaying
- THEN minimal whitespace (8pt top padding)
- AND no decorative icons (information, not decoration)
- AND close button in toolbar (xmark.circle.fill)
- AND consistent .font(.caption) for secondary text

#### Scenario: InfoSheet Dismissal
- GIVEN InfoSheet is presented
- WHEN user taps close button or swipes down
- THEN sheet dismisses
- AND returns to previous view

### Requirement: CountdownOverlay Component
The system SHALL provide a pre-session countdown overlay.

#### Scenario: Countdown Display
- GIVEN countdown is triggered before session
- WHEN CountdownOverlayView renders
- THEN large countdown number displays (3, 2, 1)
- AND progress ring shows remaining time
- AND semi-transparent background covers screen

#### Scenario: Countdown Configuration
- GIVEN CountdownOverlay is initialized
- WHEN setting parameters
- THEN totalSeconds configures duration
- AND onComplete callback fires when countdown ends
- AND onCancel callback fires if user cancels

#### Scenario: Countdown Animation
- GIVEN countdown is running
- WHEN second changes
- THEN number updates with animation
- AND progress ring animates smoothly
- AND provides visual preparation for session

#### Scenario: Countdown Cancellation
- GIVEN countdown is active
- WHEN user taps cancel
- THEN countdown stops immediately
- AND onCancel callback executes
- AND overlay dismisses

### Requirement: CircularRing Component
The system SHALL provide a circular progress ring visualization.

#### Scenario: Ring Progress Display
- GIVEN CircularRing receives progress value
- WHEN rendering
- THEN ring fills proportionally (0.0 to 1.0)
- AND fill direction is clockwise from top
- AND unfilled portion shows track color

#### Scenario: Ring Customization
- GIVEN CircularRing is initialized
- WHEN setting parameters
- THEN progress: Double (0.0-1.0)
- AND lineWidth: CGFloat
- AND color or gradient can be specified

#### Scenario: Ring Animation
- GIVEN progress value changes
- WHEN update occurs
- THEN ring animates smoothly to new value
- AND uses spring animation for natural feel

#### Scenario: Dual Ring Support
- GIVEN view needs multiple progress indicators
- WHEN using CircularRing
- THEN multiple rings can be layered concentrically
- AND different sizes create nested appearance

### Requirement: GlassCard Component
The system SHALL provide a glassmorphism card container.

#### Scenario: Glass Card Appearance
- GIVEN GlassCard wraps content
- WHEN rendering
- THEN ultraThinMaterial background applies
- AND rounded corners create card shape
- AND subtle shadow provides depth

#### Scenario: Glass Card Styling
- GIVEN GlassCard renders
- WHEN displaying
- THEN uses iOS 18+ "Liquid Glass" design language
- AND provides depth through blur effect
- AND content is readable over blurred background

### Requirement: InfoButton + InfoSheet Pattern
The system SHALL establish pattern for contextual help.

#### Scenario: Pattern Usage
- GIVEN feature needs explanation
- WHEN implementing help
- THEN InfoButton placed next to feature title
- AND @State var showInfo controls sheet
- AND InfoSheet configured with relevant content

#### Scenario: Pattern Example
- GIVEN tab has feature requiring explanation
- WHEN implementing
- THEN structure follows:
  ```swift
  HStack {
    Text("Feature Title")
    InfoButton { showInfo = true }
  }
  .sheet(isPresented: $showInfo) {
    InfoSheet(title:, description:, usageTips:)
  }
  ```

#### Scenario: Modal Context Awareness
- GIVEN view is already modal (Settings, Sheet)
- WHEN considering help UI
- THEN use inline explanatory text instead
- AND avoid nested modals (poor UX)
- AND .font(.caption) + .foregroundStyle(.secondary) for styling

### Requirement: Tab Content Placement
The system SHALL place info buttons appropriately.

#### Scenario: Info in Tab Content
- GIVEN tab has feature-specific help
- WHEN placing InfoButton
- THEN place in tab content (next to title)
- AND NOT in toolbar (toolbar = global navigation)

#### Scenario: Toolbar Reserved for Global
- GIVEN toolbar is being designed
- WHEN deciding contents
- THEN toolbar contains: Settings button, Calendar navigation
- AND tab-specific info belongs in tab content

### Requirement: Localization Support
The system SHALL support localization in UI components.

#### Scenario: InfoSheet Localization
- GIVEN InfoSheet content
- WHEN creating strings
- THEN use NSLocalizedString or LocalizedStringKey
- AND provide DE (primary) and EN (secondary) translations

## Technical Notes

- **InfoButton:** Simple button with info.circle SF Symbol
- **InfoSheet:** SwiftUI sheet with toolbar close button
- **CountdownOverlay:** ZStack overlay with Timer for countdown
- **CircularRing:** SwiftUI Shape with trim(from:to:) for progress
- **GlassCard:** ViewModifier with .ultraThinMaterial background
- **Design Language:** iOS 18+ "Liquid Glass" with glassmorphism

Reference Standards:
- `.agent-os/standards/swiftui/localization.md`
