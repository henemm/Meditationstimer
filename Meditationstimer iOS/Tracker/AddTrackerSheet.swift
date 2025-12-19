//
//  AddTrackerSheet.swift
//  Meditationstimer iOS
//
//  Created by Claude on 19.12.2025.
//
//  Sheet for adding a new tracker from predefined presets.
//

import SwiftUI
import SwiftData

#if os(iOS)

struct AddTrackerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let manager = TrackerManager.shared

    var body: some View {
        NavigationStack {
            List {
                // Awareness Section
                Section {
                    ForEach(TrackerManager.presets(for: .awareness)) { preset in
                        PresetRow(preset: preset) {
                            createTracker(from: preset)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("Awareness", comment: "Preset category"))
                } footer: {
                    Text(NSLocalizedString("The act of logging is the mindfulness exercise.", comment: "Awareness explanation"))
                }

                // Activity Section
                Section {
                    ForEach(TrackerManager.presets(for: .activity)) { preset in
                        PresetRow(preset: preset) {
                            createTracker(from: preset)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("Activity", comment: "Preset category"))
                }

                // Saboteur Section
                Section {
                    ForEach(TrackerManager.presets(for: .saboteur)) { preset in
                        PresetRow(preset: preset) {
                            createTracker(from: preset)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("Saboteur", comment: "Preset category"))
                } footer: {
                    Text(NSLocalizedString("Track autopilot behaviors to build awareness.", comment: "Saboteur explanation"))
                }

                // Custom Tracker Section (Phase 2.5)
                Section {
                    Label {
                        Text(NSLocalizedString("Custom Tracker", comment: "Custom tracker option"))
                    } icon: {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.secondary)
                } footer: {
                    Text(NSLocalizedString("Coming soon", comment: "Feature coming soon"))
                }
            }
            .navigationTitle(NSLocalizedString("Add Tracker", comment: "Sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "Cancel button")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func createTracker(from preset: TrackerPreset) {
        _ = manager.createFromPreset(preset, in: modelContext)
        dismiss()
    }
}

// MARK: - Preset Row

struct PresetRow: View {
    let preset: TrackerPreset
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Text(preset.icon)
                    .font(.system(size: 32))

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.localizedName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(modeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var modeDescription: String {
        switch preset.trackingMode {
        case .counter:
            if let goal = preset.dailyGoal {
                return String(format: NSLocalizedString("Counter (Goal: %d)", comment: "Counter with goal"), goal)
            }
            return NSLocalizedString("Counter", comment: "Counter mode")
        case .yesNo:
            return NSLocalizedString("Daily check", comment: "YesNo mode")
        case .awareness:
            return NSLocalizedString("Awareness logging", comment: "Awareness mode")
        case .avoidance:
            return NSLocalizedString("Avoidance streak", comment: "Avoidance mode")
        }
    }
}

#if DEBUG
#Preview {
    AddTrackerSheet()
        .modelContainer(for: [Tracker.self, TrackerLog.self], inMemory: true)
}
#endif

#endif // os(iOS)
