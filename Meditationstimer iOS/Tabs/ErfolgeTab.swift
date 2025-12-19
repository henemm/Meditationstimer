//
//  ErfolgeTab.swift
//  Meditationstimer iOS
//
//  Created by Claude Code on 15.12.2025.
//
//  Achievements tab showing streaks and embedded calendar view.
//  This is part of Phase 1.1 Tab Navigation Refactoring.
//
//  Layout:
//  - Streak Overview (compact header)
//  - Embedded CalendarView (main content)
//

import SwiftUI

#if os(iOS)

struct ErfolgeTab: View {
    @EnvironmentObject var streakManager: StreakManager
    @State private var showingFullCalendar = false

    // Computed property for total rewards across all streak types
    private var totalRewards: Int {
        streakManager.meditationStreak.rewardsEarned + streakManager.workoutStreak.rewardsEarned
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Compact Streak Header
                StreakHeaderSection(
                    meditationDays: streakManager.meditationStreak.currentStreakDays,
                    workoutDays: streakManager.workoutStreak.currentStreakDays,
                    rewards: totalRewards
                )
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Embedded Calendar
                CalendarView()
                    .environmentObject(streakManager)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Compact Streak Header
/// Condensed streak display for top of Erfolge tab
private struct StreakHeaderSection: View {
    let meditationDays: Int
    let workoutDays: Int
    let rewards: Int

    var body: some View {
        HStack(spacing: 16) {
            // Meditation Streak
            CompactStreakBadge(emoji: "🧘", days: meditationDays)

            // Workout Streak
            CompactStreakBadge(emoji: "💪", days: workoutDays)

            Spacer()

            // Rewards
            HStack(spacing: 4) {
                Text("⭐")
                    .font(.system(size: 18))
                Text("\(rewards)")
                    .font(.subheadline.bold())
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
}

// MARK: - Compact Streak Badge
private struct CompactStreakBadge: View {
    let emoji: String
    let days: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: 20))
            Text("\(days)")
                .font(.headline.bold())
                .monospacedDigit()
            Text(NSLocalizedString("days", comment: "Days label"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

#if DEBUG
#Preview {
    ErfolgeTab()
        .environmentObject(StreakManager())
}
#endif

#endif // os(iOS)
