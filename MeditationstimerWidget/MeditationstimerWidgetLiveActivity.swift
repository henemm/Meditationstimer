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
                           remaining: context.state.remainingSeconds,
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
                        Text(format(context.state.remainingSeconds))
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
                // z. B. Phase
                Text(context.state.phase == 1 ? "M" : "B")
                    .font(.caption2)
            } compactTrailing: {
                // Restsekunden kurz
                Text(shortFormat(context.state.remainingSeconds))
                    .font(.caption2).monospacedDigit()
            } minimal: {
                // Nur Sekunden minimal
                Text(shortFormat(context.state.remainingSeconds))
                    .monospacedDigit()
            }
            .keylineTint(.accentColor)
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let title: String
    let remaining: Int
    let phase: Int

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(phaseLabel(phase))
                .font(.subheadline)
            Text(format(remaining))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
    }
}

// MARK: - Helpers

private func phaseLabel(_ phase: Int) -> String {
    phase == 1 ? "Meditation" : "Besinnung"
}

private func format(_ s: Int) -> String {
    let m = s / 60
    let sec = s % 60
    return String(format: "%02d:%02d", m, sec)
}

private func shortFormat(_ s: Int) -> String {
    if s >= 60 {
        return "\(s/60)m"
    } else {
        return "\(s)s"
    }
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
        .init(remainingSeconds: 75, phase: 1)
    }
    static var sampleP2: MeditationAttributes.ContentState {
        .init(remainingSeconds: 12, phase: 2)
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
