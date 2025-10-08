//
//  MeditationstimerWidgetLiveActivity.swift
//  MeditationstimerWidget
//
//  Created by Henning Emmrich on 12.09.25.
//

import WidgetKit
import SwiftUI

// MARK: - MeditationAttributes Definition
// Define directly in widget to avoid target scope issues
#if canImport(ActivityKit) && os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit

struct MeditationAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var endDate: Date
        var phase: Int // 1 = Meditation, 2 = Besinnung
    }
    var title: String
}

@available(iOS 16.1, *)
struct MeditationstimerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeditationAttributes.self) { context in
            LockScreenView(title: context.attributes.title,
                           endDate: context.state.endDate,
                           phase: context.state.phase)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(phaseLabel(context.state.phase))
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)
                        Text(context.state.endDate, style: .timer)
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.primary)
                            .monospacedDigit()
                    }
                    .fixedSize()
                }
            } compactLeading: {
                Image(systemName: "figure.mind.and.body")
                    .foregroundColor(.blue)
            } compactTrailing: {
                Text(context.state.endDate, style: .timer)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.primary)
                    .monospacedDigit()
                    .overlay(
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 50)
                    )
            } minimal: {
                Image(systemName: "figure.mind.and.body")
                    .foregroundColor(.blue)
            }
        }
    }
}

private struct LockScreenView: View {
    let title: String
    let endDate: Date
    let phase: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.mind.and.body")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    Text(phaseLabel(phase))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(endDate, style: .timer)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.blue)
                        .monospacedDigit()
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

#else
// MARK: - Fallback for non-iOS environments
struct MeditationAttributes {
    public struct ContentState: Codable, Hashable {
        var endDate: Date
        var phase: Int
    }
    var title: String
}

struct MeditationstimerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MeditationTimer", provider: Provider()) { entry in
            Text("Live Activities require iOS 16.1+")
        }
        .configurationDisplayName("Meditation Timer")
        .description("Live Activity for meditation sessions")
    }
}

private struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(SimpleEntry(date: Date()))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        completion(Timeline(entries: [SimpleEntry(date: Date())], policy: .never))
    }
}

private struct SimpleEntry: TimelineEntry {
    let date: Date
}

private struct LockScreenView: View {
    let title: String
    let endDate: Date
    let phase: Int

    var body: some View {
        VStack {
            Text("Live Activity Preview")
            Text(title)
            Text("5:00").monospacedDigit()
        }
        .padding()
    }
}
#endif

// MARK: - Helpers
private func phaseLabel(_ phase: Int) -> String {
    phase == 1 ? "Meditation" : "Besinnung"
}

// MARK: - Previews
#if DEBUG
#Preview("Lock Screen", as: .content, using: MeditationAttributes(title: "Meditation Timer")) {
    MeditationstimerWidgetLiveActivity()
} contentStates: {
    MeditationAttributes.ContentState(endDate: Date().addingTimeInterval(300), phase: 1)
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: MeditationAttributes(title: "Meditation Timer")) {
    MeditationstimerWidgetLiveActivity()
} contentStates: {
    MeditationAttributes.ContentState(endDate: Date().addingTimeInterval(300), phase: 1)
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: MeditationAttributes(title: "Meditation Timer")) {
    MeditationstimerWidgetLiveActivity()
} contentStates: {
    MeditationAttributes.ContentState(endDate: Date().addingTimeInterval(300), phase: 1)
}
#endif
