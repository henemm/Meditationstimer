//
//  ClaudeEditorSpeichernTests.swift
//  LeanHealthTimerTests
//
//  TDD RED #51 Schnitt 2b, Runde 2b-2: Editoren setzen `modifiedAt`, Schritt-Editor behaelt `claude.*`.
//  Rundenspec: DOCS/specs/features/feature-51-s2b2-editor.md (AC-1 bis AC-10).
//  Neue APIs (fehlen noch, daher Compile-Fehler = RED):
//    ClaudeStore.savingEdit(_:original:in:modifiedAt:now:) -> [T]?
//    WorkoutPhase.applyKeepingClaudeId(ownName:)
//

import XCTest
@testable import Lean_Health_Timer

final class ClaudeEditorSpeichernTests: XCTestCase {

    // MARK: - Hilfen

    private let delivered = Date(timeIntervalSince1970: 1_700_000_000)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func origin(_ itemId: String, rev: Int = 1) -> ClaudeOrigin {
        ClaudeOrigin(itemId: itemId, revision: rev, why: "Weil es passt.", packageId: "claude.paket",
                     packageName: "Paket", deliveredAt: delivered)
    }

    private func program(_ name: String = "Claude Programm", rev: Int = 1, id: UUID = UUID(),
                         itemId: String = "claude.prog", claude: Bool = true) -> WorkoutSet {
        WorkoutSet(id: id, name: name, emoji: "💪",
                   phases: [WorkoutPhase(name: "Planke", workDuration: 30, restDuration: 10, exerciseId: "builtin.planke", hint: nil)],
                   repetitions: 2, claude: claude ? origin(itemId, rev: rev) : nil)
    }

    private func breath(_ name: String = "Claude Atem", rev: Int = 1, id: UUID = UUID(),
                        itemId: String = "claude.atem", claude: Bool = true) -> AtemView.Preset {
        AtemView.Preset(id: id, name: name, emoji: "🌙", inhale: 4, holdIn: 2, exhale: 6, holdOut: 0, repetitions: 10,
                        claude: claude ? origin(itemId, rev: rev) : nil)
    }

    private func renamed(_ s: WorkoutSet, _ name: String) -> WorkoutSet { var c = s; c.name = name; return c }
    private func renamed(_ p: AtemView.Preset, _ name: String) -> AtemView.Preset { var c = p; c.name = name; return c }

    private func delivery(_ id: String, items: [[String: Any]]) throws -> ClaudeDelivery {
        let json: [String: Any] = ["format": "hhhaven.delivery/1", "deliveryId": id, "source": "claude",
                                   "createdAt": "2026-11-13T10:15:00Z", "why": "Neue Revision", "items": items]
        return try ClaudeDelivery.read(try JSONSerialization.data(withJSONObject: json))
    }

    private func programItem(_ rev: Int, _ name: String) -> [String: Any] {
        ["kind": "program", "itemId": "claude.prog", "revision": rev, "name": name, "symbol": "💪", "rounds": 2,
         "steps": [["exerciseId": "builtin.planke", "workSeconds": 30, "restSeconds": 10]]]
    }

    private func breathItem(_ rev: Int, _ name: String) -> [String: Any] {
        ["kind": "breath", "itemId": "claude.atem", "revision": rev, "name": name, "symbol": "🌙",
         "inhaleSeconds": 4, "holdInSeconds": 2, "exhaleSeconds": 6, "holdOutSeconds": 0, "rounds": 10]
    }

    // MARK: - AC-1

    /// Verhalten: Ein unveraendert gespeichertes Programm schreibt nichts (kein `modifiedAt`).
    func testSavingEditUnveraendertLiefertNil_Programm() {
        let original = program()
        let list = [program("Anderes", itemId: "claude.x"), original]
        XCTAssertNil(original.modifiedAt)
        XCTAssertNil(ClaudeStore.savingEdit(original, original: original, in: list, modifiedAt: \.modifiedAt, now: now))
        XCTAssertNil(ClaudeStore.savingEdit(original, original: original, in: [], modifiedAt: \.modifiedAt, now: now))
    }

