//
//  TrackerEditorSheet.swift
//  Meditationstimer iOS
//
//  Created by Claude on 19.12.2025.
//  Updated: 19.01.2026 - Added Level Editor, Joker System, Day Boundary editing
//
//  Sheet for editing tracker properties and deleting trackers.
//

import SwiftUI
import SwiftData

#if os(iOS)

struct TrackerEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var tracker: Tracker

    @State private var showDeleteConfirmation = false

    // MARK: - Level Editor State (for .levels mode)
    @State private var editableLevels: [EditableLevel] = []
    @State private var enableJokerSystem = false
    @State private var jokerEarnEveryDays = 7
    @State private var jokerMaxOnHand = 3
    @State private var useCutoffHour = false
    @State private var cutoffHour = 18

    // Reminder state
    @State private var linkedReminders: [SmartReminder] = []

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

    // MARK: - Validation

    private var levelsAreValid: Bool {
        guard tracker.trackingMode == .levels else { return true }
        let validLevelCount = editableLevels.count >= 2 && editableLevels.count <= 5
        let allLevelsNamed = editableLevels.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let hasSuccessLevel = editableLevels.contains { $0.streakEffect == .success }
        return validLevelCount && allLevelsNamed && hasSuccessLevel
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            formContent
        }
    }

    private var formContent: some View {
        formWithModifiers
    }

    private var formWithModifiers: some View {
        formWithNavigation
            .onAppear(perform: onAppearHandler)
            .onChange(of: editableLevels) { _, _ in saveLevelsToTracker() }
            .onChange(of: enableJokerSystem) { _, _ in saveJokerConfigToTracker() }
            .onChange(of: jokerEarnEveryDays) { _, _ in saveJokerConfigToTracker() }
            .onChange(of: jokerMaxOnHand) { _, _ in saveJokerConfigToTracker() }
            .onChange(of: useCutoffHour) { _, _ in saveDayBoundaryToTracker() }
            .onChange(of: cutoffHour) { _, _ in saveDayBoundaryToTracker() }
    }

    private var formWithNavigation: some View {
        formBody
            .navigationTitle(NSLocalizedString("Edit Tracker", comment: "Edit sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .confirmationDialog(
                NSLocalizedString("Delete Tracker?", comment: "Delete confirmation title"),
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                deleteConfirmationButtons
            } message: {
                Text(NSLocalizedString("This action cannot be undone. All logs will be deleted.", comment: "Delete confirmation message"))
            }
    }

    private var formBody: some View {
        Form {
            Group {
                basicSettingsSection
            }
            Group {
                levelEditorSections
            }
            Group {
                integrationSection  // FEAT-39 D1/D2
                reminderSection
                infoSection
                deleteSection
            }
        }
    }

    // MARK: - Integration Section (FEAT-39 D1/D2)

    private var integrationSection: some View {
        Section {
            // D1: HealthKit Toggle (only show if tracker has HealthKit type)
            if tracker.healthKitType != nil {
                Toggle(isOn: $tracker.saveToHealthKit) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        Text(NSLocalizedString("Sync to Health", comment: "HealthKit sync toggle"))
                    }
                }
                .accessibilityIdentifier("saveToHealthKitToggle")
            }

            // D2: Widget Toggle
            Toggle(isOn: $tracker.showInWidget) {
                HStack {
                    Image(systemName: "rectangle.3.group")
                        .foregroundStyle(.blue)
                    Text(NSLocalizedString("Show in Widget", comment: "Widget toggle"))
                }
            }
            .accessibilityIdentifier("showInWidgetToggle")

            // D2: Calendar Toggle
            Toggle(isOn: $tracker.showInCalendar) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.orange)
                    Text(NSLocalizedString("Show in Calendar", comment: "Calendar toggle"))
                }
            }
            .accessibilityIdentifier("showInCalendarToggle")
        } header: {
            Text(NSLocalizedString("Integrations", comment: "Integrations section header"))
        }
    }

    // MARK: - Reminder Section

    private var reminderSection: some View {
        Section {
            if linkedReminders.isEmpty {
                HStack {
                    Image(systemName: "bell.slash")
                        .foregroundStyle(.secondary)
                    Text(NSLocalizedString("No reminders linked", comment: "No reminders label"))
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(linkedReminders) { reminder in
                    HStack {
                        Image(systemName: reminder.isEnabled ? "bell.fill" : "bell.slash.fill")
                            .foregroundStyle(reminder.isEnabled ? .green : .secondary)
                        VStack(alignment: .leading) {
                            Text(reminder.title)
                            Text(reminder.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            NavigationLink {
                SmartRemindersView()
            } label: {
                Label(
                    NSLocalizedString("Manage Smart Reminders", comment: "Manage reminders link"),
                    systemImage: "bell.badge"
                )
            }
        } header: {
            Text(NSLocalizedString("Smart Reminders", comment: "Reminders section header"))
        } footer: {
            Text(NSLocalizedString("Create reminders that auto-cancel when you log this tracker.", comment: "Reminders explanation"))
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(NSLocalizedString("Done", comment: "Done button")) {
                dismiss()
            }
        }
    }

    @ViewBuilder
    private var deleteConfirmationButtons: some View {
        Button(NSLocalizedString("Delete", comment: "Delete action"), role: .destructive) {
            deleteTracker()
        }
        Button(NSLocalizedString("Cancel", comment: "Cancel action"), role: .cancel) {}
    }

    private func onAppearHandler() {
        if tracker.trackingMode == .levels {
            loadLevelEditorState()
        }
        loadLinkedReminders()
    }

    private func loadLinkedReminders() {
        // Load reminders linked to this tracker from SmartReminderEngine
        let allReminders = SmartReminderEngine.shared.getReminders()
        linkedReminders = allReminders.filter { $0.trackerID == tracker.id }
    }

    // MARK: - Basic Settings Section

    @ViewBuilder
    private var basicSettingsSection: some View {
        // Icon Section
        Section {
            iconSelectionGrid
        } header: {
            Text(NSLocalizedString("Icon", comment: "Icon section header"))
        }

        // Name Section
        Section {
            TextField(
                NSLocalizedString("Name", comment: "Tracker name field"),
                text: $tracker.name
            )
        } header: {
            Text(NSLocalizedString("Name", comment: "Name section header"))
        }

        // Daily Goal Section (only for counter mode)
        if tracker.trackingMode == .counter {
            Section {
                Stepper(value: Binding(
                    get: { tracker.dailyGoal ?? 0 },
                    set: { tracker.dailyGoal = $0 > 0 ? $0 : nil }
                ), in: 0...100) {
                    HStack {
                        Text(NSLocalizedString("Daily Goal", comment: "Daily goal label"))
                        Spacer()
                        Text("\(tracker.dailyGoal ?? 0)")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(NSLocalizedString("Goal", comment: "Goal section header"))
            } footer: {
                Text(NSLocalizedString("Set to 0 to disable goal tracking.", comment: "Goal footer"))
            }
        }
    }

    // MARK: - Level Editor Sections

    @ViewBuilder
    private var levelEditorSections: some View {
        if tracker.trackingMode == .levels {
            levelsSection
            jokerSystemSection
            dayBoundarySection
        }
    }

    private var levelsSection: some View {
        Section {
            ForEach($editableLevels) { $level in
                LevelEditorRow(
                    level: $level,
                    iconChoices: levelIconChoices,
                    canDelete: editableLevels.count > 2,
                    onDelete: { deleteLevel(level) }
                )
            }

            if editableLevels.count < 5 {
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
                Text("\(editableLevels.count)/5")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } footer: {
            if !editableLevels.contains(where: { $0.streakEffect == .success }) {
                Text(NSLocalizedString("⚠️ At least one level must be \"Success\" for streaks to work.", comment: "Missing success level warning"))
                    .foregroundStyle(.orange)
            } else {
                Text(NSLocalizedString("Define 2-5 levels with different streak effects.", comment: "Levels explanation"))
            }
        }
    }

    private var jokerSystemSection: some View {
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
    }

    private var dayBoundarySection: some View {
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

    // MARK: - Info Section

    private var infoSection: some View {
        Section {
            // FEAT-39 C2: History link
            NavigationLink {
                TrackerHistorySheet(tracker: tracker)
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text(NSLocalizedString("View History", comment: "View history link"))
                }
            }
            .accessibilityIdentifier("trackerHistoryLink")

            HStack {
                Text(NSLocalizedString("Type", comment: "Tracker type label"))
                Spacer()
                Text(typeLabel)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(NSLocalizedString("Mode", comment: "Tracking mode label"))
                Spacer()
                Text(modeLabel)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(NSLocalizedString("Created", comment: "Creation date label"))
                Spacer()
                Text(tracker.createdAt, style: .date)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(NSLocalizedString("Total Logs", comment: "Total logs label"))
                Spacer()
                Text("\(tracker.logs.count)")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(NSLocalizedString("Info", comment: "Info section header"))
        }
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        Section {
            Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                HStack {
                    Image(systemName: "trash")
                    Text(NSLocalizedString("Delete Tracker", comment: "Delete button"))
                }
            }
        } footer: {
            Text(NSLocalizedString("This will permanently delete the tracker and all its logs.", comment: "Delete warning"))
        }
    }

    // MARK: - Icon Selection Grid

    private var iconSelectionGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
            ForEach(emojiChoices, id: \.self) { emoji in
                Button {
                    tracker.icon = emoji
                } label: {
                    Text(emoji)
                        .font(.system(size: 28))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(tracker.icon == emoji ? Color.blue.opacity(0.2) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(tracker.icon == emoji ? Color.blue : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helper Labels

    private var typeLabel: String {
        switch tracker.type {
        case .good:
            return NSLocalizedString("Good Habit", comment: "Good tracker type")
        case .saboteur:
            return NSLocalizedString("Saboteur", comment: "Saboteur tracker type")
        }
    }

    private var modeLabel: String {
        switch tracker.trackingMode {
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

    // MARK: - Actions

    private func deleteTracker() {
        TrackerManager.shared.deleteTracker(tracker, from: modelContext)
        dismiss()
    }

    // MARK: - Level Management

    private func loadLevelEditorState() {
        // Load levels from tracker
        if let trackerLevels = tracker.levels {
            editableLevels = trackerLevels.map { level in
                EditableLevel(
                    icon: level.icon,
                    name: level.labelKey,
                    streakEffect: level.streakEffect
                )
            }
        } else {
            // Default levels if none exist
            editableLevels = [
                EditableLevel.makeDefault(index: 0),
                EditableLevel.makeDefault(index: 1)
            ]
        }

        // Load joker config
        if let rewardConfig = tracker.rewardConfig {
            enableJokerSystem = true
            jokerEarnEveryDays = rewardConfig.earnEveryDays
            jokerMaxOnHand = rewardConfig.maxOnHand
        } else {
            enableJokerSystem = false
        }

        // Load day boundary
        switch tracker.effectiveDayAssignment {
        case .timestamp:
            useCutoffHour = false
        case .cutoffHour(let hour):
            useCutoffHour = true
            cutoffHour = hour
        }
    }

    private func saveLevelsToTracker() {
        guard tracker.trackingMode == .levels else { return }

        // Save levels
        tracker.levels = editableLevels.enumerated().map { index, editableLevel in
            TrackerLevel(
                id: index,
                key: editableLevel.name.lowercased().replacingOccurrences(of: " ", with: "_"),
                icon: editableLevel.icon,
                labelKey: editableLevel.name,
                streakEffect: editableLevel.streakEffect
            )
        }
    }

    private func saveJokerConfigToTracker() {
        guard tracker.trackingMode == .levels else { return }

        if enableJokerSystem {
            tracker.rewardConfig = RewardConfig(
                earnEveryDays: jokerEarnEveryDays,
                maxOnHand: jokerMaxOnHand,
                canHealGrace: true
            )
        } else {
            tracker.rewardConfig = nil
        }
    }

    private func saveDayBoundaryToTracker() {
        guard tracker.trackingMode == .levels else { return }

        if useCutoffHour {
            tracker.dayAssignmentRaw = "cutoffHour:\(cutoffHour)"
        } else {
            tracker.dayAssignmentRaw = nil
        }
    }

    private func addLevel() {
        guard editableLevels.count < 5 else { return }
        let newLevel = EditableLevel.makeDefault(index: editableLevels.count)
        editableLevels.append(newLevel)
        saveLevelsToTracker()
    }

    private func deleteLevel(_ level: EditableLevel) {
        guard editableLevels.count > 2 else { return }
        editableLevels.removeAll { $0.id == level.id }
        saveLevelsToTracker()
    }
}

#if DEBUG
#Preview("Counter Tracker") {
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

    return TrackerEditorSheet(tracker: tracker)
        .modelContainer(container)
}

#Preview("Level Tracker") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Tracker.self, TrackerLog.self, configurations: config)

    let tracker = Tracker(
        name: "NoAlc",
        icon: "🍷",
        type: .saboteur,
        trackingMode: .levels
    )
    // Configure with NoAlc-style levels
    tracker.levels = TrackerLevel.noAlcLevels
    tracker.rewardConfig = .noAlcDefault
    tracker.dayAssignmentRaw = "cutoffHour:18"

    container.mainContext.insert(tracker)

    return TrackerEditorSheet(tracker: tracker)
        .modelContainer(container)
}
#endif

#endif // os(iOS)
