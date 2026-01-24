//
//  CustomTrackerSheet.swift
//  Meditationstimer iOS
//
//  Created by Claude on 19.12.2025.
//  Updated: 26.12.2025 - Level Editor für volle Konfiguration
//
//  Sheet for creating a custom tracker with user-defined settings.
//

import SwiftUI
import SwiftData

#if os(iOS)

// MARK: - Editable Level (UI State)

/// Mutable level struct for the editor UI
struct EditableLevel: Identifiable, Equatable {
    let id = UUID()
    var icon: String
    var name: String
    var streakEffect: StreakEffect

    static func == (lhs: EditableLevel, rhs: EditableLevel) -> Bool {
        lhs.id == rhs.id && lhs.icon == rhs.icon && lhs.name == rhs.name && lhs.streakEffect == rhs.streakEffect
    }

    /// Default level for new entries
    static func makeDefault(index: Int) -> EditableLevel {
        let defaults = [
            ("✅", "Level 1", StreakEffect.success),
            ("⚡", "Level 2", StreakEffect.needsGrace),
            ("💥", "Level 3", StreakEffect.breaksStreak)
        ]
        let safeIndex = min(index, defaults.count - 1)
        return EditableLevel(
            icon: defaults[safeIndex].0,
            name: defaults[safeIndex].1,
            streakEffect: defaults[safeIndex].2
        )
    }
}

