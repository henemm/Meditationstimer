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
                           phase: context.state.phase,
                           ownerId: context.state.ownerId)
            .activityBackgroundTint(.black.opacity(0.2))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded: Links Icons, rechts Timer - alles auf einer Höhe
                DynamicIslandExpandedRegion(.leading) {
                    // Leading region: show the phase icon for the current activity (replaces app icon)
                    // For AtemTab: use SF arrow mapping. For OffenTab: use emoji mapping. Fallback to app icon.
                    if let owner = context.state.ownerId {
                        if owner == "AtemTab" {
                            let iconName: String = {
                                if context.state.phase == 1 { return "arrow.up" }
                                if context.state.phase == 2 { return "arrow.left" }
                                if context.state.phase == 3 { return "arrow.down" }
                                return "arrow.right"
                            }()
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.28))
                                    .frame(width: 36, height: 36)
                                Image(systemName: iconName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.leading)
                        } else if owner == "OffenTab" {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.28))
                                    .frame(width: 36, height: 36)
                                Text(context.state.phase == 1 ? "🧘‍♂️" : "🍃")
                                    .font(.title3)
                            }
                            .padding(.leading)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color("AccentColor"))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "figure.mind.and.body")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            }
                            .padding(.leading)
                        }
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color("AccentColor"))
                                .frame(width: 36, height: 36)
                            Image(systemName: "figure.mind.and.body")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        .padding(.leading)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // Trailing region: show the timer (no phase bubble here) — allow font scaling to avoid truncation
                    HStack {
                        Spacer(minLength: 6)
                        Text(context.state.endDate, style: .timer)
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .foregroundStyle(.white)
                            .layoutPriority(1)
                        Spacer(minLength: 6)
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
    let ownerId: String?

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
            
            // Rechts: Phasen-Icon/Emoji in Kreis — arrows only for AtemTab
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 40, height: 40)
                if ownerId == "AtemTab" {
                    // arrows for Atem
                    let iconName: String = {
                        if phase == 1 { return "arrow.up" }
                        if phase == 3 { return "arrow.down" }
                        return "arrow.right"
                    }()
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundColor(.white)
                } else {
                    // fallback: emoji mapping used previously
                    Text(phase == 1 ? "🧘‍♂️" : "🍃")
                        .font(.title2)
                }
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
        .init(endDate: Date().addingTimeInterval(75), phase: 1, ownerId: "AtemTab")
    }
    static var sampleP2: MeditationAttributes.ContentState {
        .init(endDate: Date().addingTimeInterval(12), phase: 2, ownerId: nil)
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