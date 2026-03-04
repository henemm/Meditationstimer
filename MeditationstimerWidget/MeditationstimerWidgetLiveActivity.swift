//
//  STYLING BACKUP - MeditationstimerWidgetLiveActivity.swift
//  Sicherung des detaillierten Stylings vor Wiederherstellung
//  Erstellt am: 9. Oktober 2025
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Timer Helper

private func timeString(from endDate: Date) -> String {
    let now = Date()
    let interval = max(Int(endDate.timeIntervalSince(now)), 0)
    let minutes = interval / 60
    let seconds = interval % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

// Uses MeditationAttributes from the main app target

#if os(iOS)
struct MeditationstimerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeditationAttributes.self) { context in
            // Sperrbildschirm / Banner – große, gut lesbare Anzeige
            LockScreenView(title: context.attributes.title,
                           endDate: context.state.endDate,
                           phase: context.state.phase,
                           ownerId: context.state.ownerId,
                           isPaused: context.state.isPaused,
                           phaseEndDate: context.state.phaseEndDate)
            .activityBackgroundTint(.black.opacity(0.2))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded: Links Icons, rechts Timer - alles auf einer Höhe
                DynamicIslandExpandedRegion(.leading) {
                    VStack {
                        if let owner = context.state.ownerId {
                            if owner == "AtemTab" {
                                let iconName: String = {
                                    if context.state.phase == 1 { return "arrow.up" }
                                    if context.state.phase == 2 { return "arrow.right" }
                                    if context.state.phase == 3 { return "arrow.down" }
                                    return "arrow.right"
                                }()
                                ZStack {
                                    Circle()
                                        .fill(Color.green.opacity(0.28))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: iconName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            } else if owner == "OffenTab" {
                                ZStack {
                                    Circle()
                                        .fill(Color.green.opacity(0.28))
                                        .frame(width: 52, height: 52)
                                    Text(context.state.phase == 1 ? "🧘‍♂️" : "🍃")
                                        .font(.title3)
                                }
                            } else if owner == "WorkoutsTab" {
                                let iconName: String = {
                                    if context.state.phase == 1 { return "flame" } // work phase
                                    return "pause" // rest phase or default
                                }()
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.28))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: iconName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(Color("AccentColor"))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "figure.mind.and.body")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                }
                            }
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color("AccentColor"))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "figure.mind.and.body")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.vertical, 12)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let phaseEnd = context.state.phaseEndDate {
                        // Dual Timer: Phase (groß) + Gesamt (klein)
                        VStack(alignment: .trailing, spacing: 2) {
                            if context.state.isPaused {
                                Text(timeString(from: phaseEnd))
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                                Text(timeString(from: context.state.endDate))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.white.opacity(0.6))
                            } else {
                                Text(phaseEnd, style: .timer)
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                                Text(context.state.endDate, style: .timer)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .layoutPriority(1)
                        .padding(.trailing, 16)
                        .padding(.vertical, 12)
                        .padding(.top, 4)
                    } else {
                        // Single Timer (bestehend)
                        VStack {
                            if context.state.isPaused {
                                Text(timeString(from: context.state.endDate))
                                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .minimumScaleFactor(0.6)
                                    .lineLimit(1)
                                    .foregroundStyle(.white)
                                    .layoutPriority(1)
                                    .padding(.top, 4)
                                    .padding(.trailing, 16)
                            } else {
                                Text(context.state.endDate, style: .timer)
                                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .minimumScaleFactor(0.6)
                                    .lineLimit(1)
                                    .foregroundStyle(.white)
                                    .layoutPriority(1)
                                    .padding(.top, 4)
                                    .padding(.trailing, 16)
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.vertical, 12)
                        .padding(.top, 4)
                    }
                }
            } compactLeading: {
                // Compact Leading: show phase icon instead of static app icon
                if let owner = context.state.ownerId {
                    if owner == "AtemTab" {
                        let iconName: String = {
                            if context.state.phase == 1 { return "arrow.up" }
                            if context.state.phase == 2 { return "arrow.right" }
                            if context.state.phase == 3 { return "arrow.down" }
                            return "arrow.right" // Phase 4: hold out
                        }()
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.28))
                                .frame(width: 20, height: 20)
                            Image(systemName: iconName)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    } else if owner == "OffenTab" {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.28))
                                .frame(width: 20, height: 20)
                            Text(context.state.phase == 1 ? "🧘‍♂️" : "🍃")
                                .font(.system(size: 8))
                        }
                    } else if owner == "WorkoutsTab" {
                        let iconName: String = {
                            if context.state.phase == 1 { return "flame" } // work phase
                            return "pause" // rest phase or default
                        }()
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.28))
                                .frame(width: 20, height: 20)
                            Image(systemName: iconName)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color("AccentColor"))
                                .frame(width: 20, height: 20)
                            Image(systemName: "figure.mind.and.body")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                        }
                    }
                } else {
                    ZStack {
                        Circle()
                            .fill(Color("AccentColor"))
                            .frame(width: 20, height: 20)
                        Image(systemName: "figure.mind.and.body")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                    }
                }
            } compactTrailing: {
                // Rechts: Timer mit OVERLAY-TRICK gegen Width-Bug
                // Bei Workout: Phase-Timer (relevanter), sonst Gesamt-Timer
                let timerDate = context.state.phaseEndDate ?? context.state.endDate
                Text("00:00")
                    .hidden()
                    .overlay(alignment: .leading) {
                        if context.state.isPaused {
                            Text(timeString(from: timerDate))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        } else {
                            Text(timerDate, style: .timer)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        }
                    }
            } minimal: {
                // Minimal: show phase icon instead of static app icon
                if let owner = context.state.ownerId {
                    if owner == "AtemTab" {
                        let iconName: String = {
                            if context.state.phase == 1 { return "arrow.up" }
                            if context.state.phase == 2 { return "arrow.right" }
                            if context.state.phase == 3 { return "arrow.down" }
                            return "arrow.right" // Phase 4: hold out
                        }()
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.28))
                                .frame(width: 18, height: 18)
                            Image(systemName: iconName)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    } else if owner == "OffenTab" {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.28))
                                .frame(width: 18, height: 18)
                            Text(context.state.phase == 1 ? "🧘‍♂️" : "🍃")
                                .font(.system(size: 6))
                        }
                    } else if owner == "WorkoutsTab" {
                        let iconName: String = {
                            if context.state.phase == 1 { return "flame" } // work phase
                            return "pause" // rest phase or default
                        }()
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.28))
                                .frame(width: 18, height: 18)
                            Image(systemName: iconName)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color("AccentColor"))
                                .frame(width: 18, height: 18)
                            Image(systemName: "figure.mind.and.body")
                                .font(.system(size: 8))
                                .foregroundColor(.white)
                        }
                    }
                } else {
                    ZStack {
                        Circle()
                            .fill(Color("AccentColor"))
                            .frame(width: 18, height: 18)
                        Image(systemName: "figure.mind.and.body")
                            .font(.system(size: 8))
                            .foregroundColor(.white)
                    }
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
    let isPaused: Bool
    let phaseEndDate: Date?

    var body: some View {
        HStack {
            if let phaseEnd = phaseEndDate {
                // Dual Timer Layout (Workout): Phase links groß, Gesamt rechts klein
                // Kein Icon, kein Label — selbsterklärend
                if isPaused {
                    Text(timeString(from: phaseEnd))
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Spacer()
                    Text(timeString(from: endDate))
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    Text(phaseEnd, style: .timer)
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Spacer()
                    Text(endDate, style: .timer)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.6))
                }
            } else {
                // Single Timer Layout (Meditation/Atem): Icon + Timer
                if let owner = ownerId {
                    if owner == "AtemTab" {
                        let iconName: String = {
                            if phase == 1 { return "arrow.up" }
                            if phase == 2 { return "arrow.right" }
                            if phase == 3 { return "arrow.down" }
                            return "arrow.right"
                        }()
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.28))
                                .frame(width: 40, height: 40)
                            Image(systemName: iconName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.leading)
                    } else if owner == "OffenTab" {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.28))
                                .frame(width: 40, height: 40)
                            Text(phase == 1 ? "🧘‍♂️" : "🍃")
                                .font(.title2)
                        }
                        .padding(.leading)
                    } else if owner == "WorkoutsTab" {
                        let iconName: String = {
                            if phase == 1 { return "flame" }
                            return "pause"
                        }()
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.28))
                                .frame(width: 40, height: 40)
                            Image(systemName: iconName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.leading)
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color("AccentColor"))
                                .frame(width: 40, height: 40)
                            Image(systemName: "figure.mind.and.body")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                        .padding(.leading)
                    }
                } else {
                    ZStack {
                        Circle()
                            .fill(Color("AccentColor"))
                            .frame(width: 40, height: 40)
                        Image(systemName: "figure.mind.and.body")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    .padding(.leading)
                }

                Spacer()
                if isPaused {
                    Text(timeString(from: endDate))
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                } else {
                    Text(endDate, style: .timer)
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
// MARK: - Timer Helper

private func timeString(from endDate: Date) -> String {
    let now = Date()
    let interval = max(Int(endDate.timeIntervalSince(now)), 0)
    let minutes = interval / 60
    let seconds = interval % 60
    return String(format: "%02d:%02d", minutes, seconds)
}
}

// MARK: - Helpers

private func phaseLabel(_ phase: Int) -> String {
    phase == 1 ? "Meditation" : NSLocalizedString("Closing", comment: "Phase 2 session label")
}

// MARK: - Previews

#if DEBUG
extension MeditationAttributes {
    static var preview: MeditationAttributes {
        MeditationAttributes(title: "Healthy Habits")
    }
}

extension MeditationAttributes.ContentState {
    static var sampleP1: MeditationAttributes.ContentState {
        .init(endDate: Date().addingTimeInterval(75), phase: 1, ownerId: "AtemTab", isPaused: false)
    }
    static var sampleP2: MeditationAttributes.ContentState {
        .init(endDate: Date().addingTimeInterval(12), phase: 2, ownerId: nil, isPaused: false)
    }
    static var sampleWorkout: MeditationAttributes.ContentState {
        .init(endDate: Date().addingTimeInterval(734), phase: 1, ownerId: "WorkoutsTab", isPaused: false, phaseEndDate: Date().addingTimeInterval(28))
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

#Preview("Lock Screen – Workout", as: .content, using: MeditationAttributes.preview) {
    MeditationstimerWidgetLiveActivity()
} contentStates: {
    MeditationAttributes.ContentState.sampleWorkout
}

#Preview("Dynamic Island – Phase 1", as: .dynamicIsland(.compact), using: MeditationAttributes.preview) {
    MeditationstimerWidgetLiveActivity()
} contentStates: {
    MeditationAttributes.ContentState.sampleP1
}

#Preview("Dynamic Island – Workout Expanded", as: .dynamicIsland(.expanded), using: MeditationAttributes.preview) {
    MeditationstimerWidgetLiveActivity()
} contentStates: {
    MeditationAttributes.ContentState.sampleWorkout
}

#Preview("Dynamic Island – Workout Compact", as: .dynamicIsland(.compact), using: MeditationAttributes.preview) {
    MeditationstimerWidgetLiveActivity()
} contentStates: {
    MeditationAttributes.ContentState.sampleWorkout
}
#else
// Live Activities are not supported on non-iOS platforms
#endif
#endif