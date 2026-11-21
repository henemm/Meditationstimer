//
//  ClaudeApply.swift
//  Meditationstimer
//
//  Reine Anwende-Logik fuer Lieferungen von Claude, #51 Schnitt 2a-1 (Programme, Atemuebungen, Uebungen 2a-2).
//  Kein Speicher, keine Benachrichtigung, keine Uhr (Zeit nur ueber `now`). Nur Foundation.
//

import Foundation

struct ClaudeOrigin: Codable, Hashable {
    var itemId: String
    var revision: Int
    var why: String
    var packageId: String?
    var packageName: String?
    var deliveredAt: Date
}

enum ClaudeApplyResult: Codable, Equatable {
    case applied
    case noEffect
    case rejected(code: String, reason: String)
}

struct ClaudeApplyLogEntry: Codable, Equatable {
    var deliveryId: String
    var result: ClaudeApplyResult
    var at: Date
}

/// Von Claude gelieferte Uebung (Regel 6, 12); `category` ist der englische Text der Lieferung.
struct ClaudeStoredExercise: Codable, Hashable {
    var id: UUID
    var name: String
    var nameEn: String?
    var category: String
    var effect: String
    var instructions: String
    var notes: String?
    var claude: ClaudeOrigin
}

struct ClaudeApplyState: Codable, Equatable {
    var sets: [WorkoutSet]
    var presets: [AtemView.Preset]
    var exercises: [ClaudeStoredExercise]
    var log: [ClaudeApplyLogEntry]   // neueste zuletzt, hoechstens 50
}

/// Wendet eine Lieferung auf eine Kopie des Zustands an: ganz oder gar nicht (Bausteine), jedes Ergebnis wird gemerkt.
func apply(_ delivery: ClaudeDelivery, to state: ClaudeApplyState,
           lastSnapshotAt: Date?, now: Date) -> (ClaudeApplyState, ClaudeApplyResult) {
    if let known = state.log.first(where: { $0.deliveryId == delivery.deliveryId }) {
        return (state, known.result)
    }
    var work = state
    var result = ClaudeApplyResult.noEffect
    for item in delivery.items {
        let one: ClaudeApplyResult
        switch item {
        case .program(let p):
            one = applyProgram(p, from: delivery, to: &work, lastSnapshotAt: lastSnapshotAt, initialSets: state.sets)
        case .exercise(let e): one = applyExercise(e, from: delivery, to: &work)
        case .breath(let b): one = applyBreath(b, from: delivery, to: &work, lastSnapshotAt: lastSnapshotAt)
        case .withdrawal(let w): one = applyWithdrawal(w, to: &work, lastSnapshotAt: lastSnapshotAt)
        default:
            one = .rejected(code: "KIND_NOT_SUPPORTED", reason: "Diese Art von Baustein kann die App noch nicht annehmen.")
        }
        if case .rejected = one { result = one; break }
        if one == .applied { result = .applied }
    }
    var final = state
    if case .rejected = result {} else { final.sets = work.sets; final.presets = work.presets; final.exercises = work.exercises }
    final.log.append(ClaudeApplyLogEntry(deliveryId: delivery.deliveryId, result: result, at: now))
    if final.log.count > 50 { final.log.removeFirst(final.log.count - 50) }
    return (final, result)
}

private func origin(_ itemId: String, _ revision: Int, _ d: ClaudeDelivery) -> ClaudeOrigin {
    ClaudeOrigin(itemId: itemId, revision: revision, why: d.why, packageId: d.package?.packageId,
                 packageName: d.package?.name, deliveredAt: d.createdAt)
}

/// Regel 8: Hat Henning den Baustein nach der letzten Abschrift geaendert (oder gibt es keine Abschrift)?
func isBlockedByIphone(modifiedAt: Date?, lastSnapshotAt: Date?) -> Bool {
    guard let modifiedAt else { return false }
    guard let lastSnapshotAt else { return true }
    return modifiedAt > lastSnapshotAt
}

private let changedOnIphone = ClaudeApplyResult.rejected(
    code: "CHANGED_ON_IPHONE", reason: "Henning hat den Baustein inzwischen geändert; bitte neu lesen")

/// Regel 12: englische Kategorie der Lieferung ueber den Fallnamen auf `ExerciseCategory`.
func mapCategory(_ english: String) -> ExerciseCategory? {
    ExerciseCategory.allCases.first { "\($0)" == english }
}

/// Regel 10: `builtin.*` aus der Datenbank; `claude.*` aus der Lieferung, dann aus dem Zustand;
/// `own.*` aus einer Phase der Programme im Eingangszustand.
func resolveStepName(_ id: String, delivery d: ClaudeDelivery, exercises: [ClaudeStoredExercise],
                     initialSets: [WorkoutSet]) -> String? {
    if id.hasPrefix("builtin.") { return ExerciseDatabase.info(forId: id)?.name }
    if id.hasPrefix("claude.") {
        for case .exercise(let e) in d.items where e.itemId == id { return e.name }
        return exercises.first { $0.claude.itemId == id }?.name
    }
    if id.hasPrefix("own.") {
        return initialSets.lazy.flatMap(\.phases).first { $0.exerciseId == id }?.name
    }
    return nil
}

