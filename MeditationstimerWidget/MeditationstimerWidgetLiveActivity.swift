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
                // Expanded: Links Icons, rechts Timer - alles auf einer Höhe
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 12) {
                        // App SF icon as white glyph on filled AccentColor circle (matches app icon)
                        ZStack {
                            Circle()
                                .fill(Color("AccentColor"))
                                .frame(width: 36, height: 36)
                            Image(systemName: "figure.mind.and.body")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        // (Emoji moved to the right side next to the timer)
                    }
                    .padding(.leading)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // Timer rechts - Emoji direkt rechts daneben
                    HStack(spacing: 10) {
                        Text(context.state.endDate, style: .timer)
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)

                        // Emoji in Kreis rechts neben dem Timer
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.3))
                                .frame(width: 36, height: 36)
                            Text(context.state.phase == 1 ? "🧘‍♂️" : "🍃")
                                .font(.title2)
                        }
                    }
                    .padding(.trailing)
                }
            } compactLeading: {
                ZStack {
                    Circle()
                        .fill(Color("AccentColor"))
                        .frame(width: 20, height: 20)
                    Image(systemName: "figure.mind.and.body")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
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
                ZStack {
                    Circle()
                        .fill(Color("AccentColor"))
                        .frame(width: 18, height: 18)
                    Image(systemName: "figure.mind.and.body")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                }
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
            // Links: App SF icon as filled AccentColor with white glyph
            ZStack {
                Circle()
                    .fill(Color("AccentColor"))
                    .frame(width: 40, height: 40)
                Image(systemName: "figure.mind.and.body")
                    .font(.title2)
                    .foregroundColor(.white)
            }
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
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 40, height: 40)
                Text(phase == 1 ? "🧘‍♂️" : "🍃")
                    .font(.title2)
            }
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