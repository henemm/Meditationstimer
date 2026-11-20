//
//  ClaudeApplyTests.swift
//  LeanHealthTimerTests
//
//  TDD RED #51 Schnitt 2a, Runde 2a-1: Anwende-Logik fuer Lieferungen von Claude (Programme, Atemuebungen).
//  Spec: DOCS/specs/features/feature-51-s2-bausteine-anwenden.md (Regeln 1-14, AC-1a bis AC-22).
//  Reine Funktion `apply`: kein Speicher, keine Echtzeit (Zeit nur ueber `now`).
//

import XCTest
@testable import Lean_Health_Timer

final class ClaudeApplyTests: XCTestCase {

    // MARK: - Hilfen

    private typealias Json = [String: Any]

    private func t(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func empty() -> ClaudeApplyState { ClaudeApplyState(sets: [], presets: [], log: []) }

    private func sampleDelivery(_ name: String, file: StaticString = #filePath) throws -> ClaudeDelivery {
        let dir = URL(fileURLWithPath: "\(file)").deletingLastPathComponent()
            .appendingPathComponent("../Contracts/deliveries/valid").standardized
        let data = try Data(contentsOf: dir.appendingPathComponent(name))
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? Json)
        let delivery = try XCTUnwrap(root["delivery"] as? Json)
        return try ClaudeDelivery.read(try JSONSerialization.data(withJSONObject: delivery))
    }

    private func breathItem(_ id: String, rev: Int, name: String = "Atem", inhale: Int = 4, rounds: Int = 10) -> Json {
        ["kind": "breath", "itemId": id, "revision": rev, "name": name, "symbol": "🌙",
         "inhaleSeconds": inhale, "holdInSeconds": 2, "exhaleSeconds": 6, "holdOutSeconds": 0, "rounds": rounds]
    }

    private func programItem(_ id: String, rev: Int, name: String = "Programm", rounds: Int = 2,
                             steps: [String] = ["builtin.planke"]) -> Json {
        ["kind": "program", "itemId": id, "revision": rev, "name": name, "symbol": "💪", "rounds": rounds,
         "steps": steps.map { ["exerciseId": $0, "workSeconds": 30, "restSeconds": 10, "hint": "Hinweis"] as Json }]
    }

    private func exerciseItem(_ id: String) -> Json {
        ["kind": "exercise", "itemId": id, "revision": 1, "name": "Vierfuessler", "category": "core",
         "effect": "Rumpf", "instructions": "Langsam"]
    }

    private func delivery(_ id: String, items: [Json], why: String = "Weil es passt.",
                          package: (String, String)? = nil, createdAt: String = "2026-11-13T10:15:00Z") throws -> ClaudeDelivery {
        var json: Json = ["format": "hhhaven.delivery/1", "deliveryId": id, "source": "claude",
                          "createdAt": createdAt, "why": why, "items": items]
        if let package { json["package"] = ["packageId": package.0, "name": package.1] }
        return try ClaudeDelivery.read(try JSONSerialization.data(withJSONObject: json))
    }

    /// Erstes Element oder Testfehler (kein Absturz bei leerer Liste).
    private func first<T>(_ items: [T], _ what: String = "Eintrag", file: StaticString = #filePath, line: UInt = #line) throws -> T {
        try XCTUnwrap(items.first, "\(what) fehlt (Liste leer)", file: file, line: line)
    }

    private func rejection(_ result: ClaudeApplyResult) -> (code: String, reason: String)? {
        if case .rejected(let code, let reason) = result { return (code, reason) }
        return nil
    }

    private func assertRejected(_ result: ClaudeApplyResult, _ code: String, _ ctx: String = "",
                                file: StaticString = #filePath, line: UInt = #line) {
        guard let r = rejection(result) else {
            return XCTFail("\(ctx) erwartet rejected(\(code)), war \(result)", file: file, line: line)
        }
        XCTAssertEqual(r.code, code, ctx, file: file, line: line)
        XCTAssertFalse(r.reason.isEmpty, "\(ctx) Grund leer", file: file, line: line)
    }

