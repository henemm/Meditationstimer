---
entity_id: FEAT-38
type: feature
created: 2026-01-19
status: draft
workflow: feat-38-inline-level-buttons
---

# FEAT-38: Inline Quick-Log Buttons für Level-Tracker

- [ ] Approved for implementation

## Purpose

Alle level-basierten Tracker (NoAlc, Mood, Energy, etc.) sollen dieselben inline Quick-Log Buttons haben wie die hardcoded noAlcCard. Ein Tap = geloggt.

## Problem

| Tracker | Aktuelle UI | Taps zum Loggen |
|---------|-------------|-----------------|
| NoAlc (original) | 💧 ✨ 💥 inline | **1 Tap** |
| NoAlc (neu via Preset) | "Log" Button | **2 Taps** (Button → Sheet → Level) |
| Mood | "Log" Button | **2 Taps** |

**User-Erwartung:** Konsistente UI - immer 1 Tap.

## Scope

- **Files:** 1 (TrackerRow.swift)
- **Estimated:** +35/-20 LoC
- **Risk:** LOW

## Implementation Details

### 1. State für visuelles Feedback

```swift
// TrackerRow.swift
@State private var loggedLevel: TrackerLevel? = nil
```

### 2. Neue View: inlineLevelButtons

Ersetzt `levelQuickLogButton` (Zeile 209-221):

```swift
@ViewBuilder
private var levelQuickLogButtons: some View {
    HStack(spacing: 6) {
        ForEach(trackerLevels) { level in
            Button(action: {
                Task { await logLevel(level) }
            }) {
                Text(level.icon)
                    .font(.system(size: levelIconSize))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(levelColor(for: level).opacity(0.2))
                    .cornerRadius(10)
                    .overlay {
                        if loggedLevel?.id == level.id {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.green)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: loggedLevel?.id == level.id)
        }
    }
}

private var levelIconSize: CGFloat {
    // Kleinere Icons bei 4-5 Levels
    trackerLevels.count > 3 ? 24 : 28
}

private func levelColor(for level: TrackerLevel) -> Color {
    switch level.streakEffect {
    case .success: return .green
    case .needsGrace: return .yellow
    case .breaksStreak: return .red
    }
}
```

### 3. Log Action mit Feedback

```swift
@MainActor
private func logLevel(_ level: TrackerLevel) async {
    // Log entry
    _ = manager.logEntry(
        for: tracker,
        value: level.id,
        note: "\(level.icon) \(level.localizedLabel)",
        in: modelContext
    )

    // Visual feedback
    withAnimation(.spring(duration: 0.3)) {
        loggedLevel = level
    }

    // Reset after 1.5 seconds
    try? await Task.sleep(for: .seconds(1.5))
    withAnimation(.easeOut(duration: 0.2)) {
        loggedLevel = nil
    }
}
```

### 4. quickLogButton anpassen

```swift
@ViewBuilder
private var quickLogButton: some View {
    if isLevelBased {
        levelQuickLogButtons  // NEU: inline statt single button
    } else {
        legacyQuickLogButton
    }
}
```

### 5. LevelSelectionView bleibt für Advanced

- Edit-Button (...) kann weiterhin LevelSelectionView öffnen für historische Einträge
- Sheet wird nicht gelöscht, nur nicht mehr als primäre Logging-Methode verwendet

## Test Plan

### Automated Tests (TDD RED)

XCUITests in `LeanHealthTimerUITests.swift`:

- [ ] `testLevelTrackerShowsInlineButtons`: Level-Tracker zeigt Emoji-Buttons statt "Log"
- [ ] `testLevelTrackerDirectLog`: Tap auf Level-Button loggt direkt (kein Sheet)
- [ ] `testLevelTrackerFeedback`: Nach Tap erscheint Checkmark-Overlay

### Manual Tests

- [ ] NoAlc (neu via Preset) zeigt 💧 ✨ 💥 inline
- [ ] Mood Tracker zeigt 😢 😕 😐 🙂 😊 inline
- [ ] Bei 5 Levels: Icons passen noch in eine Zeile
- [ ] Checkmark-Animation erscheint nach Log
- [ ] Haptisches Feedback bei erfolgreichem Log

## Acceptance Criteria

- [ ] Alle level-basierten Tracker zeigen inline Emoji-Buttons
- [ ] 1 Tap = Log (kein Modal nötig)
- [ ] Visuelles Feedback (Checkmark + Animation)
- [ ] Haptisches Feedback
- [ ] UI konsistent mit noAlcCard
- [ ] Edit-Button (...) öffnet weiterhin Details/History

## Visual Comparison

### Vorher (TrackerRow für Level-Tracker)
```
┌─────────────────────────────────────┐
│ 🍷 NoAlc          🔥2  [  Log  ] ⋯ │
└─────────────────────────────────────┘
```

### Nachher (wie noAlcCard)
```
┌─────────────────────────────────────┐
│ 🍷 NoAlc  🔥2  [💧][✨][💥]      ⋯ │
└─────────────────────────────────────┘
```

## Rollback Plan

Bei Problemen: `levelQuickLogButtons` durch `levelQuickLogButton` ersetzen (alte Implementierung).
