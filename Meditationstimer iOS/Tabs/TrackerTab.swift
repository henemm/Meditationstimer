//
//  TrackerTab.swift
//  Meditationstimer iOS
//
//  Created by Claude Code on 15.12.2025.
//  Updated: 19.12.2025 - Phase 2.1 + 2.2 TrackerTab UI
//
//  Main tab for custom trackers including NoAlc and user-defined trackers.
//

import SwiftUI
import SwiftData

#if os(iOS)

struct TrackerTab: View {
    @EnvironmentObject var streakManager: StreakManager
    @Environment(\.modelContext) private var modelContext

    // SwiftData Query for ALL active trackers (including NoAlc for parallel operation)
    // FEAT-tracker-drag-drop: Sort by displayOrder for user-defined ordering
    @Query(filter: #Predicate<Tracker> { $0.isActive }, sort: \Tracker.displayOrder)
    private var allTrackers: [Tracker]

    // Edit mode for drag & drop reordering
    @State private var editMode: EditMode = .inactive

    // NoAlc tracker query (separate for special handling of the FIRST/original NoAlc)
    @Query(filter: #Predicate<Tracker> { $0.name == "NoAlc" })
    private var noAlcTrackers: [Tracker]

    /// The FIRST NoAlc tracker (shown in dedicated noAlcCard)
    private var noAlcTracker: Tracker? {
        noAlcTrackers.first
    }

    /// Custom trackers = all trackers EXCEPT the first NoAlc (which has its own card)
    /// This allows parallel operation: first NoAlc in noAlcCard, additional NoAlcs in list
    private var customTrackers: [Tracker] {
        let firstNoAlcId = noAlcTracker?.id
        return allTrackers.filter { tracker in
            // Exclude the FIRST NoAlc (it has its own card)
            // But include any ADDITIONAL NoAlc trackers created via preset
            if tracker.name == "NoAlc" && tracker.id == firstNoAlcId {
                return false
            }
            return true
        }
    }

    // Sheet states
    @State private var showingNoAlcLog = false
    @State private var showingAddTracker = false
    @State private var trackerToEdit: Tracker?
    @State private var showingNoAlcHistory = false  // FEAT-39 C1

    // NoAlc feedback state
    @State private var loggedLevel: TrackerLevel? = nil

    // HealthKit data for NoAlc streak calculation (per spec: HealthKit is source of truth)
    @State private var alcoholDays: [Date: TrackerLevel] = [:]
    private let calendar = Calendar.current

    // MARK: - Computed Properties

    /// Calculate NoAlc streak using HealthKit data (NOT SwiftData logs!)
    /// Per spec: "Same HealthKit query for calendar display AND streak calculation"
    private var noAlcStreakResult: StreakResult {
        TrackerManager.calculateNoAlcStreakFromHealthKit(alcoholDays: alcoholDays, calendar: calendar)
    }

    var body: some View {
        NavigationStack {
            // BUG 1 FIX: Explicit .vertical axis prevents horizontal wobble
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Unified Trackers Section (NoAlc + Custom Trackers)
                    trackersSection

                    // Add Tracker Card
                    addTrackerCard
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // FEAT-tracker-drag-drop: EditButton for reordering (only with >1 custom trackers)
                ToolbarItem(placement: .topBarTrailing) {
                    if customTrackers.count > 1 {
                        EditButton()
                            .environment(\.editMode, $editMode)
                    }
                }
            }
            .sheet(isPresented: $showingNoAlcLog) {
                // CRITICAL: NoAlcLogSheet provides LOG functionality with:
                // - Quick log buttons (Steady, Easy, Wild)
                // - "Advanced" button for date picker (18:00 cutoff rule)
                // TrackerHistorySheet is read-only and should NOT be used here!
                NoAlcLogSheet()
            }
            .sheet(isPresented: $showingNoAlcHistory) {
                // FEAT-39 C1: History view for NoAlc tracker
                if let tracker = noAlcTracker {
                    TrackerHistorySheet(tracker: tracker)
                }
            }
            .sheet(isPresented: $showingAddTracker) {
                AddTrackerSheet()
            }
            .sheet(item: $trackerToEdit) { tracker in
                TrackerEditorSheet(tracker: tracker)
            }
            .task {
                await loadNoAlcData()
            }
        }
    }

    /// Load NoAlc data from HealthKit for streak calculation
    /// Per spec: "HealthKit is source of truth for NoAlc"
    private func loadNoAlcData() async {
        var loadedDays: [Date: TrackerLevel] = [:]

        // Load last 90 days of NoAlc data from HealthKit
        for dayOffset in 0..<90 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let dayStart = calendar.startOfDay(for: date)

            if let level = await TrackerManager.shared.fetchNoAlcLevelFromHealthKit(for: dayStart) {
                loadedDays[dayStart] = level
            }
        }

        await MainActor.run {
            self.alcoholDays = loadedDays
        }
    }

