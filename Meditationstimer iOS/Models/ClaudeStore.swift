//
//  ClaudeStore.swift
//  Meditationstimer iOS
//
//  #51 Schnitt 2b-1: Persistenz um die reine Funktion `apply` (ClaudeApply.swift bleibt rein).
//  Spec: DOCS/specs/features/feature-51-s2b-speichern.md
//

import Foundation

extension Notification.Name {
    static let claudeStoreDidChange = Notification.Name("ClaudeStore.didChange")
}

enum ClaudeListState: Equatable { case missing, stored, unreadable }

/// Inhalt von `claudeState`: nur das Gedaechtnis, nicht die Listen (die liegen unter ihren eigenen Keys).
struct ClaudeStoredState: Codable, Equatable {
    var exercises: [ClaudeStoredExercise] = []
    var log: [ClaudeApplyLogEntry] = []
}

extension AtemView.Preset {
    static let backupKeyPrefix = "atemPresetsBackup."
    static func loadStored(from defaults: UserDefaults, key: String = "atemPresets",
                           now: Date = Date()) -> [AtemView.Preset]? {
        guard let data = defaults.data(forKey: key) else { return nil }
        if let decoded = try? JSONDecoder().decode([AtemView.Preset].self, from: data) { return decoded }
        WorkoutSet.backUpUnreadable(data, prefix: backupKeyPrefix, in: defaults, now: now)
        return nil
    }
}

/// Die reine Funktion `apply`; der Name ist in `ClaudeStore` durch die gleichnamige Methode verdeckt.
private func applyToState(_ d: ClaudeDelivery, _ s: ClaudeApplyState, _ last: Date?, _ now: Date)
    -> (ClaudeApplyState, ClaudeApplyResult) {
    apply(d, to: s, lastSnapshotAt: last, now: now)
}

enum ClaudeStore {
    static let setsKey = "workoutProgramSets"
    static let presetsKey = "atemPresets"
    static let stateKey = "claudeState"
    static let stateBackupPrefix = "claudeStateBackup."

    /// #51 2b-2: Unveraendert -> nil (nichts schreiben), ausser `isNew` (ueber die Neu-Karte angelegt, AC-14). Sonst `modifiedAt = now`, per id ersetzen, sonst anhaengen.
    static func savingEdit<T: Identifiable & Equatable>(_ edited: T, original: T, in list: [T],
                                                        modifiedAt: WritableKeyPath<T, Date?>, now: Date, isNew: Bool = false) -> [T]? {
        if edited == original && !isNew { return nil }
        var stamped = edited
        stamped[keyPath: modifiedAt] = now
        var result = list
        if let i = result.firstIndex(where: { $0.id == stamped.id }) { result[i] = stamped } else { result.append(stamped) }
        return result
    }

    static let unreadableResult = ClaudeApplyResult.rejected(
        code: "LIST_UNREADABLE",
        reason: "Die gespeicherten Programme oder Atemübungen sind nicht lesbar; bitte später neu lesen.")

    /// Gespeichert (mit Vorgaben ergaenzt) oder Vorgaben; unlesbar wird gesichert und zeigt Vorgaben.
    static func loadSets(from defaults: UserDefaults, now: Date = Date()) -> (list: [WorkoutSet], state: ClaudeListState) {
        guard defaults.data(forKey: setsKey) != nil else { return (defaultWorkoutSets, .missing) }
        guard let stored = WorkoutSet.loadStored(from: defaults, key: setsKey, now: now) else {
            return (defaultWorkoutSets, .unreadable)
        }
        return (WorkoutSet.migratingPresets(stored, presets: defaultWorkoutSets), .stored)
    }

    static func loadPresets(from defaults: UserDefaults, now: Date = Date()) -> (list: [AtemView.Preset], state: ClaudeListState) {
        guard defaults.data(forKey: presetsKey) != nil else { return (MeditationTab.defaultPresets, .missing) }
        guard let stored = AtemView.Preset.loadStored(from: defaults, key: presetsKey, now: now) else {
            return (MeditationTab.defaultPresets, .unreadable)
        }
        return (MeditationTab.migratingPresets(stored), .stored)
    }