struct CustomTrackerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Form state
    @State private var icon = "✨"
    @State private var name = ""
    @State private var trackerType: TrackerType = .good
    @State private var trackingMode: TrackingMode = .counter
    @State private var dailyGoal: Int = 0

    // Level Editor State
    @State private var levels: [EditableLevel] = [
        EditableLevel.makeDefault(index: 0),
        EditableLevel.makeDefault(index: 1)
    ]
    @State private var enableJokerSystem = false
    @State private var jokerEarnEveryDays = 7
    @State private var jokerMaxOnHand = 3
    @State private var useCutoffHour = false
    @State private var cutoffHour = 18

    // Emoji choices for icon selection
    private let emojiChoices = [
        "😊", "💭", "🙏", "💧", "📱", "🍫", "🛋️", "🌀", "📵",
        "✨", "🔥", "💪", "🌿", "🧘", "☕", "🍎", "📚", "🎯",
        "💤", "🚶", "🏃", "🧠", "❤️", "🌟"
    ]

    // Level icon choices
    private let levelIconChoices = [
        "✅", "💧", "⚡", "💥", "🔥", "⭐", "🌟", "💎",
        "🍀", "🎯", "💪", "❤️", "⚠️", "🚨", "❌"
    ]

    // Available modes depend on tracker type
    private var availableModes: [TrackingMode] {
        switch trackerType {
        case .good:
            return [.counter, .yesNo, .levels]
        case .saboteur:
            return [.awareness, .avoidance, .levels]
        }
    }

    // Validation
    private var canCreate: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if trackingMode == .levels {
            // Levels mode needs valid levels
            let validLevelCount = levels.count >= 2 && levels.count <= 5
            let allLevelsNamed = levels.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let hasSuccessLevel = levels.contains { $0.streakEffect == .success }
            return hasName && validLevelCount && allLevelsNamed && hasSuccessLevel
        }

        return hasName
    }

    var body: some View {
        NavigationStack {
            Form {
                // Icon Section
                Section {
                    iconSelectionGrid
                } header: {
                    Text(NSLocalizedString("Icon", comment: "Icon section header"))
                }

                // Name Section
                Section {
                    TextField(
                        NSLocalizedString("Tracker name", comment: "Tracker name placeholder"),
                        text: $name
                    )
                } header: {
                    Text(NSLocalizedString("Name", comment: "Name section header"))
                }

                // Type Section
                Section {
                    Picker(NSLocalizedString("Type", comment: "Tracker type picker"), selection: $trackerType) {
                        Text(NSLocalizedString("Good Habit", comment: "Good tracker type"))
                            .tag(TrackerType.good)
                        Text(NSLocalizedString("Saboteur", comment: "Saboteur tracker type"))
                            .tag(TrackerType.saboteur)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text(NSLocalizedString("Type", comment: "Type section header"))
                } footer: {
                    Text(typeFooter)
                }

                // Mode Section
                Section {
                    Picker(NSLocalizedString("Mode", comment: "Tracking mode picker"), selection: $trackingMode) {
                        ForEach(availableModes, id: \.self) { mode in
                            Text(modeLabel(for: mode))
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text(NSLocalizedString("Mode", comment: "Mode section header"))
                } footer: {
                    Text(modeFooter)
                }

                // Daily Goal Section (only for counter mode)
                if trackingMode == .counter {
                    Section {
                        Stepper(value: $dailyGoal, in: 0...100) {
                            HStack {
                                Text(NSLocalizedString("Daily Goal", comment: "Daily goal label"))
                                Spacer()
                                Text("\(dailyGoal)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("Goal", comment: "Goal section header"))
                    } footer: {
                        Text(NSLocalizedString("Set to 0 to disable goal tracking.", comment: "Goal footer"))
                    }
                }

                // MARK: - Level Editor Sections (only for levels mode)
                if trackingMode == .levels {
                    // Levels Section
                    Section {
                        ForEach($levels) { $level in
                            LevelEditorRow(
                                level: $level,
                                iconChoices: levelIconChoices,
                                canDelete: levels.count > 2,
                                onDelete: { deleteLevel(level) }
                            )
                        }

                        if levels.count < 5 {
                            Button {
                                addLevel()
                            } label: {
                                Label(
                                    NSLocalizedString("Add Level", comment: "Add level button"),
                                    systemImage: "plus.circle.fill"
                                )
                            }
                        }
                    } header: {
                        HStack {
                            Text(NSLocalizedString("Levels", comment: "Levels section header"))
                            Spacer()
                            Text("\(levels.count)/5")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } footer: {
                        if !levels.contains(where: { $0.streakEffect == .success }) {
                            Text(NSLocalizedString("⚠️ At least one level must be \"Success\" for streaks to work.", comment: "Missing success level warning"))
                                .foregroundStyle(.orange)
                        } else {
                            Text(NSLocalizedString("Define 2-5 levels with different streak effects.", comment: "Levels explanation"))
                        }
                    }

                    // Joker System Section
                    Section {
                        Toggle(isOn: $enableJokerSystem) {
                            Text(NSLocalizedString("Enable Joker System", comment: "Joker system toggle"))
                        }

                        if enableJokerSystem {
                            Stepper(value: $jokerEarnEveryDays, in: 1...30) {
                                HStack {
                                    Text(NSLocalizedString("Earn every", comment: "Joker earn label"))
                                    Spacer()
                                    Text(String(format: NSLocalizedString("%d days", comment: "Days count"), jokerEarnEveryDays))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Stepper(value: $jokerMaxOnHand, in: 1...10) {
                                HStack {
                                    Text(NSLocalizedString("Max on hand", comment: "Joker max label"))
                                    Spacer()
                                    Text("\(jokerMaxOnHand)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("Joker System", comment: "Joker section header"))
                    } footer: {
                        Text(NSLocalizedString("Jokers can heal \"Needs Joker\" days to continue streaks.", comment: "Joker explanation"))
                    }

                    // Day Boundary Section
                    Section {
                        Picker(selection: $useCutoffHour) {
                            Text(NSLocalizedString("Midnight (00:00)", comment: "Midnight option"))
                                .tag(false)
                            Text(NSLocalizedString("Custom hour", comment: "Custom hour option"))
                                .tag(true)
                        } label: {
                            Text(NSLocalizedString("Day changes at", comment: "Day boundary label"))
                        }
                        .pickerStyle(.menu)

                        if useCutoffHour {
                            Stepper(value: $cutoffHour, in: 0...23) {
                                HStack {
                                    Text(NSLocalizedString("Cutoff hour", comment: "Cutoff hour label"))
                                    Spacer()
                                    Text(String(format: "%02d:00", cutoffHour))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("Day Boundary", comment: "Day boundary section header"))
                    } footer: {
                        Text(NSLocalizedString("Logs before this hour count for the previous day.", comment: "Day boundary explanation"))
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Custom Tracker", comment: "Custom tracker sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "Cancel button")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Create", comment: "Create button")) {
                        createTracker()
                    }
                    .disabled(!canCreate)
                }
            }
            .onChange(of: trackerType) { _, newType in
                // Reset mode to first available when type changes
                trackingMode = availableModes.first ?? .counter
            }
        }
    }

    // MARK: - Icon Selection Grid

    private var iconSelectionGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
            ForEach(emojiChoices, id: \.self) { emoji in
                Button {
                    icon = emoji
                } label: {
                    Text(emoji)
                        .font(.system(size: 28))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(icon == emoji ? Color.blue.opacity(0.2) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(icon == emoji ? Color.blue : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helper Labels

    private var typeFooter: String {
        switch trackerType {
        case .good:
            return NSLocalizedString("Track positive habits you want to build.", comment: "Good type explanation")
        case .saboteur:
            return NSLocalizedString("Track behaviors you want to become aware of or avoid.", comment: "Saboteur type explanation")
        }
    }

    private func modeLabel(for mode: TrackingMode) -> String {
        switch mode {
        case .counter:
            return NSLocalizedString("Counter", comment: "Counter mode")
        case .yesNo:
            return NSLocalizedString("Daily Check", comment: "YesNo mode")
        case .awareness:
            return NSLocalizedString("Awareness", comment: "Awareness mode")
        case .avoidance:
            return NSLocalizedString("Avoidance", comment: "Avoidance mode")
        case .levels:
            return NSLocalizedString("Levels", comment: "Levels mode")
        }
    }

    private var modeFooter: String {
        switch trackingMode {
        case .counter:
            return NSLocalizedString("Count how many times per day (e.g., glasses of water).", comment: "Counter mode explanation")
        case .yesNo:
            return NSLocalizedString("Simple daily yes/no check.", comment: "YesNo mode explanation")
        case .awareness:
            return NSLocalizedString("Log each occurrence to build awareness.", comment: "Awareness mode explanation")
        case .avoidance:
            return NSLocalizedString("Track days without the behavior (streak).", comment: "Avoidance mode explanation")
        case .levels:
            return NSLocalizedString("Custom levels with joker system (e.g., NoAlc, Energy).", comment: "Levels mode explanation")
        }
    }

    // MARK: - Actions

    private func createTracker() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        let tracker = Tracker(
            name: trimmedName,
            icon: icon,
            type: trackerType,
            trackingMode: trackingMode,
            dailyGoal: trackingMode == .counter && dailyGoal > 0 ? dailyGoal : nil
        )

        // Level-based tracker configuration
        if trackingMode == .levels {
            tracker.levels = levels.enumerated().map { index, editableLevel in
                TrackerLevel(
                    id: index,
                    key: editableLevel.name.lowercased().replacingOccurrences(of: " ", with: "_"),
                    icon: editableLevel.icon,
                    labelKey: editableLevel.name,
                    streakEffect: editableLevel.streakEffect
                )
            }

            if enableJokerSystem {
                tracker.rewardConfig = RewardConfig(
                    earnEveryDays: jokerEarnEveryDays,
                    maxOnHand: jokerMaxOnHand,
                    canHealGrace: true
                )
            }

            if useCutoffHour {
                tracker.dayAssignmentRaw = "cutoffHour:\(cutoffHour)"
            }
        }

        TrackerManager.shared.createTracker(tracker, in: modelContext)
        dismiss()
    }

    // MARK: - Level Management

    private func addLevel() {
        guard levels.count < 5 else { return }
        let newLevel = EditableLevel.makeDefault(index: levels.count)
        levels.append(newLevel)
    }

    private func deleteLevel(_ level: EditableLevel) {
        guard levels.count > 2 else { return }
        levels.removeAll { $0.id == level.id }
    }
}

// MARK: - Level Editor Row

struct LevelEditorRow: View {
    @Binding var level: EditableLevel
    let iconChoices: [String]
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon Picker
            Menu {
                ForEach(iconChoices, id: \.self) { emoji in
                    Button {
                        level.icon = emoji
                    } label: {
                        Text(emoji)
                    }
                }
            } label: {
                Text(level.icon)
                    .font(.system(size: 28))
                    .frame(width: 44, height: 44)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }

            // Name TextField
            TextField(
                NSLocalizedString("Level name", comment: "Level name placeholder"),
                text: $level.name
            )
            .textFieldStyle(.plain)

            Spacer()

            // StreakEffect Picker
            Picker("", selection: $level.streakEffect) {
                Text(NSLocalizedString("Success", comment: "Success streak effect"))
                    .tag(StreakEffect.success)
                Text(NSLocalizedString("Needs Joker", comment: "Needs joker streak effect"))
                    .tag(StreakEffect.needsGrace)
                Text(NSLocalizedString("Breaks", comment: "Breaks streak effect"))
                    .tag(StreakEffect.breaksStreak)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 100)

            // Delete Button
            if canDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview {
    CustomTrackerSheet()
        .modelContainer(for: [Tracker.self, TrackerLog.self], inMemory: true)
}
#endif

#endif // os(iOS)