    /// Zustand mit einem Programm (`claude.prog`) und einer Atemuebung (`claude.atem`) jeweils in `rev`, Gedaechtnis gefuellt.
    private func seeded(rev: Int = 1) throws -> ClaudeApplyState {
        let d = try delivery("seed-\(rev)", items: [programItem("claude.prog", rev: rev, name: "Alt-P"),
                                                    breathItem("claude.atem", rev: rev, name: "Alt-A")])
        let (state, result) = apply(d, to: empty(), lastSnapshotAt: nil, now: t(100))
        XCTAssertEqual(result, .applied)
        _ = try first(state.sets, "Programm im Ausgangszustand")
        _ = try first(state.presets, "Atemuebung im Ausgangszustand")
        return state
    }

    // MARK: - AC-1a Anlegen

    /// Verhalten: Ein Programm aus eingebauten Uebungen wird als eigenes Programm angelegt.
    func testAnlegenProgrammMitBuiltinAusBeispielsatz() throws {
        let d = try sampleDelivery("program-builtin.json")
        let (state, result) = apply(d, to: empty(), lastSnapshotAt: nil, now: now)
        XCTAssertEqual(result, .applied)
        XCTAssertEqual(state.sets.count, 1)
        XCTAssertTrue(state.presets.isEmpty)
        let set = try XCTUnwrap(state.sets.first)
        XCTAssertEqual(set.name, "Rücken A")
        XCTAssertEqual(set.emoji, "🧘")
        XCTAssertEqual(set.repetitions, 2)
        let expected: [(String, Int, Int, String?)] = [("builtin.glute-bridges", 40, 20, "12 Wiederholungen, langsam"),
                                                       ("builtin.planke", 30, 15, nil),
                                                       ("builtin.kindspose", 45, 0, "Ruhig ausatmen")]
        XCTAssertEqual(set.phases.count, expected.count)
        for (phase, e) in zip(set.phases, expected) {
            XCTAssertEqual(phase.exerciseId, e.0)
            XCTAssertEqual(phase.workDuration, e.1)
            XCTAssertEqual(phase.restDuration, e.2)
            XCTAssertEqual(phase.hint, e.3)
            XCTAssertEqual(phase.name, ExerciseDatabase.info(forId: e.0)?.name)
        }
        let origin = try XCTUnwrap(set.claude)
        XCTAssertEqual(origin.itemId, "claude.ruecken-a")
        XCTAssertEqual(origin.revision, 1)
        XCTAssertEqual(origin.why, d.why)
        XCTAssertNil(origin.packageId)
        XCTAssertEqual(origin.deliveredAt, d.createdAt)
        XCTAssertNil(set.modifiedAt)
        XCTAssertEqual(state.log.count, 1)
        XCTAssertEqual(state.log.first?.deliveryId, d.deliveryId)
        XCTAssertEqual(state.log.first?.result, .applied)
        XCTAssertEqual(state.log.first?.at, now)
    }

    /// Verhalten: Eine Atemuebung wird mit allen vier Zeiten als Atemuebung angelegt.
    func testAnlegenAtemuebungAusBeispielsatz() throws {
        let d = try sampleDelivery("breath.json")
        let (state, result) = apply(d, to: empty(), lastSnapshotAt: nil, now: now)
        XCTAssertEqual(result, .applied)
        XCTAssertTrue(state.sets.isEmpty)
        XCTAssertEqual(state.presets.count, 1)
        let p = try XCTUnwrap(state.presets.first)
        XCTAssertEqual(p.name, "Abendatem")
        XCTAssertEqual(p.emoji, "🌙")
        XCTAssertEqual(p.inhale, 4)
        XCTAssertEqual(p.holdIn, 2)
        XCTAssertEqual(p.exhale, 6)
        XCTAssertEqual(p.holdOut, 0)
        XCTAssertEqual(p.repetitions, 10)
        let origin = try XCTUnwrap(p.claude)
        XCTAssertEqual(origin.itemId, "claude.abendatem")
        XCTAssertEqual(origin.revision, 1)
        XCTAssertEqual(origin.why, d.why)
        XCTAssertEqual(origin.deliveredAt, d.createdAt)
        XCTAssertNil(p.modifiedAt)
        XCTAssertEqual(state.log.map(\.deliveryId), [d.deliveryId])
    }

