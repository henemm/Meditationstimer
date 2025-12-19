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

    // SwiftData Query for active trackers
    @Query(filter: #Predicate<Tracker> { $0.isActive }, sort: \Tracker.createdAt)
    private var trackers: [Tracker]

    // Sheet states
    @State private var showingNoAlcLog = false
    @State private var showingAddTracker = false
    @State private var trackerToEdit: Tracker?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // NoAlc Quick Log Section (built-in tracker)
                    noAlcSection

                    // Custom Trackers Section
                    if !trackers.isEmpty {
                        trackersSection
                    }

                    // Add Tracker Card
                    addTrackerCard
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingNoAlcLog) {
                NoAlcLogSheet()
            }
            .sheet(isPresented: $showingAddTracker) {
                AddTrackerSheet()
            }
            .sheet(item: $trackerToEdit) { tracker in
                // Phase 2.3: TrackerEditorSheet
                Text("Edit: \(tracker.name)")
            }
        }
    }

    // MARK: - NoAlc Section

    private var noAlcSection: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Text("NoAlc")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                }
                .padding(.horizontal, 4)

                Button(action: { showingNoAlcLog = true }) {
                    HStack {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 24))
                        Text(NSLocalizedString("Log Today", comment: "NoAlc log button"))
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
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

            ForEach(trackers) { tracker in
                TrackerRow(tracker: tracker) {
                    trackerToEdit = tracker
                }
            }
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
