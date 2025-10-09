//
//  STYLING BACKUP - MeditationstimerWidgetLiveActivity.swift
//  Sicherung des detaillierten Stylings vor Wiederherstellung
//  Erstellt am: 9. Oktober 2025
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
                // Sinnvolle Expanded: App-Info links, Timer rechts
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 12) {
                        // Phase-spezifisches Icon
                        Image(systemName: context.state.phase == 1 ? "figure.mind.and.body" : "leaf")
                            .font(.title2)
                            .foregroundStyle(.white)
                        
                        // Phase-Info
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Meditation")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                            Text(phaseLabel(context.state.phase))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // Timer rechts
                    Text(context.state.endDate, style: .timer)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.trailing)
                }
            } compactLeading: {
                Image(systemName: "figure.mind.and.body")
                    .foregroundColor(.blue)
            } compactTrailing: {
                // Rechts: Timer mit OVERLAY-TRICK gegen Width-Bug
                Text("00:00")
                    .hidden()
                    .overlay(alignment: .leading) {
                        Text(context.state.endDate, style: .timer)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
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
        HStack {
            // Links: Phase-spezifisches Icon in Kreis
            Image(systemName: phase == 1 ? "figure.mind.and.body" : "leaf")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.blue.opacity(0.3)))
                .padding(.leading, 12)
            
            Spacer()
            
            // Mitte: Nur Timer, groß und schlicht (wie im Vorbild)
            Text(endDate, style: .timer)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            
            // Rechts: Phasen-Emoji in Kreis (unterscheidet sich vom App-Icon)
            Text(phase == 1 ? "🧘‍♂️" : "🍃")
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.green.opacity(0.3)))
                .padding(.trailing, 12)
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

#Preview("Dynamic Island – Phase 1", as: .dynamicIsland(.compact), using: MeditationAttributes.preview) {
    MeditationstimerWidgetLiveActivity()
} contentStates: {
    MeditationAttributes.ContentState.sampleP1
}

#Preview("Dynamic Island – Phase 2", as: .dynamicIsland(.expanded), using: MeditationAttributes.preview) {
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