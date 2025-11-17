//
//  SmartRemindersView.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 27.09.25.
//

import SwiftUI
import UserNotifications
import HealthKit
#if canImport(UIKit)
import UIKit
#endif

/// View für die Verwaltung von Smart Reminders mit Permission-Handling
struct SmartRemindersView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("smartRemindersEnabled") private var smartRemindersEnabled: Bool = false

    @State private var reminders: [SmartReminder] = []
    @State private var showingAddReminder = false
    @State private var editingReminder: SmartReminder?

    // Permission States
    @State private var notificationsGranted: Bool = false
    @State private var backgroundRefreshEnabled: Bool = false
    @State private var healthKitGranted: Bool = false
    @State private var allPermissionsGranted: Bool = false

    // Deleted reminders blacklist (verhindert automatisches Wieder-Hinzufügen durch Migration)
    @AppStorage("deletedSampleReminderTypes") private var deletedTypesData: Data = Data()

    private let engine = SmartReminderEngine.shared

    var body: some View {
        List {
            // Toggle Section (disabled wenn Permissions fehlen)
            Section {
                Toggle("Enable Smart Reminders", isOn: $smartRemindersEnabled)
                    .disabled(!allPermissionsGranted)
                    .help("Activates smart reminders that are automatically cancelled when you have already completed the activity.")
                    .onChange(of: smartRemindersEnabled) { _, newValue in
                        if newValue {
                            requestNotificationPermissions()
                        }
                    }
            }

            // Permission Warning Banner
            if !allPermissionsGranted {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Missing Permissions")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Text("Smart Reminders require all of the following permissions:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Permission Checklist
                        VStack(alignment: .leading, spacing: 8) {
                            PermissionRow(
                                icon: "bell.fill",
                                title: "Notifications",
                                granted: notificationsGranted
                            )
                            PermissionRow(
                                icon: "arrow.clockwise",
                                title: "Background Refresh",
                                granted: backgroundRefreshEnabled
                            )
                            PermissionRow(
                                icon: "heart.fill",
                                title: "HealthKit (Read Mindfulness)",
                                granted: healthKitGranted
                            )
                        }
                        .padding(.top, 4)

                        Button(action: openSettings) {
                            HStack {
                                Text("Open Settings")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "arrow.up.forward.app")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("")
                } footer: {
                    Text("Go to: Settings → Lean Health Timer\n• Notifications: Allow\n• Background Refresh: Enable\n• Health → Mindfulness: Allow Read Access")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Reminders List (nur wenn aktiviert)
            if smartRemindersEnabled && allPermissionsGranted {
                Section(header: Text("Reminders")) {
                    if reminders.isEmpty {
                        Text("No Smart Reminders configured")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(reminders) { reminder in
                            ReminderRow(reminder: reminder) {
                                editingReminder = reminder
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    deleteReminder(reminder)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }

                    Button(action: {
                        showingAddReminder = true
                    }) {
                        Label("Add New Reminder", systemImage: "plus")
                    }
                }

                Section(header: Text("Info")) {
                    Text("Smart Reminders send notifications at the configured time, but are automatically cancelled if you've already completed the activity during the look-back period.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Smart Reminders")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            loadReminders()
            checkAllPermissions()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // User kommt aus Settings zurück → Permissions neu prüfen
            if newPhase == .active {
                checkAllPermissions()
            }
        }
        .sheet(isPresented: $showingAddReminder) {
            ReminderEditorView { newReminder in
                addReminder(newReminder)
                showingAddReminder = false
            }
        }
        .sheet(item: $editingReminder) { reminder in
            ReminderEditorView(reminder: reminder) { updatedReminder in
                updateReminder(updatedReminder)
                editingReminder = nil
            }
        }
    }

    // MARK: - Reminders Management

    private func loadReminders() {
        reminders = engine.getReminders()

        // Migration: NoAlc Reminder hinzufügen falls nicht vorhanden UND nicht gelöscht
        let hasNoAlcReminder = reminders.contains { $0.activityType == .noalc }
        if !hasNoAlcReminder && !isDeleted(.noalc) {
            let samples = SmartReminder.sampleData()
            if let noAlcSample = samples.first(where: { $0.activityType == .noalc }) {
                engine.addReminder(noAlcSample)
                reminders = engine.getReminders()
            }
        }
    }

    private func addReminder(_ reminder: SmartReminder) {
        engine.addReminder(reminder)
        loadReminders()
    }

    private func updateReminder(_ updatedReminder: SmartReminder) {
        engine.updateReminder(updatedReminder)
        loadReminders()
    }

    private func deleteReminder(_ reminder: SmartReminder) {
        engine.removeReminder(withId: reminder.id)

        // Mark activity type as deleted (prevents auto-re-adding by migration)
        markAsDeleted(reminder.activityType)

        loadReminders()
    }

    // MARK: - Deleted Types Blacklist

    private func loadDeletedTypes() -> Set<ActivityType> {
        guard !deletedTypesData.isEmpty else { return [] }
        do {
            let decoded = try JSONDecoder().decode(Set<ActivityType>.self, from: deletedTypesData)
            return decoded
        } catch {
            print("Failed to load deleted types: \(error)")
            return []
        }
    }

    private func saveDeletedTypes(_ types: Set<ActivityType>) {
        do {
            let encoded = try JSONEncoder().encode(types)
            deletedTypesData = encoded
        } catch {
            print("Failed to save deleted types: \(error)")
        }
    }

    private func isDeleted(_ type: ActivityType) -> Bool {
        return loadDeletedTypes().contains(type)
    }

    private func markAsDeleted(_ type: ActivityType) {
        var deleted = loadDeletedTypes()
        deleted.insert(type)
        saveDeletedTypes(deleted)
    }

    // MARK: - Permission Checks

    /// Prüft alle 3 erforderlichen Permissions
    private func checkAllPermissions() {
        Task {
            // 1. Notifications
            let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
            let notificationsOK = notificationSettings.authorizationStatus == .authorized

            // 2. Background Refresh
            #if os(iOS)
            let backgroundOK = UIApplication.shared.backgroundRefreshStatus == .available
            #else
            let backgroundOK = true
            #endif

            // 3. HealthKit (Mindfulness Read)
            let healthStore = HKHealthStore()
            let mindfulnessType = HKObjectType.categoryType(forIdentifier: .mindfulSession)!
            let healthOK = healthStore.authorizationStatus(for: mindfulnessType) == .sharingAuthorized

            await MainActor.run {
                notificationsGranted = notificationsOK
                backgroundRefreshEnabled = backgroundOK
                healthKitGranted = healthOK
                allPermissionsGranted = notificationsOK && backgroundOK && healthOK

                // Toggle automatisch ausschalten wenn Permissions fehlen
                if !allPermissionsGranted && smartRemindersEnabled {
                    smartRemindersEnabled = false
                }
            }
        }
    }

    private func requestNotificationPermissions() {
        Task {
            let helper = NotificationHelper()
            do {
                try await helper.requestAuthorization()
                // HealthKit Authorization auch anfordern
                try await HealthKitManager.shared.requestAuthorization()
                // Neu checken nach Authorization
                checkAllPermissions()
            } catch {
                print("Permission request failed: \(error.localizedDescription)")
            }
        }
    }

    private func openSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

// MARK: - Permission Row Component

struct PermissionRow: View {
    let icon: String
    let title: String
    let granted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(granted ? .green : .secondary)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)

            Spacer()

            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(granted ? .green : .red)
        }
    }
}

// MARK: - Reminder Row

/// Zeile für einen einzelnen Reminder in der Liste
struct ReminderRow: View {
    let reminder: SmartReminder
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(reminder.title)
                    .font(.headline)
                Spacer()
                Text(reminder.isEnabled ? "Active" : "Inactive")
                    .font(.caption)
                    .foregroundColor(reminder.isEnabled ? .green : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(reminder.isEnabled ? Color.green.opacity(0.1) : Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }

            Text(reminder.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}

// MARK: - Reminder Editor

/// Editor-View für das Hinzufügen/Bearbeiten von Reminders
struct ReminderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var message: String = ""
    @State private var hoursInactive: Int = 12  // Default: 12h look-back window
    @State private var triggerTime: Date = Date()
    @State private var isEnabled: Bool = true
    @State private var selectedDays: Set<Weekday> = Set(Weekday.allCases)
    @State private var activityType: ActivityType = .mindfulness

    let reminder: SmartReminder?
    let onSave: (SmartReminder) -> Void

    init(reminder: SmartReminder? = nil, onSave: @escaping (SmartReminder) -> Void) {
        self.reminder = reminder
        self.onSave = onSave

        if let reminder = reminder {
            _title = State(initialValue: reminder.title)
            _message = State(initialValue: reminder.message)
            _hoursInactive = State(initialValue: reminder.hoursInactive)
            _triggerTime = State(initialValue: reminder.triggerTime)
            _isEnabled = State(initialValue: reminder.isEnabled)
            _selectedDays = State(initialValue: reminder.selectedDays)
            _activityType = State(initialValue: reminder.activityType)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("General")) {
                    TextField("Title", text: $title)
                    TextField("Message", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                    Toggle("Enabled", isOn: $isEnabled)
                }

                Section(header: Text("Schedule")) {
                    Picker("Activity Type", selection: $activityType) {
                        Text("Meditation").tag(ActivityType.mindfulness)
                        Text("Workout").tag(ActivityType.workout)
                        Text("NoAlc").tag(ActivityType.noalc)
                    }

                    DatePicker("Time", selection: $triggerTime, displayedComponents: .hourAndMinute)

                    Picker("Look-back Period", selection: $hoursInactive) {
                        ForEach(1...24, id: \.self) { hours in
                            if hours == 1 {
                                Text("1 hour").tag(hours)
                            } else {
                                Text(String(format: "%d hours", hours)).tag(hours)
                            }
                        }
                    }

                    Text(String(format: "Reminder won't be sent if activity occurred in the last %dh before reminder time.", hoursInactive))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(header: Text("Weekdays")) {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        Toggle(day.displayName, isOn: Binding(
                            get: { selectedDays.contains(day) },
                            set: { isSelected in
                                if isSelected {
                                    selectedDays.insert(day)
                                } else {
                                    selectedDays.remove(day)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle(reminder == nil ? "New Reminder" : "Edit Reminder")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newReminder = SmartReminder(
                            id: reminder?.id ?? UUID(),
                            title: title,
                            message: message,
                            hoursInactive: hoursInactive,
                            triggerTime: triggerTime,
                            isEnabled: isEnabled,
                            selectedDays: selectedDays,
                            activityType: activityType
                        )
                        onSave(newReminder)
                        dismiss()
                    }
                    .disabled(title.isEmpty || message.isEmpty || selectedDays.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        SmartRemindersView()
    }
}