    // MARK: - AC-3 Idempotenz

    /// Verhalten: Dieselbe Lieferung wirkt nur einmal; die zweite Anwendung gibt das gemerkte Ergebnis und aendert nichts.
    func testZweiteAnwendungLiefertGemerktesErgebnisUndAendertNichts() throws {
        let d = try sampleDelivery("breath.json")
        let (first, firstResult) = apply(d, to: empty(), lastSnapshotAt: nil, now: now)
        let (second, secondResult) = apply(d, to: first, lastSnapshotAt: t(5), now: now.addingTimeInterval(3600))
        XCTAssertEqual(firstResult, .applied)
        XCTAssertEqual(secondResult, firstResult)
        XCTAssertEqual(second, first)
        XCTAssertEqual(second.presets.count, 1)
        XCTAssertEqual(second.log.count, 1)
    }

    // MARK: - AC-4 Gedaechtnis

    /// Verhalten: Das Gedaechtnis behaelt hoechstens 50 Lieferungen; die aelteste faellt weg und wird neu bewertet.
    func testGedaechtnisBehaelt50UndVerwirftAelteste() throws {
        var state = empty()
        var deliveries: [ClaudeDelivery] = []
        for i in 0..<51 {
            let d = try delivery("d-\(i)", items: [breathItem("claude.item-\(i)", rev: 1)])
            deliveries.append(d)
            let (next, result) = apply(d, to: state, lastSnapshotAt: nil, now: t(1000 + Double(i)))
            XCTAssertEqual(result, .applied)
            state = next
        }
        XCTAssertEqual(state.log.count, 50)
        XCTAssertEqual(state.log.last?.deliveryId, "d-50")
        XCTAssertEqual(state.log.first?.deliveryId, "d-1")
        XCTAssertFalse(state.log.contains { $0.deliveryId == "d-0" })
        XCTAssertEqual(state.presets.count, 51)

        // Die herausgefallene erste Lieferung wird neu bewertet (Baustein steht schon da, gleiche Fassung: ohne Wirkung).
        let (again, result) = apply(deliveries[0], to: state, lastSnapshotAt: nil, now: t(5000))
        XCTAssertEqual(result, .noEffect)
        XCTAssertEqual(again.log.count, 50)
        XCTAssertEqual(again.log.last?.deliveryId, "d-0")
        XCTAssertEqual(again.log.last?.result, .noEffect)
        XCTAssertFalse(again.log.contains { $0.deliveryId == "d-1" })
    }

    // MARK: - AC-5 Ganz oder gar nicht

    /// Verhalten: Ein unbekannter eingebauter Verweis lehnt die ganze Lieferung ab; auch die anwendbare Atemuebung entsteht nicht.
    func testAblehnungLaesstBausteineUnveraendertUnbekannterBuiltinVerweis() throws {
        let before = try seeded()
        let d = try delivery("rej-1", items: [breathItem("claude.neu", rev: 1),
                                              programItem("claude.neu-p", rev: 1, steps: ["builtin.gibt-es-nicht"])])
        let (after, result) = apply(d, to: before, lastSnapshotAt: nil, now: now)
        assertRejected(result, "EXERCISE_UNKNOWN")
        XCTAssertEqual(after.sets, before.sets)
        XCTAssertEqual(after.presets, before.presets)
        XCTAssertEqual(after.log.count, before.log.count + 1)
        XCTAssertEqual(after.log.last?.deliveryId, "rej-1")
        XCTAssertEqual(after.log.last?.result, result)

        let (fromEmpty, _) = apply(d, to: empty(), lastSnapshotAt: nil, now: now)
        XCTAssertTrue(fromEmpty.presets.isEmpty)
        XCTAssertTrue(fromEmpty.sets.isEmpty)
        XCTAssertEqual(fromEmpty.log.count, 1)
    }