    private func noAlcButton(_ level: TrackerLevel, color: Color) -> some View {
        Button(action: {
            Task {
                // FEAT-37d: Log via TrackerManager (handles SwiftData + HealthKit + Reminders)
                if let tracker = noAlcTracker {
                    _ = TrackerManager.shared.logEntry(
                        for: tracker,
                        value: level.id,
                        in: modelContext
                    )
                    try? modelContext.save()

                    // Also cancel old-style NoAlc reminders (backwards compatibility)
                    // Needed because legacy reminders use activityType = .noalc instead of trackerID
                    SmartReminderEngine.shared.cancelMatchingReminders(
                        for: .noalc,
                        completedAt: Date()
                    )

                    // Reload HealthKit data to update streak display
                    await loadNoAlcData()
                }

                // Show feedback animation
                await MainActor.run {
                    withAnimation(.spring(duration: 0.3)) {
                        loggedLevel = level
                    }
                }

                // Reset feedback after 1.5 seconds
                try? await Task.sleep(for: .seconds(1.5))
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        loggedLevel = nil
                    }
                }
            }
        }) {
            // FIX 1: Show EMOJI instead of text label
            Text(level.icon)
                .font(.system(size: 32))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color.opacity(0.2))
                .cornerRadius(10)
                // FIX 2: Checkmark overlay when this level was just logged
                .overlay {
                    if loggedLevel?.id == level.id {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.green)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: loggedLevel?.id == level.id)
        .accessibilityLabel(level.localizedLabel)
        .accessibilityIdentifier("legacy_\(level.icon)")
    }

    // MARK: - Trackers Section

    private var trackersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("Trackers", comment: "Trackers section header"))
                .font(.title3)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            // NoAlc as built-in tracker (always first, NOT sortable)
            noAlcCard

            // Custom Trackers (sortable via drag & drop)
            if !customTrackers.isEmpty {
                List {
                    ForEach(customTrackers) { tracker in
                        TrackerRow(tracker: tracker) {
                            trackerToEdit = tracker
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    }
                    .onMove(perform: moveTrackers)
                }
                .listStyle(.plain)
                .environment(\.editMode, $editMode)
                .scrollDisabled(true)
                // FIX: Calculate height based on tracker types
                // Level-based trackers (3 rows: header, buttons, status) need ~180pt
                // Legacy trackers (1 row) need ~100pt
                .frame(height: calculateListHeight())
            }
        }
    }

    // MARK: - List Height Calculation

    /// Calculate the total height needed for the custom trackers list
    /// Level-based trackers need more height (3 rows) than legacy trackers (1 row)
    private func calculateListHeight() -> CGFloat {
        var totalHeight: CGFloat = 0
        for tracker in customTrackers {
            // Check if tracker is level-based (has levels array)
            if tracker.levels != nil && !(tracker.levels?.isEmpty ?? true) {
                // Level-based: header + buttons + status + GlassCard padding + list row insets
                totalHeight += 200
            } else {
                // Legacy: single row + GlassCard padding + list row insets
                totalHeight += 130
            }
        }
        return totalHeight
    }

    // MARK: - Drag & Drop Handler

    private func moveTrackers(from source: IndexSet, to destination: Int) {
        // Create mutable copy of current order
        var trackers = customTrackers

        // Perform the move
        trackers.move(fromOffsets: source, toOffset: destination)

        // Update displayOrder for all trackers
        for (index, tracker) in trackers.enumerated() {
            tracker.displayOrder = index
        }

        // Persist changes
        try? modelContext.save()
    }

    // MARK: - NoAlc Card (within Trackers section)

    private var noAlcCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    Text("🍷")
                        .font(.system(size: 28))
                    Text("NoAlc")
                        .font(.headline)

                    // FEAT-39 A1: Streak and Joker display
                    Spacer()

                    // Streak indicator (🔥)
                    HStack(spacing: 2) {
                        Text("🔥")
                        Text("\(noAlcStreakResult.currentStreak)")
                            .font(.subheadline.monospacedDigit())
                    }
                    .accessibilityIdentifier("noAlcStreak")

                    // Joker indicator (🃏) - only show if reward system is active
                    if noAlcTracker?.rewardConfig != nil {
                        HStack(spacing: 2) {
                            Text("🃏")
                            Text("\(noAlcStreakResult.availableRewards)/\(noAlcTracker?.rewardConfig?.maxOnHand ?? 3)")
                                .font(.subheadline.monospacedDigit())
                        }
                        .padding(.leading, 8)
                        .accessibilityIdentifier("noAlcJokers")
                    }

                    Spacer()

                    // FEAT-39 C1: History button
                    Button(action: { showingNoAlcHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("noAlcHistoryButton")

                    // Info button for detailed view (opens NoAlcLogSheet with Advanced mode)
                    Button(action: { showingNoAlcLog = true }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                }

                // Quick-Log Buttons (using TrackerLevel from Generic Tracker System)
                HStack(spacing: 10) {
                    noAlcButton(TrackerLevel.noAlcLevels[0], color: .green)  // Steady
                    noAlcButton(TrackerLevel.noAlcLevels[1], color: .yellow) // Easy
                    noAlcButton(TrackerLevel.noAlcLevels[2], color: .red)    // Wild
                }

                // FIX 3: Show today's logged level
                if let tracker = noAlcTracker,
                   let todayLog = tracker.todayLog,
                   let levelId = todayLog.value,
                   let level = TrackerLevel.noAlcLevels.first(where: { $0.id == levelId }) {
                    HStack(spacing: 4) {
                        Text(NSLocalizedString("Today:", comment: "Today's log prefix"))
                        Text(level.icon)
                        Text(level.localizedLabel)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Add Tracker Card

    private var addTrackerCard: some View {
        Button(action: { showingAddTracker = true }) {
            GlassCard {
                HStack {
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.blue)
                    Text(NSLocalizedString("Add Tracker", comment: "Add tracker button"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .frame(minHeight: 60)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("addTrackerButton")
    }
}

#if DEBUG
#Preview {
    TrackerTab()
        .environmentObject(StreakManager())
        .modelContainer(for: [Tracker.self, TrackerLog.self], inMemory: true)
}
#endif

#endif // os(iOS)
