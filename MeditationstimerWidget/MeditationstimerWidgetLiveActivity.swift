//
//  MeditationstimerWidgetLiveActivity.swift
//  MeditationstimerWidget
//
//  Created by Henning Emmrich on 12.09.25.
//

import WidgetKit
import SwiftUI
#if os(iOS)
import ActivityKit

// WICHTIG: Dieses Widget verwendet die im App‑Target definierte Struktur `MeditationAttributes`.
// Stelle sicher, dass die Datei `MeditationActivityAttributes.swift` auch der Widget‑Extension
// zugeordnet ist (Target Membership), damit der Typ hier bekannt ist.

@available(iOS 16.1, *)
struct MeditationstimerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeditationAttributes.self) { context in
            // Sperrbildschirm / Banner – große, gut lesbare Anzeige
            LockScreenView(title: context.attributes.title,
                           endDate: context.state.endDate,
                           phase: context.state.phase)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded – kompakt, mittig, ohne künstliche Breite
                DynamicIslandExpandedRegion(.center) {
                    // Nur der Timer, mittig, ohne zusätzliche Labels → bleibt schmal
                    Text(context.state.endDate, style: .timer)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .fixedSize()
                }
            } compactLeading: {
                // Leading bewusst leer lassen, damit iOS nur eine kompakte Blase rechts rendert
                EmptyView()
            } compactTrailing: {
                // Zeit rechts – monospaced und klein
                Text(context.state.endDate, style: .timer)
                    .font(.caption2)
                    .monospacedDigit()
            } minimal: {
                // Nur Sekunden minimal
                Text(context.state.endDate, style: .timer)
                    .monospacedDigit()
            }
            // Keine explizite keylineTint – Standard reicht und beeinflusst Breite nicht
        }
    }
}
#endif // os(iOS)

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let title: String
    let endDate: Date
    let phase: Int
    
    private var showMinutesLabel: Bool {
        endDate.timeIntervalSince(Date()) >= 60
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            // Phase-Bezeichnung, dezent
            Text(phaseLabel(phase))
                .font(.subheadline)

            // Exakt zentrierter Timer, ohne ungewollte Breitenexpansion
            Text(endDate, style: .timer)
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize()

            if showMinutesLabel {
                Text("Minuten")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Helpers

private func phaseLabel(_ phase: Int) -> String {
    phase == 1 ? "Meditation" : "Besinnung"
}



// MARK: - Previews

#if DEBUG
#if os(iOS)
extension MeditationAttributes {
    static var preview: MeditationAttributes { MeditationAttributes(title: "Meditationstimer") }
}
extension MeditationAttributes.ContentState {
    static var sampleP1: MeditationAttributes.ContentState { .init(endDate: Date().addingTimeInterval(75), phase: 1) }
    static var sampleP2: MeditationAttributes.ContentState { .init(endDate: Date().addingTimeInterval(12), phase: 2) }
}
#Preview("Lock Screen – Phase 1", as: .content, using: MeditationAttributes.preview) {
    MeditationstimerWidgetLiveActivity()
} contentStates: { MeditationAttributes.ContentState.sampleP1 }

#Preview("Lock Screen – Phase 2", as: .content, using: MeditationAttributes.preview) {
    MeditationstimerWidgetLiveActivity()
} contentStates: { MeditationAttributes.ContentState.sampleP2 }
#endif

#endif
