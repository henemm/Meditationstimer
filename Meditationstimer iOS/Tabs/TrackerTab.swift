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

    // SwiftData Query for active trackers (excludes NoAlc which is shown separately)
    @Query(filter: #Predicate<Tracker> { $0.isActive && $0.name != "NoAlc" }, sort: \Tracker.createdAt)
    private var customTrackers: [Tracker]

    // NoAlc tracker query (separate for special handling)
    @Query(filter: #Predicate<Tracker> { $0.name == "NoAlc" })
    private var noAlcTrackers: [Tracker]

    /// The NoAlc tracker from SwiftData (created on first access if missing)
    private var noAlcTracker: Tracker? {
        noAlcTrackers.first
    }

    // Sheet states
    @State private var showingNoAlcLog = false
    @State private var showingAddTracker = false
    @State private var trackerToEdit: Tracker?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Unified Trackers Section (NoAlc + Custom Trackers)
                    trackersSection

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
                TrackerEditorSheet(tracker: tracker)
            }
        }
    }

    private func noAlcButton(_ level: TrackerLevel, color: Color) -> some View {
        Button(action: {
            Task {
                // Log to SwiftData via Generic Tracker System
                if let tracker = noAlcTracker {
                    tracker.logLevel(level, context: modelContext)
                    try? modelContext.save()
                }

                // Also log to HealthKit (preserves existing behavior)
                do {
                    // Map TrackerLevel to legacy ConsumptionLevel
                    let legacyLevel: NoAlcManager.ConsumptionLevel
                    switch level.key {
                    case "steady": legacyLevel = .steady
                    case "easy": legacyLevel = .easy
                    case "wild": legacyLevel = .wild
                    default: legacyLevel = .steady
                    }
                    try await NoAlcManager.shared.logConsumption(legacyLevel, for: Date())
                } catch {
                    print("[NoAlc] HealthKit log failed: \(error)")
                }
            }
        }) {
            Text(NSLocalizedString(level.labelKey, comment: "NoAlc level"))
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color.opacity(0.2))
                .foregroundStyle(color)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Trackers Section

    private var trackersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("Trackers", comment: "Trackers section header"))
                .font(.title3)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            // NoAlc as built-in tracker (always first)
            noAlcCard

            // Custom Trackers
            ForEach(customTrackers) { tracker in
                TrackerRow(tracker: tracker) {
                    trackerToEdit = tracker
                }
            }
        }
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
                    Spacer()
                    // Info button for detailed view
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
