//
//  TrackerHistorySheet.swift
//  Lean Health Timer
//
//  Created by Claude on 18.01.2026.
//
//  Shows history of tracker logs grouped by date.
//  Displays the last 30 days of entries for a given tracker.
//

import SwiftUI
import SwiftData

#if os(iOS)

struct TrackerHistorySheet: View {
    let tracker: Tracker

    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.current

    /// Logs from the last 30 days, grouped by date
    private var groupedLogs: [(date: Date, logs: [TrackerLog])] {
        let today = calendar.startOfDay(for: Date())
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) ?? today

        // Filter logs from last 30 days
        let recentLogs = tracker.logs.filter { log in
            log.timestamp >= thirtyDaysAgo
        }

        // Group by date using effectiveDayAssignment
        var grouped: [Date: [TrackerLog]] = [:]
        for log in recentLogs {
            let assignedDay = tracker.effectiveDayAssignment.assignedDay(for: log.timestamp, calendar: calendar)
            grouped[assignedDay, default: []].append(log)
        }

        // Sort by date (newest first) and sort logs within each day by timestamp
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, logs: $0.value.sorted { $0.timestamp > $1.timestamp }) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if groupedLogs.isEmpty {
                    emptyStateView
                } else {
                    logsList
                }
            }
            .navigationTitle(NSLocalizedString("History", comment: "History sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("Done", comment: "Done button")) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(NSLocalizedString("No entries yet", comment: "Empty history message"))
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(NSLocalizedString("Your logged entries will appear here", comment: "Empty history hint"))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Logs List

    private var logsList: some View {
        List {
            ForEach(groupedLogs, id: \.date) { group in
                Section {
                    ForEach(group.logs) { log in
                        logRow(log)
                    }
                } header: {
                    Text(formattedDate(group.date))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Log Row

    private func logRow(_ log: TrackerLog) -> some View {
        HStack(spacing: 12) {
            // Level icon and label (if level-based tracker)
            if let levelId = log.value,
               let levels = tracker.levels,
               let level = levels.first(where: { $0.id == levelId }) {
                Text(level.icon)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.localizedLabel)
                        .font(.body)
                        .fontWeight(.medium)

                    Text(formattedTime(log.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                // Fallback for non-level trackers
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    if let value = log.value {
                        Text("\(value)")
                            .font(.body)
                            .fontWeight(.medium)
                    } else {
                        Text(NSLocalizedString("Logged", comment: "Generic log label"))
                            .font(.body)
                    }

                    Text(formattedTime(log.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Note indicator (if exists)
            if let note = log.note, !note.isEmpty {
                Image(systemName: "note.text")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Formatting

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#if DEBUG
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Tracker.self, TrackerLog.self, configurations: config)

    // Create test tracker with logs
    let tracker = Tracker(
        name: "NoAlc",
        icon: "🍷",
        type: .saboteur,
        trackingMode: .levels
    )
    tracker.levels = TrackerLevel.noAlcLevels

    // Add some test logs
    let log1 = TrackerLog(timestamp: Date(), value: 0)
    let log2 = TrackerLog(timestamp: Date().addingTimeInterval(-86400), value: 1)
    let log3 = TrackerLog(timestamp: Date().addingTimeInterval(-172800), value: 2)
    tracker.logs = [log1, log2, log3]

    container.mainContext.insert(tracker)

    return TrackerHistorySheet(tracker: tracker)
        .modelContainer(container)
}
#endif

#endif // os(iOS)