    /// Verhalten: Ein nach der Abschrift geaenderter Baustein an zweiter Stelle lehnt die ganze Lieferung ab.
    func testAblehnungLaesstBausteineUnveraendertChangedOnIphone() throws {
        var before = try seeded()
        before.presets[0].modifiedAt = t(2000)
        let d = try delivery("rej-2", items: [breathItem("claude.neu", rev: 1),
                                              breathItem("claude.atem", rev: 2, name: "Neu-A")])
        let (after, result) = apply(d, to: before, lastSnapshotAt: t(1000), now: now)
        assertRejected(result, "CHANGED_ON_IPHONE")
        XCTAssertEqual(after.sets, before.sets)
        XCTAssertEqual(after.presets, before.presets)
        XCTAssertEqual(after.presets.count, 1, "die anwendbare erste Position darf nicht angelegt sein")
        XCTAssertEqual(after.log.count, before.log.count + 1)
        XCTAssertEqual(after.log.last?.deliveryId, "rej-2")
        XCTAssertEqual(after.log.last?.result, result)
    }

    /// Verhalten: Eine abgelehnte Lieferung, erneut gesendet, liefert das gemerkte Ablehnen und aendert nichts.
    func testZweiteAnwendungEinerAbgelehntenLieferungLiefertGemerktesRejected() throws {
        let d = try delivery("rej-3", items: [programItem("claude.x", rev: 1, steps: ["builtin.gibt-es-nicht"])])
        let (first, firstResult) = apply(d, to: empty(), lastSnapshotAt: nil, now: now)
        assertRejected(firstResult, "EXERCISE_UNKNOWN")
        let (second, secondResult) = apply(d, to: first, lastSnapshotAt: t(777), now: now.addingTimeInterval(60))
        assertRejected(secondResult, "EXERCISE_UNKNOWN", "zweite Anwendung")
        XCTAssertEqual(second, first)
        XCTAssertEqual(second.log.count, 1)
    }

    // MARK: - AC-6a, AC-7 Revisionen

    /// Verhalten: Eine hoehere Fassung ersetzt Programm und Atemuebung, behaelt die lokale Kennung und setzt die Herkunft neu.
    func testHoehereRevisionErsetztMitGleicherUUID() throws {
        let before = try seeded()
        let d = try delivery("upd-1", items: [
            programItem("claude.prog", rev: 2, name: "Neu-P", rounds: 5, steps: ["builtin.planke", "builtin.kindspose"]),
            breathItem("claude.atem", rev: 2, name: "Neu-A", inhale: 5, rounds: 7)],
            why: "Neuer Grund", package: ("pkg-2", "Paket Zwei"), createdAt: "2026-12-01T08:00:00Z")
        let (after, result) = apply(d, to: before, lastSnapshotAt: nil, now: now)
        XCTAssertEqual(result, .applied)
        XCTAssertEqual(after.sets.count, 1)
        XCTAssertEqual(after.presets.count, 1)
        let set = try first(after.sets, "Programm"), preset = try first(after.presets, "Atemuebung")
        XCTAssertEqual(set.id, try first(before.sets).id)
        XCTAssertEqual(preset.id, try first(before.presets).id)
        XCTAssertEqual(set.name, "Neu-P")
        XCTAssertEqual(set.repetitions, 5)
        XCTAssertEqual(set.phases.count, 2)
        XCTAssertEqual(preset.name, "Neu-A")
        XCTAssertEqual(preset.inhale, 5)
        XCTAssertEqual(preset.repetitions, 7)
        for origin in [set.claude, preset.claude] {
            XCTAssertEqual(origin?.revision, 2)
            XCTAssertEqual(origin?.why, "Neuer Grund")
            XCTAssertEqual(origin?.packageId, "pkg-2")
            XCTAssertEqual(origin?.packageName, "Paket Zwei")
            XCTAssertEqual(origin?.deliveredAt, d.createdAt)
        }
        XCTAssertNil(set.modifiedAt)
        XCTAssertNil(preset.modifiedAt)
    }

