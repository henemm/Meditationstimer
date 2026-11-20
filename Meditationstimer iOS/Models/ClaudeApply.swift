//
//  ClaudeApply.swift
//  Meditationstimer
//
//  Reine Anwende-Logik fuer Lieferungen von Claude, #51 Schnitt 2a-1 (Programme, Atemuebungen).
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

struct ClaudeApplyState: Codable, Equatable {
    var sets: [WorkoutSet]
    var presets: [AtemView.Preset]
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
        case .program(let p): one = applyProgram(p, from: delivery, to: &work, lastSnapshotAt: lastSnapshotAt)
        case .breath(let b): one = applyBreath(b, from: delivery, to: &work, lastSnapshotAt: lastSnapshotAt)
        default:
            one = .rejected(code: "KIND_NOT_SUPPORTED", reason: "Diese Art von Baustein kann die App noch nicht annehmen.")
        }
        if case .rejected = one { result = one; break }
        if one == .applied { result = .applied }
    }
    var final = state
    if case .rejected = result {} else { final.sets = work.sets; final.presets = work.presets }
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

/// Regel 10, 2a-1: nur `builtin.*` ist aufloesbar.
func resolveStepName(_ exerciseId: String) -> String? {
    exerciseId.hasPrefix("builtin.") ? ExerciseDatabase.info(forId: exerciseId)?.name : nil
}

func applyProgram(_ p: ClaudeProgram, from d: ClaudeDelivery, to state: inout ClaudeApplyState,
                  lastSnapshotAt: Date?) -> ClaudeApplyResult {
    let index = state.sets.firstIndex { $0.claude?.itemId == p.itemId }
    if let i = index {
        let old = state.sets[i]
        if p.revision <= (old.claude?.revision ?? 0) { return .noEffect }
        if isBlockedByIphone(modifiedAt: old.modifiedAt, lastSnapshotAt: lastSnapshotAt) { return changedOnIphone }
    }
    var phases: [WorkoutPhase] = []
    for step in p.steps {
        guard let name = resolveStepName(step.exerciseId) else {
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
