# Context: FEAT-38 Inline Level Buttons

## Request Summary
Alle level-basierten Tracker sollen dieselben Quick-Log Buttons wie die noAlcCard haben - inline Emoji-Buttons statt "Log" Button mit Modal Sheet.

## Problem

| Komponente | UI | Logging |
|------------|-----|---------|
| **noAlcCard** (TrackerTab) | 3 inline Emoji-Buttons (💧 ✨ 💥) | 1 Tap = logged |
| **TrackerRow** (für alle anderen) | Ein "Log" Button | 1 Tap → Sheet → 2. Tap = logged |

Der User erwartet konsistentes Verhalten: Direkt tracken mit einem Tap.

## Related Files

| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Tabs/TrackerTab.swift` | noAlcCard mit inline Buttons (Zeile 86-147, 173-214) |
| `Meditationstimer iOS/Tracker/TrackerRow.swift` | levelQuickLogButton öffnet Sheet (Zeile 209-221) |
| `Meditationstimer iOS/Tracker/LevelSelectionView.swift` | Modal Sheet für Level-Auswahl |
| `Services/TrackerModels.swift` | TrackerLevel Definition (Zeile 42-53) |

## Existing Patterns

### noAlcCard Implementation (TrackerTab.swift:86-147)
```swift
private func noAlcButton(_ level: TrackerLevel, color: Color) -> some View {
    Button(action: {
        Task {
            // Log to SwiftData
            tracker.logLevel(level, context: modelContext)
            // Show feedback animation
            withAnimation(.spring(duration: 0.3)) {
                loggedLevel = level
            }
            // Reset after 1.5 seconds
            try? await Task.sleep(for: .seconds(1.5))
            loggedLevel = nil
        }
    }) {
        Text(level.icon)
            .font(.system(size: 32))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.2))
            .cornerRadius(10)
            .overlay {
                if loggedLevel?.id == level.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
    }
}
```

### TrackerRow Current Implementation (TrackerRow.swift:209-221)
```swift
private var levelQuickLogButton: some View {
    Button(action: { showingLevelSheet = true }) {
        Text(NSLocalizedString("Log", comment: ""))
            .font(.subheadline.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.blue)
            .foregroundStyle(.white)
            .cornerRadius(16)
    }
}
```

## Scope Assessment

- **Files:** 1 (TrackerRow.swift)
- **Estimated LoC:** +30/-15 (net +15)
- **Risk Level:** LOW (self-contained UI change)

## Technical Approach

1. **Add State für Feedback:**
   ```swift
   @State private var loggedLevel: TrackerLevel? = nil
   ```

2. **Inline Level Buttons:**
   ```swift
   private var levelQuickLogButtons: some View {
       HStack(spacing: 6) {
           ForEach(trackerLevels) { level in
               inlineLevelButton(level)
           }
       }
   }
   ```

3. **Keep Sheet für Advanced:**
   - (i) oder Edit-Button kann weiterhin LevelSelectionView öffnen für DatePicker

## Open Questions

- [x] Soll das Modal Sheet (LevelSelectionView) komplett verschwinden?
  → Nein, Advanced-Modus für historische Einträge bleibt nützlich

## Risks & Considerations

- **Layout:** Bei 5 Levels (Mood) könnte Platz knapp werden
  → Lösung: Kleinere Icons (font size 24 statt 32)
- **Info-Button:** Brauchen wir einen separaten Info-Button für historische Einträge?
  → Vorschlag: Long-Press auf beliebigen Button öffnet Sheet
