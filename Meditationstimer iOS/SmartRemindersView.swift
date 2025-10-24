//
//  SmartRemindersView.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 27.09.25.
//

import SwiftUI

/// View für die Verwaltung von Smart Reminders
struct SmartRemindersView: View {
    @AppStorage("smartRemindersEnabled") private var smartRemindersEnabled: Bool = false

    @State private var reminders: [SmartReminder] = []
    @State private var showingAddReminder = false
    @State private var editingReminder: SmartReminder?

    private let engine = SmartReminderEngine.shared

    var body: some View {
        List {
            Section {
                Toggle("Smart Reminders aktivieren", isOn: $smartRemindersEnabled)
                    .help("Aktiviert intelligente Erinnerungen basierend auf deiner Aktivität.")
            }

            if smartRemindersEnabled {
                Section(header: Text("Erinnerungen")) {
                    if reminders.isEmpty {
                        Text("Keine Smart Reminders konfiguriert")
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
                    Text("Smart Reminders senden Benachrichtigungen, wenn du länger als die eingestellte Zeit keine Meditation oder Workouts durchgeführt hast.")
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

    private func loadReminders() {
        reminders = engine.getReminders()
        if reminders.isEmpty {
            // Lade Beispieldaten falls keine gespeicherten Daten vorhanden
            reminders = SmartReminder.sampleData()
        }
    }

    private func saveReminders() {
        // Nicht mehr nötig - der Engine speichert automatisch
    }

    private func addReminder(_ reminder: SmartReminder) {
        engine.addReminder(reminder)
        loadReminders() // UI aktualisieren
    }

    private func updateReminder(_ updatedReminder: SmartReminder) {
        engine.updateReminder(updatedReminder)
        loadReminders() // UI aktualisieren
    }

    private func deleteReminder(_ reminder: SmartReminder) {
        engine.removeReminder(withId: reminder.id)
        loadReminders() // UI aktualisieren
    }
}

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
                        ForEach(1...24, id: \.self) { hours in
                            Text("\(hours)").tag(hours)
                        }
                    }

                    Picker("Aktivitätstyp", selection: $activityType) {
                        Text("Meditation").tag(ActivityType.mindfulness)
                        Text("Workout").tag(ActivityType.workout)
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
                    .disabled(title.isEmpty || message.isEmpty)
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