/// Regel 12 vor Regel 7: Kategorie wird vor der Revision geprueft. Uebungen haben kein `modifiedAt` (Regel 8).
func applyExercise(_ e: ClaudeExercise, from d: ClaudeDelivery, to state: inout ClaudeApplyState) -> ClaudeApplyResult {
    guard mapCategory(e.category) != nil else {
        return .rejected(code: "CATEGORY_UNKNOWN", reason: "Die Kategorie \"\(e.category)\" kennt die App nicht; bitte neu lesen.")
    }
    let index = state.exercises.firstIndex { $0.claude.itemId == e.itemId }
    if let i = index, e.revision <= state.exercises[i].claude.revision { return .noEffect }
    let stored = ClaudeStoredExercise(id: index.map { state.exercises[$0].id } ?? UUID(), name: e.name, nameEn: e.nameEn,
                                      category: e.category, effect: e.effect, instructions: e.instructions,
                                      notes: e.notes, claude: origin(e.itemId, e.revision, d))
    if let i = index { state.exercises[i] = stored } else { state.exercises.append(stored) }
    return .applied
}

func applyProgram(_ p: ClaudeProgram, from d: ClaudeDelivery, to state: inout ClaudeApplyState,
                  lastSnapshotAt: Date?, initialSets: [WorkoutSet]) -> ClaudeApplyResult {
    let index = state.sets.firstIndex { $0.claude?.itemId == p.itemId }
    if let i = index {
        let old = state.sets[i]
        if p.revision <= (old.claude?.revision ?? 0) { return .noEffect }
        if isBlockedByIphone(modifiedAt: old.modifiedAt, lastSnapshotAt: lastSnapshotAt) { return changedOnIphone }
    }
    var phases: [WorkoutPhase] = []
    for step in p.steps {
        guard let name = resolveStepName(step.exerciseId, delivery: d, exercises: state.exercises,
                                         initialSets: initialSets) else {
            return .rejected(code: "EXERCISE_UNKNOWN",
                             reason: "Die Übung \"\(step.exerciseId)\" kennt die App nicht; bitte neu lesen.")
        }
        phases.append(WorkoutPhase(name: name, workDuration: step.workSeconds, restDuration: step.restSeconds,
                                   exerciseId: step.exerciseId, hint: step.hint))
    }
    var set = WorkoutSet(id: index.map { state.sets[$0].id } ?? UUID(), name: p.name, emoji: p.symbol,
                         phases: phases, repetitions: p.rounds, description: p.description)
    set.claude = origin(p.itemId, p.revision, d)
    if let i = index { state.sets[i] = set } else { state.sets.append(set) }
    return .applied
}

func applyBreath(_ b: ClaudeBreath, from d: ClaudeDelivery, to state: inout ClaudeApplyState,
                 lastSnapshotAt: Date?) -> ClaudeApplyResult {
    let index = state.presets.firstIndex { $0.claude?.itemId == b.itemId }
    if let i = index {
        let old = state.presets[i]
        if b.revision <= (old.claude?.revision ?? 0) { return .noEffect }
        if isBlockedByIphone(modifiedAt: old.modifiedAt, lastSnapshotAt: lastSnapshotAt) { return changedOnIphone }
    }
    var preset = AtemView.Preset(id: index.map { state.presets[$0].id } ?? UUID(), name: b.name, emoji: b.symbol,
                                 inhale: b.inhaleSeconds, holdIn: b.holdInSeconds, exhale: b.exhaleSeconds,
                                 holdOut: b.holdOutSeconds, repetitions: b.rounds, description: b.description)
    preset.claude = origin(b.itemId, b.revision, d)
    if let i = index { state.presets[i] = preset } else { state.presets.append(preset) }
    return .applied
}

/// Regel 8 und 9: Treffer nur ueber `claude` (itemId und/oder packageId); erst Treffermenge, dann Sperrpruefung, dann entfernen.
func applyWithdrawal(_ w: ClaudeWithdrawal, to state: inout ClaudeApplyState, lastSnapshotAt: Date?) -> ClaudeApplyResult {
    func hit(_ o: ClaudeOrigin?) -> Bool {
        guard let o else { return false }
        return (w.itemId != nil && o.itemId == w.itemId) || (w.packageId != nil && o.packageId == w.packageId)
    }
    let sets = state.sets.filter { hit($0.claude) }
    let presets = state.presets.filter { hit($0.claude) }
    let exercises = state.exercises.filter { hit($0.claude) }
    if sets.isEmpty && presets.isEmpty && exercises.isEmpty { return .noEffect }
    let blocked = sets.contains { isBlockedByIphone(modifiedAt: $0.modifiedAt, lastSnapshotAt: lastSnapshotAt) }
        || presets.contains { isBlockedByIphone(modifiedAt: $0.modifiedAt, lastSnapshotAt: lastSnapshotAt) }
    if blocked { return changedOnIphone }
    state.sets.removeAll { hit($0.claude) }
    state.presets.removeAll { hit($0.claude) }
    state.exercises.removeAll { hit($0.claude) }
    return .applied
}