    /// Verhalten: Gleiche oder niedrigere Fassung aendert nichts, auch bei geaendertem Baustein; das Ergebnis wird gemerkt.
    func testGleicheOderNiedrigereRevisionOhneWirkungUndWirdGemerkt() throws {
        let before = try seeded(rev: 2)
        for rev in [2, 1] {
            let d = try delivery("same-\(rev)", items: [programItem("claude.prog", rev: rev, name: "Anders"),
                                                         breathItem("claude.atem", rev: rev, name: "Anders")])
            let (after, result) = apply(d, to: before, lastSnapshotAt: nil, now: now)
            XCTAssertEqual(result, .noEffect, "revision \(rev)")
            XCTAssertEqual(after.sets, before.sets)
            XCTAssertEqual(after.presets, before.presets)
            XCTAssertEqual(after.log.last?.deliveryId, "same-\(rev)")
            XCTAssertEqual(after.log.last?.result, .noEffect)
            let (again, againResult) = apply(d, to: after, lastSnapshotAt: nil, now: now.addingTimeInterval(10))
            XCTAssertEqual(againResult, .noEffect)
            XCTAssertEqual(again, after, "revision \(rev)")
        }
        // Auch mit gesetztem modifiedAt und unbekannter Abschrift: ohne Wirkung statt Ablehnung.
        var changed = before
        changed.sets[0].modifiedAt = t(2000)
        changed.presets[0].modifiedAt = t(2000)
        let d = try delivery("same-mod", items: [programItem("claude.prog", rev: 2), breathItem("claude.atem", rev: 1)])
        let (after, result) = apply(d, to: changed, lastSnapshotAt: nil, now: now)
        XCTAssertEqual(result, .noEffect)
        XCTAssertEqual(after.sets, changed.sets)
        XCTAssertEqual(after.presets, changed.presets)
    }

    // MARK: - AC-8a Das iPhone gewinnt

    /// Verhalten: Hat Henning nach der Abschrift (oder ohne Abschrift) geaendert, wird das Ersetzen abgelehnt.
    func testChangedOnIphoneBeiModifiedAtNachAbschriftOderAbschriftNil() throws {
        for kind in ["program", "breath"] {
            for snapshot: Date? in [t(500), nil] {
                var before = try seeded()
                before.sets[0].modifiedAt = t(1000)
                before.presets[0].modifiedAt = t(1000)
                let item = kind == "program" ? programItem("claude.prog", rev: 2, name: "Neu")
                                             : breathItem("claude.atem", rev: 2, name: "Neu")
                let d = try delivery("chg-\(kind)-\(snapshot == nil ? "nil" : "t")", items: [item])
                let (after, result) = apply(d, to: before, lastSnapshotAt: snapshot, now: now)
                assertRejected(result, "CHANGED_ON_IPHONE", "\(kind) \(String(describing: snapshot))")
                XCTAssertEqual(after.sets, before.sets)
                XCTAssertEqual(after.presets, before.presets)
                XCTAssertEqual(after.log.last?.result, result)
            }
        }
    }