    /// Verhalten: Eine unveraendert gespeicherte Atemuebung schreibt nichts.
    func testSavingEditUnveraendertLiefertNil_Atemuebung() {
        let original = breath()
        let list = [breath("Anderes", itemId: "claude.x"), original]
        XCTAssertNil(ClaudeStore.savingEdit(original, original: original, in: list, modifiedAt: \.modifiedAt, now: now))
        XCTAssertNil(ClaudeStore.savingEdit(original, original: original, in: [], modifiedAt: \.modifiedAt, now: now))
    }

    // MARK: - AC-2

    /// Verhalten: Ein geaendertes Programm ersetzt das alte an gleicher Stelle, traegt `modifiedAt = jetzt` und behaelt die Herkunft.
    func testSavingEditGeaendertErsetztUndSetztModifiedAt_Programm() throws {
        let a = program("A", itemId: "claude.a"), original = program("Mitte"), c = program("C", itemId: "claude.c")
        let edited = renamed(original, "Hennings Name")
        let result = try XCTUnwrap(ClaudeStore.savingEdit(edited, original: original, in: [a, original, c],
                                                          modifiedAt: \.modifiedAt, now: now))
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], a)
        XCTAssertEqual(result[2], c)
        XCTAssertEqual(result[1].id, original.id)
        XCTAssertEqual(result[1].name, "Hennings Name")
        XCTAssertEqual(result[1].modifiedAt, now)
        XCTAssertEqual(result[1].claude, original.claude)
        XCTAssertEqual(result[1].phases, original.phases)
    }

    /// Verhalten: Eine geaenderte Atemuebung ersetzt die alte an gleicher Stelle, traegt `modifiedAt = jetzt` und behaelt die Herkunft.
    func testSavingEditGeaendertErsetztUndSetztModifiedAt_Atemuebung() throws {
        let a = breath("A", itemId: "claude.a"), original = breath("Mitte"), c = breath("C", itemId: "claude.c")
        let edited = renamed(original, "Hennings Atem")
        let result = try XCTUnwrap(ClaudeStore.savingEdit(edited, original: original, in: [a, original, c],
                                                          modifiedAt: \.modifiedAt, now: now))
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], a)
        XCTAssertEqual(result[2], c)
        XCTAssertEqual(result[1].id, original.id)
        XCTAssertEqual(result[1].name, "Hennings Atem")
        XCTAssertEqual(result[1].modifiedAt, now)
        XCTAssertEqual(result[1].claude, original.claude)
    }

    // MARK: - AC-3

    /// Verhalten: Ein neu angelegter Baustein (id nicht in der Liste) wird hinten angehaengt, mit `modifiedAt = jetzt`.
    func testSavingEditNeuerBausteinWirdAngehaengt() throws {
        let a = program("A", itemId: "claude.a"), b = program("B", itemId: "claude.b")
        let blank = program("", claude: false)
        var edited = blank
        edited.name = "Neu von Henning"
        let result = try XCTUnwrap(ClaudeStore.savingEdit(edited, original: blank, in: [a, b], modifiedAt: \.modifiedAt, now: now))
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(Array(result.prefix(2)), [a, b])
        XCTAssertEqual(result[2].id, edited.id)
        XCTAssertEqual(result[2].name, "Neu von Henning")
        XCTAssertEqual(result[2].modifiedAt, now)
        XCTAssertNil(result[2].claude)
    }

    // MARK: - AC-4

    /// Verhalten: Wurde der Baustein inzwischen zurueckgenommen, steht Hennings Fassung wieder hinten in der Liste, weiter mit Herkunft.
    func testSavingEditZurueckgenommenerBausteinWirdWiederAngelegt() throws {
        let original = program()
        let edited = renamed(original, "Hennings Fassung")
        let remaining = program("Rest", itemId: "claude.rest")
        let result = try XCTUnwrap(ClaudeStore.savingEdit(edited, original: original, in: [remaining],
                                                          modifiedAt: \.modifiedAt, now: now))
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], remaining)
        XCTAssertEqual(result[1].id, original.id)
        XCTAssertEqual(result[1].name, "Hennings Fassung")
        XCTAssertEqual(result[1].modifiedAt, now)
        XCTAssertEqual(result[1].claude?.itemId, "claude.prog")
    }

    // MARK: - AC-5

    /// Verhalten: Ein veralteter Editor ohne Aenderung ueberschreibt eine inzwischen hoehere Revision nicht.
    func testSavingEditUnveraendertLaesstNeuereRevisionStehen() {
        let id = UUID()
        let original = program("Alt", rev: 1, id: id)
        let newer = program("Neu aus Revision 2", rev: 2, id: id)
        XCTAssertNil(ClaudeStore.savingEdit(original, original: original, in: [newer], modifiedAt: \.modifiedAt, now: now))
        let oldBreath = breath("Alt", rev: 1, id: id), newBreath = breath("Neu", rev: 2, id: id)
        XCTAssertNil(ClaudeStore.savingEdit(oldBreath, original: oldBreath, in: [newBreath], modifiedAt: \.modifiedAt, now: now))
    }

    // MARK: - AC-6

    /// Verhalten: Hennings geaendertes Programm wird von einer neuen Revision nicht ueberschrieben (CHANGED_ON_IPHONE).
    func testGeaenderterClaudeBausteinLehntLieferungAb_Programm() throws {
        let seed = try delivery("seed-p", items: [programItem(1, "Alt-P")])
        let (seeded, r0) = apply(seed, to: ClaudeApplyState(sets: [], presets: [], exercises: [], log: []),
                                 lastSnapshotAt: nil, now: delivered)
        XCTAssertEqual(r0, .applied)
        let original = try XCTUnwrap(seeded.sets.first)
        let edited = try XCTUnwrap(ClaudeStore.savingEdit(renamed(original, "Hennings Name"), original: original,
                                                          in: seeded.sets, modifiedAt: \.modifiedAt, now: now))
        var state = seeded
        state.sets = edited
        let snapshots: [(String, Date?)] = [("datum", now.addingTimeInterval(-60)), ("nil", nil)]
        for (label, snapshot) in snapshots {
            let rev2 = try delivery("rev2-p-\(label)", items: [programItem(2, "Neu aus Revision 2")])
            let (after, result) = apply(rev2, to: state, lastSnapshotAt: snapshot, now: now.addingTimeInterval(10))
            guard case .rejected(let code, _) = result else { return XCTFail("erwartet rejected, war \(result)") }
            XCTAssertEqual(code, "CHANGED_ON_IPHONE", label)
            XCTAssertEqual(after.sets, edited, "Liste muss unveraendert bleiben (\(label))")
            XCTAssertEqual(after.sets.first?.name, "Hennings Name")
        }
    }

    /// Verhalten: Hennings geaenderte Atemuebung wird von einer neuen Revision nicht ueberschrieben (CHANGED_ON_IPHONE).
    func testGeaenderterClaudeBausteinLehntLieferungAb_Atemuebung() throws {
        let seed = try delivery("seed-a", items: [breathItem(1, "Alt-A")])
        let (seeded, r0) = apply(seed, to: ClaudeApplyState(sets: [], presets: [], exercises: [], log: []),
                                 lastSnapshotAt: nil, now: delivered)
        XCTAssertEqual(r0, .applied)
        let original = try XCTUnwrap(seeded.presets.first)
        let edited = try XCTUnwrap(ClaudeStore.savingEdit(renamed(original, "Hennings Atem"), original: original,
                                                          in: seeded.presets, modifiedAt: \.modifiedAt, now: now))
        var state = seeded
        state.presets = edited
        let snapshots: [(String, Date?)] = [("datum", now.addingTimeInterval(-60)), ("nil", nil)]
        for (label, snapshot) in snapshots {
            let rev2 = try delivery("rev2-a-\(label)", items: [breathItem(2, "Neu aus Revision 2")])
            let (after, result) = apply(rev2, to: state, lastSnapshotAt: snapshot, now: now.addingTimeInterval(10))
            guard case .rejected(let code, _) = result else { return XCTFail("erwartet rejected, war \(result)") }
            XCTAssertEqual(code, "CHANGED_ON_IPHONE", label)
            XCTAssertEqual(after.presets, edited, "Liste muss unveraendert bleiben (\(label))")
            XCTAssertEqual(after.presets.first?.name, "Hennings Atem")
        }
    }

    // MARK: - AC-7 bis AC-9

    private func claudePhase() -> WorkoutPhase {
        WorkoutPhase(name: "Bergsteiger Plus", workDuration: 30, restDuration: 10, exerciseId: "claude.x", hint: "Langsam")
    }

    /// Verhalten: Ein Schritt mit Claude-Uebung behaelt Kennung und Name, wenn Henning den Namen nicht aendert.
    func testPhaseBehaeltClaudeIdBeiUnveraendertemNamen() {
        var phase = claudePhase()
        phase.applyKeepingClaudeId(ownName: "Bergsteiger Plus")
        XCTAssertEqual(phase.exerciseId, "claude.x")
        XCTAssertEqual(phase.name, "Bergsteiger Plus")
        XCTAssertEqual(phase.workDuration, 30)
        XCTAssertEqual(phase.hint, "Langsam")
    }

    /// Verhalten: Aendert Henning den Namen, wird der Schritt zur eigenen Uebung (own.*); own.* und builtin.* verhalten sich wie bisher.
    func testPhaseWechseltAufOwnBeiNamensaenderung() {
        var phase = claudePhase()
        phase.applyKeepingClaudeId(ownName: "Mein Name")
        XCTAssertEqual(phase.exerciseId, ExerciseDatabase.ownExerciseId(forName: "Mein Name"))
        XCTAssertEqual(phase.name, "Mein Name")

        for id in ["own.mein-name", "builtin.planke"] {
            var viaNew = WorkoutPhase(name: "Planke", workDuration: 30, restDuration: 10, exerciseId: id, hint: nil)
            var viaOld = viaNew
            viaNew.applyKeepingClaudeId(ownName: "Planke")
            viaOld.apply(.own(name: "Planke"))
            XCTAssertEqual(viaNew.exerciseId, viaOld.exerciseId, "\(id) muss sich wie apply(.own) verhalten")
            XCTAssertEqual(viaNew.name, viaOld.name)
            XCTAssertEqual(viaNew.exerciseId, ExerciseDatabase.ownExerciseId(forName: "Planke"))
        }
    }

    /// Verhalten: Waehlt Henning im Picker eine Katalogubung, ersetzt sie die Claude-Kennung.
    func testPhaseKatalogwechselErsetztClaudeId() {
        var phase = claudePhase()
        phase.apply(.catalog(id: "builtin.planke"))
        XCTAssertEqual(phase.exerciseId, "builtin.planke")
        XCTAssertEqual(phase.name, ExerciseDatabase.info(forId: "builtin.planke")?.name)
    }

    // MARK: - AC-10

    /// Verhalten: Die Migration setzt kein `modifiedAt` und laesst die Claude-Kennung eines gelieferten Programms unberuehrt.
    func testMigratingPresetsLaesstClaudeProgrammUnberuehrt() throws {
        var set = program("Claude Programm mit Eigener")
        set.phases = [WorkoutPhase(name: "Bergsteiger Plus", workDuration: 30, restDuration: 10, exerciseId: "claude.x", hint: nil)]
        let same = WorkoutSet(name: "Claude Programm mit Eigener", emoji: "💪", phases: [], repetitions: 1, description: "Vorgabe-Text")
        let other = WorkoutSet(name: "Vorgabe", emoji: "🔥", phases: [], repetitions: 1)
        let result = WorkoutSet.migratingPresets([set], presets: [same, other])
        let migrated = try XCTUnwrap(result.first { $0.id == set.id })
        XCTAssertNil(migrated.modifiedAt)
        XCTAssertEqual(migrated.phases.first?.exerciseId, "claude.x")
        XCTAssertEqual(migrated.claude, set.claude)
        XCTAssertEqual(migrated.name, set.name)
    }
}
