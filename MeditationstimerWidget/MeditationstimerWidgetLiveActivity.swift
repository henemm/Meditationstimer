//
//  MeditationstimerWidgetLiveActivity.swift
//  MeditationstimerWidget
//
//  Created by Henning Emmrich on 12.09.25.
//

import ActivityKit
import WidgetKit
import SwiftUI

// WICHTIG: Dieses Widget verwendet die im App‑Target definierte Struktur `MeditationAttributes`.
// Stelle sicher, dass die Datei `MeditationActivityAttributes.swift` auch der Widget‑Extension
// zugeordnet ist (Target Membership), damit der Typ hier bekannt ist.

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
                // Expanded – großer Countdown + Phase
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 6) {
                        Text(phaseLabel(context.state.phase))
                            .font(.headline)
                        Text(context.state.endDate, style: .timer)
                            .font(.system(size: 44, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.title)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                HStack(spacing: 4) {
                    Text(context.state.phase == 1 ? "M" : "B")
                        .font(.caption2).bold()
                    Text(context.state.endDate, style: .timer)
                        .font(.caption2).monospacedDigit()
                }
            } minimal: {
                // Nur Sekunden minimal
                Text(context.state.endDate, style: .timer)
                    .monospacedDigit()
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
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(phaseLabel(phase))
                .font(.subheadline)

            Text(endDate, style: .timer)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .center)

            Text("Minuten")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
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
#endif