    /// Verhalten: War die Aenderung schon in der Abschrift (oder gar nicht vorhanden), wird ersetzt.
    func testModifiedAtVorOderGleichAbschriftOderNilBlockiertNicht() throws {
        let cases: [(modified: Date?, snapshot: Date?)] = [(t(1000), t(2000)), (t(1000), t(1000)), (nil, nil), (nil, t(10))]
        for (index, c) in cases.enumerated() {
            for kind in ["program", "breath"] {
                var before = try seeded()
                before.sets[0].modifiedAt = c.modified
                before.presets[0].modifiedAt = c.modified
                let item = kind == "program" ? programItem("claude.prog", rev: 2, name: "Neu")
                                             : breathItem("claude.atem", rev: 2, name: "Neu")
                let d = try delivery("ok-\(kind)-\(index)", items: [item])
                let (after, result) = apply(d, to: before, lastSnapshotAt: c.snapshot, now: now)
                XCTAssertEqual(result, .applied, "\(kind) Fall \(index)")
                let name = kind == "program" ? try first(after.sets, kind).name : try first(after.presets, kind).name
                XCTAssertEqual(name, "Neu", "\(kind) Fall \(index)")
                XCTAssertEqual(kind == "program" ? try first(after.sets, kind).claude?.revision : try first(after.presets, kind).claude?.revision, 2)
            }
        }
    }

    // MARK: - AC-13a Namensaufloesung

    /// Verhalten: Schritte mit eingebauter Kennung tragen den deutschen Katalognamen.
    func testBuiltinVerweisNutztKatalogNamen() throws {
        let d = try delivery("names", items: [programItem("claude.n", rev: 1, steps: ["builtin.planke", "builtin.kindspose"])])
        let (state, result) = apply(d, to: empty(), lastSnapshotAt: nil, now: now)
        XCTAssertEqual(result, .applied)
        let names = try first(state.sets, "Programm").phases.map(\.name)
        let planke = try XCTUnwrap(ExerciseDatabase.info(forId: "builtin.planke")?.name)
        let kind = try XCTUnwrap(ExerciseDatabase.info(forId: "builtin.kindspose")?.name)
        XCTAssertEqual(names, [planke, kind])
        XCTAssertFalse(planke.isEmpty)
        XCTAssertNotEqual(planke, "builtin.planke")
    }

    /// Verhalten: In dieser Runde ist ein eigener oder von Claude gelieferter Verweis nicht aufloesbar und lehnt ab.
    func testProgrammMitOwnOderClaudeVerweisLehntMitExerciseUnknownAb() throws {
        var base = empty()
        base.sets = [WorkoutSet(name: "Vorhanden", emoji: "💪", phases: [
            WorkoutPhase(name: "Eigene", workDuration: 30, restDuration: 10, exerciseId: "own.x")], repetitions: 1)]
        for ref in ["own.x", "claude.y"] {
            let d = try delivery("ref-\(ref)", items: [programItem("claude.p", rev: 1, steps: ["builtin.planke", ref])])
            let (after, result) = apply(d, to: base, lastSnapshotAt: nil, now: now)
            assertRejected(result, "EXERCISE_UNKNOWN", ref)
            XCTAssertEqual(after.sets, base.sets)
            XCTAssertEqual(after.presets, base.presets)
            XCTAssertEqual(after.log.last?.result, result)
        }
    }

    // MARK: - AC-14 Von Henning geloescht

    /// Verhalten: Hat Henning einen gelieferten Baustein geloescht, legt eine hoehere Fassung ihn neu an.
    func testGeloeschterBausteinWirdBeiHoehererFassungNeuAngelegt() throws {
        let first = try delivery("del-1", items: [programItem("claude.del", rev: 1)])
        var (state, _) = apply(first, to: empty(), lastSnapshotAt: nil, now: now)
        let oldId = try self.first(state.sets, "Programm").id
        state.sets.removeAll()

        let second = try delivery("del-2", items: [programItem("claude.del", rev: 2, name: "Zurueck")])
        let (after, result) = apply(second, to: state, lastSnapshotAt: nil, now: now)
        XCTAssertEqual(result, .applied)
        XCTAssertEqual(after.sets.count, 1)
        let recreated = try self.first(after.sets, "neues Programm")
        XCTAssertNotEqual(recreated.id, oldId)
        XCTAssertNil(recreated.modifiedAt)
        XCTAssertEqual(recreated.claude?.revision, 2)

        // Dieselbe deliveryId wie die erste Lieferung: gemerktes Ergebnis, nichts angelegt.
        let (repeated, repeatedResult) = apply(first, to: state, lastSnapshotAt: nil, now: now)
        XCTAssertEqual(repeatedResult, .applied)
        XCTAssertEqual(repeated, state)
        XCTAssertTrue(repeated.sets.isEmpty)
    }