    private static func loadState(from defaults: UserDefaults, now: Date) -> ClaudeStoredState {
        guard let data = defaults.data(forKey: stateKey) else { return ClaudeStoredState() }
        if let decoded = try? JSONDecoder().decode(ClaudeStoredState.self, from: data) { return decoded }
        WorkoutSet.backUpUnreadable(data, prefix: stateBackupPrefix, in: defaults, now: now)
        return ClaudeStoredState()
    }

    /// #57 S3: Liest `claudeState` ohne Sicherung und ohne Schreiben; unlesbar -> leer und `unreadable`.
    static func readState(from defaults: UserDefaults) -> (state: ClaudeStoredState, unreadable: Bool) {
        guard let data = defaults.data(forKey: stateKey) else { return (ClaudeStoredState(), false) }
        guard let state = try? JSONDecoder().decode(ClaudeStoredState.self, from: data) else { return (ClaudeStoredState(), true) }
        return (state, false)
    }

    /// #51 S3: Gelieferte Uebung (`claude.*`) aus dem Zustand; Katalog bleibt Sache von `ExerciseDatabase`.
    private static func storedExerciseEntry(id: String, defaults: UserDefaults) -> ClaudeStoredExercise? {
        guard id.hasPrefix("claude.") else { return nil }
        return loadState(from: defaults, now: Date()).exercises.first { $0.claude.itemId == id }
    }

    static func storedExercise(id: String, defaults: UserDefaults = .standard) -> ExerciseInfo? {
        guard let e = storedExerciseEntry(id: id, defaults: defaults) else { return nil }
        return ExerciseInfo(id: id, name: e.name, category: mapCategory(e.category) ?? .fullBody,
                            effect: e.effect, instructions: e.instructions, notes: e.notes)
    }

    static func storedExerciseOrigin(id: String, defaults: UserDefaults = .standard) -> ClaudeOrigin? {
        storedExerciseEntry(id: id, defaults: defaults)?.claude
    }

    /// Kapseltext in der Liste: "von Claude", nach Bearbeitung "von Claude · angepasst".
    static func badgeText(modifiedAt: Date?) -> String {
        modifiedAt == nil ? NSLocalizedString("von Claude", comment: "Badge on delivered items")
                          : NSLocalizedString("von Claude · angepasst", comment: "Badge on delivered items edited by the user")
    }

    /// Liest, wendet an, schreibt (Listen zuerst, `claudeState` zuletzt) und meldet nach dem Schreiben.
    static func apply(_ delivery: ClaudeDelivery, in defaults: UserDefaults = .standard, lastSnapshotAt: Date?,
                      now: Date = Date(), center: NotificationCenter? = .default) -> ClaudeApplyResult {
        let sets = loadSets(from: defaults, now: now), presets = loadPresets(from: defaults, now: now)
        if sets.state == .unreadable || presets.state == .unreadable { return unreadableResult }
        let old = loadState(from: defaults, now: now)
        let isNew = !old.log.contains { $0.deliveryId == delivery.deliveryId }
        let input = ClaudeApplyState(sets: sets.list, presets: presets.list, exercises: old.exercises, log: old.log)
        let (new, result) = applyToState(delivery, input, lastSnapshotAt, now)

        let wroteLists = isNew && result == .applied
        if wroteLists {
            if let data = try? JSONEncoder().encode(new.sets) { defaults.set(data, forKey: setsKey) }
            if let data = try? JSONEncoder().encode(new.presets) { defaults.set(data, forKey: presetsKey) }
        }
        let newStored = ClaudeStoredState(exercises: new.exercises, log: new.log)
        if newStored != old, let data = try? JSONEncoder().encode(newStored) { defaults.set(data, forKey: stateKey) }
        if wroteLists { center?.post(name: .claudeStoreDidChange, object: nil) }
        return result
    }
}
