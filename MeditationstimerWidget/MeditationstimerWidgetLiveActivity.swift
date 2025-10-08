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
                // Expanded Region für die App-Navigation beim Antippen
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: context.state.phase == 1 ? "figure.mind.and.body" : "leaf")
                            .font(.title2)
                            .foregroundStyle(.white)
                        VStack(alignment: .leading) {
                            Text(context.attributes.title)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(phaseLabel(context.state.phase))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.endDate, style: .timer)
                        .font(.title)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                        .padding(.horizontal)
                }
            } compactLeading: {
                // Links: Sehr kleines Icon
                Image(systemName: context.state.phase == 1 ? "figure.mind.and.body" : "leaf")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
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
                // Minimal: Nur das Icon, sehr klein
                Image(systemName: context.state.phase == 1 ? "figure.mind.and.body" : "leaf")
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
            }
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

#if DEBUG && os(iOS)
extension MeditationAttributes {
    static var preview: MeditationAttributes { 
        MeditationAttributes(title: "Meditation Timer") 
    }
}

extension MeditationAttributes.ContentState {
    static var sampleP1: MeditationAttributes.ContentState { 
        .init(endDate: Date().addingTimeInterval(300), phase: 1) // 5 Min Meditation
    }
    static var sampleP2: MeditationAttributes.ContentState { 
        .init(endDate: Date().addingTimeInterval(120), phase: 2) // 2 Min Besinnung
    }
}

#Preview("Lock Screen – Meditation", as: .content, using: MeditationAttributes.preview) {
    MeditationstimerWidgetLiveActivity()
} contentStates: { 
    MeditationAttributes.ContentState.sampleP1 
}

#Preview("Lock Screen – Besinnung", as: .content, using: MeditationAttributes.preview) {
    MeditationstimerWidgetLiveActivity()
} contentStates: { 
    MeditationAttributes.ContentState.sampleP2 
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: MeditationAttributes.preview) {
    MeditationstimerWidgetLiveActivity()
} contentStates: { 
    MeditationAttributes.ContentState.sampleP1 
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: MeditationAttributes.preview) {
    MeditationstimerWidgetLiveActivity()
} contentStates: { 
    MeditationAttributes.ContentState.sampleP1 
}

#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using: MeditationAttributes.preview) {
    MeditationstimerWidgetLiveActivity()
} contentStates: { 
    MeditationAttributes.ContentState.sampleP1 
}
#endif
