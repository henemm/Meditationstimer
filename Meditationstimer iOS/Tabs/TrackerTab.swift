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

    // SwiftData Query for ALL active trackers
    // FEAT-tracker-drag-drop: Sort by displayOrder for user-defined ordering
    @Query(filter: #Predicate<Tracker> { $0.isActive }, sort: \Tracker.displayOrder)
    private var allTrackers: [Tracker]

    // Edit mode for drag & drop reordering
    @State private var editMode: EditMode = .inactive

    // Sheet states
    @State private var showingAddTracker = false
    @State private var trackerToEdit: Tracker?

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
                // FEAT-tracker-drag-drop: EditButton for reordering (only with >1 trackers)
                ToolbarItem(placement: .topBarTrailing) {
                    if allTrackers.count > 1 {
                        EditButton()
                            .environment(\.editMode, $editMode)
                    }
                }
            }
            .sheet(isPresented: $showingAddTracker) {
                AddTrackerSheet()
            }
            .sheet(item: $trackerToEdit) { tracker in
                TrackerEditorSheet(tracker: tracker)
            }
        }
    }

    // MARK: - Trackers Section

    private var trackersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("Trackers", comment: "Trackers section header"))
                .font(.title3)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            // All Trackers (including NoAlc) - sortable via drag & drop
            if !allTrackers.isEmpty {
                List {
                    ForEach(allTrackers) { tracker in
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
                // Calculate height based on tracker types
                // Level-based trackers (3 rows: header, buttons, status) need ~200pt
                // Counter trackers (1 row) need ~130pt
                .frame(height: calculateListHeight())
            }
        }
    }

    // MARK: - List Height Calculation

    /// Calculate the total height needed for the trackers list
    /// Level-based trackers need more height (3 rows) than counter trackers (1 row)
    private func calculateListHeight() -> CGFloat {
        var totalHeight: CGFloat = 0
        for tracker in allTrackers {
            // Check if tracker is level-based (has levels array)
            if tracker.levels != nil && !(tracker.levels?.isEmpty ?? true) {
                // Level-based: header + buttons + status + GlassCard padding + list row insets
                totalHeight += 200
            } else {
                // Counter: single row + GlassCard padding + list row insets
                totalHeight += 130
            }
        }
        return totalHeight
    }

    // MARK: - Drag & Drop Handler

    private func moveTrackers(from source: IndexSet, to destination: Int) {
        // Create mutable copy of current order
        var trackers = Array(allTrackers)

        // Perform the move
        trackers.move(fromOffsets: source, toOffset: destination)

        // Update displayOrder for all trackers
        for (index, tracker) in trackers.enumerated() {
            tracker.displayOrder = index
        }

        // Persist changes
        try? modelContext.save()
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
