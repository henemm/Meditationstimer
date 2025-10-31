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

/// View für die Verwaltung von Activity Reminders mit Permission-Handling
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

    private let engine = SmartReminderEngine.shared

    var body: some View {
        List {
            // Toggle Section (disabled wenn Permissions fehlen)
            Section {
                Toggle("Activity Reminders aktivieren", isOn: $smartRemindersEnabled)
                    .disabled(!allPermissionsGranted)
                    .help("Aktiviert tägliche Erinnerungen zur Aktivitäts-Protokollierung.")
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
                                Text("Fehlende Berechtigungen")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Text("Activity Reminders benötigen alle folgenden Berechtigungen:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Permission Checklist
                        VStack(alignment: .leading, spacing: 8) {
                            PermissionRow(
                                icon: "bell.fill",
                                title: "Benachrichtigungen",
                                granted: notificationsGranted
                            )
                            PermissionRow(
                                icon: "arrow.clockwise",
                                title: "Hintergrundaktualisierung",
                                granted: backgroundRefreshEnabled
                            )
                            PermissionRow(
                                icon: "heart.fill",
                                title: "HealthKit (Achtsamkeit lesen)",
                                granted: healthKitGranted
                            )
                        }
                        .padding(.top, 4)

                        Button(action: openSettings) {
                            HStack {
                                Text("Einstellungen öffnen")
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
                    Text("Gehe zu: Einstellungen → Lean Health Timer\n• Benachrichtigungen: Erlauben\n• Hintergrundaktualisierung: Aktivieren\n• Health → Achtsamkeit: Lesen erlauben")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Reminders List (nur wenn aktiviert)
            if smartRemindersEnabled && allPermissionsGranted {
                Section(header: Text("Erinnerungen")) {
                    if reminders.isEmpty {
                        Text("Keine Activity Reminders konfiguriert")
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
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                    }

                    Button(action: {
                        showingAddReminder = true
                    }) {
                        Label("Neue Erinnerung hinzufügen", systemImage: "plus")
                    }
                }

                Section(header: Text("Info")) {
                    Text("Activity Reminders senden tägliche Benachrichtigungen zur konfigurierten Uhrzeit, um dich an die Aktivitäts-Protokollierung zu erinnern.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Activity Reminders")
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

        // Beim ersten Start: Beispieldaten in Engine speichern
        if reminders.isEmpty {
            let samples = SmartReminder.sampleData()
            for sample in samples {
                engine.addReminder(sample)
            }
            reminders = engine.getReminders()
        } else {
            // Migration: NoAlc Reminder hinzufügen falls nicht vorhanden
            let hasNoAlcReminder = reminders.contains { $0.activityType == .noalc }
            if !hasNoAlcReminder {
                let samples = SmartReminder.sampleData()
                if let noAlcSample = samples.first(where: { $0.activityType == .noalc }) {
                    engine.addReminder(noAlcSample)
                    reminders = engine.getReminders()
                }
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
        loadReminders()
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
                Text(reminder.isEnabled ? "Aktiv" : "Inaktiv")
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

            HStack {
                Text("Nach \(reminder.hoursInactive) Stunden")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(reminder.triggerTime.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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
    @State private var hoursInactive: Int = 24
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
                Section(header: Text("Allgemein")) {
                    TextField("Titel", text: $title)
                    TextField("Nachricht", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                    Toggle("Aktiviert", isOn: $isEnabled)
                }

                Section(header: Text("Zeitplan")) {
                    Picker("Stunden ohne Aktivität", selection: $hoursInactive) {
                        ForEach(1...48, id: \.self) { hours in
                            Text("\(hours)").tag(hours)
                        }
                    }

                    Picker("Aktivitätstyp", selection: $activityType) {
                        Text("Meditation").tag(ActivityType.mindfulness)
                        Text("Workout").tag(ActivityType.workout)
                        Text("NoAlc").tag(ActivityType.noalc)
                    }

                    DatePicker("Uhrzeit", selection: $triggerTime, displayedComponents: .hourAndMinute)
                }

                Section(header: Text("Wochentage")) {
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
            .navigationTitle(reminder == nil ? "Neue Erinnerung" : "Erinnerung bearbeiten")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
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
