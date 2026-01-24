//
//  LevelSelectionView.swift
//  Lean Health Timer
//
//  Created by Claude on 25.12.2025.
//
//  Generic level selection sheet for level-based trackers.
//  Design based on NoAlcLogSheet but works with any TrackerLevel configuration.
//

import SwiftUI
import SwiftData

#if os(iOS)

struct LevelSelectionView: View {
    let tracker: Tracker
    var onSave: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isExpanded: Bool

    // BUG 2b FIX: Init that allows starting with DatePicker visible
    init(tracker: Tracker, onSave: @escaping () -> Void = {}, initiallyExpanded: Bool = false) {
        self.tracker = tracker
        self.onSave = onSave
        self._isExpanded = State(initialValue: initiallyExpanded)
    }
    @State private var selectedDate = Date()
    @State private var isLogging = false
    @State private var errorMessage: String?

    private let manager = TrackerManager.shared

    /// The levels to display (from tracker config)
    private var levels: [TrackerLevel] {
        tracker.levels ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isExpanded {
                compactModeView
            } else {
                extendedModeView
            }
        }
        .padding(.top, 20)
        .presentationDetents(isExpanded ? [.large] : [.height(compactHeight)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Compact Mode (Quick-Log)

    private var compactModeView: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(tracker.icon)
                        .font(.title2)
                    Text(tracker.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Text(titleText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(subtitleText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 32)

            // Level Buttons (dynamic 2-5)
            levelButtonsRow
                .padding(.horizontal, 16)

            // Advanced Button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded = true
                }
            } label: {
                Text(NSLocalizedString("Advanced", comment: "Expand to date picker"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 16)

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Extended Mode (DatePicker)

    private var extendedModeView: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header with Icon
                VStack(spacing: 8) {
                    Text(tracker.icon)
                        .font(.system(size: 48))
                    Text(NSLocalizedString("Choose Date", comment: "Date picker title"))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .padding(.top, 20)

                // Date Picker
                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)

                // Level Buttons
                VStack(spacing: 12) {
                    Text(NSLocalizedString("Select level", comment: "Level selection prompt"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    levelButtonsRow
                }
                .padding(.horizontal)

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle(tracker.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()  // BUG 2b FIX: Close sheet, don't switch to compact
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Level Buttons Row

    private var levelButtonsRow: some View {
        HStack(spacing: 12) {
            ForEach(levels) { level in
                LevelButton(
                    level: level,
                    isLogging: isLogging,
                    action: { await logLevel(level, dismissImmediately: !isExpanded) }
                )
            }
        }
    }

    // MARK: - Computed Properties

    private var titleText: String {
        NSLocalizedString("Today", comment: "Level selection title")
    }

    private var subtitleText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }

    /// Calculate compact sheet height based on number of levels
    private var compactHeight: CGFloat {
        // Base height + adjustment for level count
        let baseHeight: CGFloat = 200
        let levelCount = levels.count
        // More levels need more width, so we keep same height
        return baseHeight + (levelCount > 3 ? 40 : 0)
    }

    // MARK: - Actions

    @MainActor
    private func logLevel(_ level: TrackerLevel, dismissImmediately: Bool) async {
        isLogging = true
        errorMessage = nil

        // Use selected date if expanded, otherwise today
        let dateToLog = isExpanded ? selectedDate : Date()

        // Log entry with level ID as value
        _ = manager.logEntry(
            for: tracker,
            value: level.id,
            note: "\(level.icon) \(level.localizedLabel)",
            in: modelContext
        )

        onSave()

        // Dismiss
        if dismissImmediately {
            dismiss()
        } else {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
            dismiss()
        }
    }
}

// MARK: - Level Button Component

struct LevelButton: View {
    let level: TrackerLevel
    let isLogging: Bool
    let action: () async -> Void

    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            VStack(spacing: 8) {
                Text(level.icon)
                    .font(.system(size: 32))
                Text(level.localizedLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
        .disabled(isLogging)
        .scaleEffect(isLogging ? 0.95 : 1.0)
        .animation(.spring(response: 0.3), value: isLogging)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Tracker.self, TrackerLog.self, configurations: config)

    // Create a level-based tracker for preview
    let tracker = Tracker(
        name: "Energy",
        icon: "⚡",
        type: .good,
        trackingMode: .yesNo // Legacy, but we'll set levels
    )
    // Set levels manually for preview
    tracker.levels = TrackerLevel.energyLevels
    container.mainContext.insert(tracker)

    return LevelSelectionView(tracker: tracker)
        .modelContainer(container)
}
#endif

#endif // os(iOS)