    /// Verhalten: Auch bei gleicher Fassung und neuer Lieferung wird ein geloeschter Baustein neu angelegt.
    func testGeloeschterBausteinWirdBeiGleicherFassungUndNeuerLieferungNeuAngelegt() throws {
        let first = try delivery("del-a", items: [breathItem("claude.del", rev: 1)])
        var (state, _) = apply(first, to: empty(), lastSnapshotAt: nil, now: now)
        let oldId = try self.first(state.presets, "Atemuebung").id
        state.presets.removeAll()

        let again = try delivery("del-b", items: [breathItem("claude.del", rev: 1)])
        let (after, result) = apply(again, to: state, lastSnapshotAt: nil, now: now)
        XCTAssertEqual(result, .applied)
        XCTAssertEqual(after.presets.count, 1)
        let recreated = try self.first(after.presets, "neue Atemuebung")
        XCTAssertNotEqual(recreated.id, oldId)
        XCTAssertNil(recreated.modifiedAt)
        XCTAssertEqual(recreated.claude?.revision, 1)
    }

    // MARK: - AC-15 Alt-JSON

    /// Verhalten: Gespeicherte Programme und Atemuebungen von frueher bleiben lesbar; die neuen Felder sind leer.
    func testAltJsonWorkoutSetUndPresetLiestSichOhneNeueFelderUndRoundTrip() throws {
        let setJson = """
        [{"id":"11111111-1111-1111-1111-111111111111","name":"Alt","emoji":"💪","repetitions":3,
          "description":"Text","phases":[{"id":"22222222-2222-2222-2222-222222222222","name":"Planke",
          "workDuration":30,"restDuration":10}]}]
        """
        let presetJson = """
        [{"id":"33333333-3333-3333-3333-333333333333","name":"Alt-Atem","emoji":"🧘","inhale":4,"holdIn":1,
          "exhale":6,"holdOut":2,"repetitions":8}]
        """
        let sets = try JSONDecoder().decode([WorkoutSet].self, from: Data(setJson.utf8))
        let presets = try JSONDecoder().decode([AtemView.Preset].self, from: Data(presetJson.utf8))
        XCTAssertEqual(sets.count, 1)
        _ = try first(sets, "Programm")
        _ = try first(presets, "Atemuebung")
        XCTAssertEqual(sets[0].id, UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        XCTAssertEqual(sets[0].name, "Alt")
        XCTAssertEqual(sets[0].emoji, "💪")
        XCTAssertEqual(sets[0].repetitions, 3)
        XCTAssertEqual(sets[0].description, "Text")
        XCTAssertEqual(sets[0].phases.map(\.name), ["Planke"])
        XCTAssertEqual(sets[0].phases.map(\.workDuration), [30])
        XCTAssertEqual(sets[0].phases.map(\.restDuration), [10])
        XCTAssertNil(sets[0].claude)
        XCTAssertNil(sets[0].modifiedAt)
        XCTAssertEqual(presets.count, 1)
        XCTAssertEqual(presets[0].name, "Alt-Atem")
        XCTAssertEqual(presets[0].emoji, "🧘")
        XCTAssertEqual([presets[0].inhale, presets[0].holdIn, presets[0].exhale, presets[0].holdOut, presets[0].repetitions],
                       [4, 1, 6, 2, 8])
        XCTAssertNil(presets[0].claude)
        XCTAssertNil(presets[0].modifiedAt)

        // Round-Trip mit gesetzten Feldern.
        let origin = ClaudeOrigin(itemId: "claude.x", revision: 3, why: "Grund", packageId: "pkg", packageName: "Paket",
                                  deliveredAt: t(1_700_000_000))
        var set = sets[0]; set.claude = origin; set.modifiedAt = t(1_700_000_500)
        var preset = presets[0]; preset.claude = origin; preset.modifiedAt = t(1_700_000_500)
        let setBack = try JSONDecoder().decode([WorkoutSet].self, from: try JSONEncoder().encode([set]))
        let presetBack = try JSONDecoder().decode([AtemView.Preset].self, from: try JSONEncoder().encode([preset]))
        _ = try first(setBack, "Programm nach Round-Trip")
        _ = try first(presetBack, "Atemuebung nach Round-Trip")
        XCTAssertEqual(setBack, [set])
        XCTAssertEqual(presetBack, [preset])
        XCTAssertEqual(setBack[0].claude, origin)
        XCTAssertEqual(presetBack[0].modifiedAt, t(1_700_000_500))
    }

    // MARK: - AC-22 Reihenfolge der Ablehnung

    /// Verhalten: Die erste ablehnende Position bestimmt den Code.
    func testErsteAblehnendePositionBestimmtDenCode() throws {
        var before = try seeded()
        before.presets[0].modifiedAt = t(1000)
        let unknown = programItem("claude.u", rev: 1, steps: ["builtin.gibt-es-nicht"])
        let changed = breathItem("claude.atem", rev: 2, name: "Neu")

        let a = try delivery("order-a", items: [unknown, changed])
        let (afterA, resultA) = apply(a, to: before, lastSnapshotAt: t(500), now: now)
        assertRejected(resultA, "EXERCISE_UNKNOWN", "unbekannt zuerst")
        XCTAssertEqual(afterA.sets, before.sets)
        XCTAssertEqual(afterA.presets, before.presets)

        let b = try delivery("order-b", items: [changed, unknown])
        let (afterB, resultB) = apply(b, to: before, lastSnapshotAt: t(500), now: now)
        assertRejected(resultB, "CHANGED_ON_IPHONE", "geaendert zuerst")
        XCTAssertEqual(afterB.sets, before.sets)
        XCTAssertEqual(afterB.presets, before.presets)
    }

    // MARK: - AC-20 Zwischenstand (befristet)

    /// Verhalten (befristet, entfaellt in 2a-2): Eine Uebungslieferung wird als ganze abgelehnt, KIND_NOT_SUPPORTED.
    func testUebungslieferungNochNichtUnterstuetzt() throws {
        let d = try delivery("kind-ex", items: [breathItem("claude.neu", rev: 1), exerciseItem("claude.ex")])
        let (after, result) = apply(d, to: empty(), lastSnapshotAt: nil, now: now)
        assertRejected(result, "KIND_NOT_SUPPORTED")
        XCTAssertTrue(after.presets.isEmpty)
        XCTAssertTrue(after.sets.isEmpty)
        XCTAssertEqual(after.log.count, 1)
        XCTAssertEqual(after.log.first?.deliveryId, "kind-ex")
        XCTAssertEqual(after.log.first?.result, result)
    }

    /// Verhalten (befristet, entfaellt in 2a-3): Eine Ruecknahme wird als ganze Lieferung abgelehnt, KIND_NOT_SUPPORTED.
    func testRuecknahmeNochNichtUnterstuetzt() throws {
        let before = try seeded()
        let d = try delivery("kind-wd", items: [breathItem("claude.neu", rev: 1),
                                                ["kind": "withdrawal", "itemId": "claude.atem"]])
        let (after, result) = apply(d, to: before, lastSnapshotAt: nil, now: now)
        assertRejected(result, "KIND_NOT_SUPPORTED")
        XCTAssertEqual(after.sets, before.sets)
        XCTAssertEqual(after.presets, before.presets)
        XCTAssertEqual(after.log.count, before.log.count + 1)
        XCTAssertEqual(after.log.last?.deliveryId, "kind-wd")
        XCTAssertEqual(after.log.last?.result, result)
    }
}
