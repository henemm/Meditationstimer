//
//  TrackerRow.swift
//  Meditationstimer iOS
//
//  Created by Claude on 19.12.2025.
//
//  Reusable row component for displaying a tracker with quick-log functionality.
//

import SwiftUI
import SwiftData

#if os(iOS)

struct TrackerRow: View {
    let tracker: Tracker
    let onEdit: () -> Void

    @Environment(\.modelContext) private var modelContext
    private let manager = TrackerManager.shared

    // Sheet states for awareness presets
    @State private var showingMoodSheet = false
    @State private var showingFeelingsSheet = false
    @State private var showingGratitudeSheet = false
    @State private var showingLevelSheet = false

    // Check if this is a special awareness preset
    private var isSpecialAwareness: Bool {
        tracker.trackingMode == .awareness &&
        ["Mood", "Feelings", "Gratitude"].contains(tracker.name)
    }

    // Check if this is a level-based tracker (Generic Tracker System)
    private var isLevelBased: Bool {
        if case .levels = tracker.effectiveValueType {
            return true
        }
        return false
    }

    // Get levels for level-based tracker
    private var trackerLevels: [TrackerLevel] {
        tracker.levels ?? []
    }

    var body: some View {
        GlassCard {
            HStack(alignment: .center, spacing: 14) {
                // Icon
                Text(tracker.icon)
                    .font(.system(size: 42))

                // Name + Today's status + Streak
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(tracker.name)
                            .font(.headline)
                        streakBadge
                    }
                    todayStatusView
                }

                Spacer()

                // Quick-Log Button (mode-dependent)
                quickLogButton

                // Edit Button
                Button(action: onEdit) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
            .frame(minHeight: 80)
        }
        .sheet(isPresented: $showingMoodSheet) {
            MoodSelectionView(tracker: tracker, onSave: {})
        }
        .sheet(isPresented: $showingFeelingsSheet) {
            FeelingsSelectionView(tracker: tracker, onSave: {})
        }
        .sheet(isPresented: $showingGratitudeSheet) {
            GratitudeLogView(tracker: tracker, onSave: {})
        }
        .sheet(isPresented: $showingLevelSheet) {
            LevelSelectionView(tracker: tracker, onSave: {})
        }
    }

    // MARK: - Today Status View

    @ViewBuilder
    private var todayStatusView: some View {
        // Level-based tracker takes precedence
        if isLevelBased {
            levelStatusView
        } else {
            legacyStatusView
        }
    }

    @ViewBuilder
    private var levelStatusView: some View {
        let todayLogs = manager.todayLogs(for: tracker, in: modelContext)
        if let lastLog = todayLogs.last,
           let levelId = lastLog.value,
           let level = trackerLevels.first(where: { $0.id == levelId }) {
            // Show today's logged level
            HStack(spacing: 4) {
                Text(level.icon)
                Text(level.localizedLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            // Not logged today
            Text(NSLocalizedString("Not logged", comment: "Level tracker not logged"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var legacyStatusView: some View {
        switch tracker.trackingMode {
        case .counter:
            let total = manager.todayTotal(for: tracker, in: modelContext)
            let goal = tracker.dailyGoal ?? 0
            if goal > 0 {
                Text("\(total)/\(goal)")
                    .font(.subheadline)
                    .foregroundStyle(total >= goal ? .green : .secondary)
            } else {
                Text("\(total)×")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .yesNo:
            let logged = manager.isLoggedToday(for: tracker, in: modelContext)
            HStack(spacing: 4) {
                Image(systemName: logged ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(logged ? .green : .secondary)
                Text(logged ?
                     NSLocalizedString("Done", comment: "Tracker logged today") :
                     NSLocalizedString("Not yet", comment: "Tracker not logged"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .awareness:
            let count = manager.todayLogs(for: tracker, in: modelContext).count
            Text(String(format: NSLocalizedString("%d× noticed", comment: "Awareness count"), count))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .avoidance:
            let streak = manager.streak(for: tracker, in: modelContext)
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text(String(format: NSLocalizedString("%d days", comment: "Avoidance streak"), streak))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .levels:
            // Handled by levelStatusView, this is a fallback
            EmptyView()
        }
    }

    // MARK: - Streak Badge

    @ViewBuilder
    private var streakBadge: some View {
        // Don't show badge for avoidance (streak shown in status)
        if tracker.trackingMode != .avoidance {
            let streak = manager.streak(for: tracker, in: modelContext)
            if streak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                    Text("\(streak)")
                        .font(.caption.bold())
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.orange.opacity(0.15))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Quick Log Button

    @ViewBuilder
    private var quickLogButton: some View {
        // Level-based tracker takes precedence
        if isLevelBased {
            levelQuickLogButton
        } else {
            legacyQuickLogButton
        }
    }

    @ViewBuilder
    private var levelQuickLogButton: some View {
        // Open level selection sheet
        Button(action: { showingLevelSheet = true }) {
            Text(NSLocalizedString("Log", comment: "Level tracker log button"))
                .font(.subheadline.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.blue)
                .foregroundStyle(.white)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var legacyQuickLogButton: some View {
        switch tracker.trackingMode {
        case .counter:
            HStack(spacing: 4) {
                Button(action: decrementCounter) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(manager.todayTotal(for: tracker, in: modelContext) <= 0)

                Button(action: incrementCounter) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

        case .yesNo:
            let logged = manager.isLoggedToday(for: tracker, in: modelContext)
            Button(action: quickLog) {
                Image(systemName: logged ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 32))
                    .foregroundStyle(logged ? .green : .blue)
            }
            .buttonStyle(.plain)
            .disabled(logged)

        case .awareness:
            Button(action: openAwarenessSheet) {
                Text(NSLocalizedString("Notice", comment: "Awareness log button"))
                    .font(.subheadline.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(16)
            }
            .buttonStyle(.plain)

        case .avoidance:
            Button(action: quickLog) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(NSLocalizedString("Relapse", comment: "Avoidance relapse button"))
                }
                .font(.subheadline.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.orange)
                .foregroundStyle(.white)
                .cornerRadius(16)
            }
            .buttonStyle(.plain)

        case .levels:
            // Handled by levelQuickLogButton, this is a fallback
            EmptyView()
        }
    }

    // MARK: - Actions

    private func openAwarenessSheet() {
        // Open appropriate sheet based on tracker name
        switch tracker.name {
        case "Mood":
            showingMoodSheet = true
        case "Feelings":
            showingFeelingsSheet = true
        case "Gratitude":
            showingGratitudeSheet = true
        default:
            // Generic awareness tracker - just quickLog
            quickLog()
        }
    }

    private func quickLog() {
        _ = manager.quickLog(for: tracker, in: modelContext)
    }

    private func incrementCounter() {
        _ = manager.logEntry(for: tracker, value: 1, in: modelContext)
    }

    private func decrementCounter() {
        // For counter, we need to adjust. Get today's total and decrement.
        let todayLogs = manager.todayLogs(for: tracker, in: modelContext)
        if let lastLog = todayLogs.last {
            modelContext.delete(lastLog)
        }
    }
}

#if DEBUG
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Tracker.self, TrackerLog.self, configurations: config)

    let tracker = Tracker(
        name: "Water",
        icon: "💧",
        type: .good,
        trackingMode: .counter,
        dailyGoal: 8
    )
    container.mainContext.insert(tracker)

    return TrackerRow(tracker: tracker, onEdit: {})
        .modelContainer(container)
        .padding()
}
#endif

#endif // os(iOS)
