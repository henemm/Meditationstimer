//
//  MeditationstimerWidgetLiveActivity.swift
//  MeditationstimerWidget
//
//  Created by Henning Emmrich on 12.09.25.
//

import ActivityKit
import WidgetKit
import SwiftUI

// Uses MeditationAttributes from the main app target

#if os(iOS)
struct MeditationstimerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeditationAttributes.self) { context in
            // Sperrbildschirm / Banner – große, gut lesbare Anzeige
            LockScreenView(title: context.attributes.title,
                           endDate: context.state.endDate,
                           phase: context.state.phase)
            .activityBackgroundTint(.black.opacity(0.2))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded – clean, focused timer
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(phaseLabel(context.state.phase))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(context.state.endDate, style: .timer)
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    .fixedSize()
                }
            } compactLeading: {
                Image(systemName: "figure.mind.and.body")
                    .foregroundColor(.blue)
            } compactTrailing: {
                // Just timer - no phase abbreviation clutter
                Text(context.state.endDate, style: .timer)
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "figure.mind.and.body")
                    .foregroundColor(.blue)
            }
            .keylineTint(.accentColor)
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let title: String
    let endDate: Date
    let phase: Int

    var body: some View {
        VStack(spacing: 12) {
            // Simple phase indicator - no redundant title
            Text(phaseLabel(phase))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            // Centered, prominent timer - main focus
            Text(endDate, style: .timer)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Helpers

private func phaseLabel(_ phase: Int) -> String {
    phase == 1 ? "Meditation" : "Besinnung"
}



// MARK: - Previews

#if DEBUG
extension MeditationAttributes {
    static var preview: MeditationAttributes {
        MeditationAttributes(title: "Meditationstimer")
    }
}

extension MeditationAttributes.ContentState {
    static var sampleP1: MeditationAttributes.ContentState {
        .init(endDate: Date().addingTimeInterval(75), phase: 1)
    }
    static var sampleP2: MeditationAttributes.ContentState {
        .init(endDate: Date().addingTimeInterval(12), phase: 2)
    }
}

#Preview("Lock Screen – Phase 1", as: .content, using: MeditationAttributes.preview) {
    MeditationstimerWidgetLiveActivity()
} contentStates: {
    MeditationAttributes.ContentState.sampleP1
}

#Preview("Lock Screen – Phase 2", as: .content, using: MeditationAttributes.preview) {
    MeditationstimerWidgetLiveActivity()
} contentStates: {
    MeditationAttributes.ContentState.sampleP2
}
#else
// Fallback Widget for macOS Preview context
struct MeditationstimerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MeditationTimer", provider: Provider()) { entry in
            Text("Live Activities require iOS")
        }
        .configurationDisplayName("Meditation Timer")
        .description("Live Activity for meditation sessions")
    }
}

private struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry { SimpleEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) { completion(SimpleEntry(date: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) { completion(Timeline(entries: [SimpleEntry(date: Date())], policy: .never)) }
}

private struct SimpleEntry: TimelineEntry {
    let date: Date
}
#endif
#endif
