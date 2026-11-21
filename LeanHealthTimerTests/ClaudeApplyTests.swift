//
//  ClaudeApplyTests.swift
//  LeanHealthTimerTests
//
//  TDD RED #51 Schnitt 2a, Runde 2a-1: Anwende-Logik fuer Lieferungen von Claude (Programme, Atemuebungen).
//  Runde 2a-2: Uebungen (exercise) anwenden, own./claude.-Verweise aufloesen, Kategorie-Abbildung.
//  Rundenspec: DOCS/specs/features/feature-51-s2a2-uebungen.md
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

    private func empty() -> ClaudeApplyState { ClaudeApplyState(sets: [], presets: [], exercises: [], log: []) }

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

    private func exerciseItem(_ id: String, rev: Int = 1, name: String = "Vierfuessler",
                              category: String = "core") -> Json {
        ["kind": "exercise", "itemId": id, "revision": rev, "name": name, "category": category,
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

    // MARK: - Runde 2a-2: Uebungen

    /// Zustand mit einer von Claude gelieferten Uebung (ueber eine fruehere Lieferung angelegt).
    private func stateWithExercise(_ id: String = "claude.ex", rev: Int = 1, name: String = "Aus Zustand",
                                   category: String = "core", base: ClaudeApplyState? = nil) throws -> ClaudeApplyState {
        let d = try delivery("ex-seed-\(id)-\(rev)", items: [exerciseItem(id, rev: rev, name: name, category: category)])
        let (state, result) = apply(d, to: base ?? empty(), lastSnapshotAt: nil, now: t(100))
        XCTAssertEqual(result, .applied)
        _ = try first(state.exercises, "Uebung im Ausgangszustand")
        return state
    }

    /// Verhalten: Eine neue Uebung samt Programm, das sie verwendet, wird angelegt; die Phase traegt Namen und Hinweis.
    func testAnlegenUebungUndProgrammAusBeispielsatz() throws {
        let d = try sampleDelivery("exercise-and-program.json")
        let (state, result) = apply(d, to: empty(), lastSnapshotAt: nil, now: now)
        XCTAssertEqual(result, .applied)
        XCTAssertEqual(state.exercises.count, 1)
        let ex = try first(state.exercises, "Uebung")
        XCTAssertEqual(ex.name, "Vierfüßler diagonal")
        XCTAssertEqual(ex.nameEn, "Bird Dog")
        XCTAssertEqual(ex.category, "core", "gespeichert wird der englische Text")
        XCTAssertEqual(ex.claude.itemId, "claude.vierfuessler-diagonal")
        XCTAssertEqual(ex.claude.revision, 1)
        XCTAssertEqual(ex.claude.why, d.why)
        XCTAssertEqual(ex.claude.deliveredAt, d.createdAt)
        XCTAssertTrue(ex.effect.hasPrefix("Stärkt die tiefe Rückenmuskulatur"))
        XCTAssertTrue(ex.instructions.hasPrefix("1) Vierfüßlerstand"))
        XCTAssertEqual(state.sets.count, 1)
        let set = try first(state.sets, "Programm")
        XCTAssertEqual(set.phases.count, 2)
        let p0 = try first(set.phases, "erste Phase")
        XCTAssertEqual(p0.exerciseId, "claude.vierfuessler-diagonal")
        XCTAssertEqual(p0.name, "Vierfüßler diagonal")
        XCTAssertEqual(p0.hint, "Je Seite 8 Mal")
        let p1 = try XCTUnwrap(set.phases.dropFirst().first, "zweite Phase fehlt")
        XCTAssertEqual(p1.exerciseId, "builtin.glute-bridges")
        XCTAssertEqual(p1.name, ExerciseDatabase.info(forId: "builtin.glute-bridges")?.name)
        XCTAssertEqual(state.log.map(\.deliveryId), [d.deliveryId])
        XCTAssertEqual(state.log.first?.result, .applied)
    }

    /// Verhalten: Eine hoehere Fassung ersetzt die Uebung; die Anzahl bleibt, die Revision steigt.
    func testHoehereRevisionErsetztUebung() throws {
        let before = try stateWithExercise("claude.ex", rev: 1, name: "Erst")
        var item = exerciseItem("claude.ex", rev: 2, name: "Zweit")
        item["effect"] = "Neuer Effekt"
        let d = try delivery("ex-upd", items: [item])
        let (after, result) = apply(d, to: before, lastSnapshotAt: nil, now: now)
        XCTAssertEqual(result, .applied)
        XCTAssertEqual(after.exercises.count, 1)
        let ex = try first(after.exercises, "Uebung")
        XCTAssertEqual(ex.name, "Zweit")
        XCTAssertEqual(ex.effect, "Neuer Effekt")
        XCTAssertEqual(ex.claude.revision, 2)
        XCTAssertEqual(ex.claude.itemId, "claude.ex")
    }

    /// Verhalten: Gleiche oder niedrigere Fassung aendert an der Uebung nichts; das Ergebnis wird gemerkt.
    func testUebungGleicheOderNiedrigereRevisionOhneWirkung() throws {
        let before = try stateWithExercise("claude.ex", rev: 2, name: "Bleibt", base: try seeded())
        for rev in [2, 1] {
            let d = try delivery("ex-same-\(rev)", items: [exerciseItem("claude.ex", rev: rev, name: "Anders")])
            let (after, result) = apply(d, to: before, lastSnapshotAt: nil, now: now)
            XCTAssertEqual(result, .noEffect, "revision \(rev)")
            XCTAssertEqual(after.exercises, before.exercises)
            XCTAssertEqual(after.sets, before.sets)
            XCTAssertEqual(after.presets, before.presets)
            XCTAssertEqual(after.log.last?.deliveryId, "ex-same-\(rev)")
            XCTAssertEqual(after.log.last?.result, .noEffect)
        }
    }

    /// Verhalten: Ein own.-Verweis bekommt den Namen der gleichen Phase aus einem vorhandenen Programm.
    func testOwnVerweisLoestNamenAusVorhandenerPhaseAuf() throws {
        var base = empty()
        base.sets = [WorkoutSet(name: "Vorhanden", emoji: "💪", phases: [
            WorkoutPhase(name: "Eigene", workDuration: 30, restDuration: 10, exerciseId: "own.x")], repetitions: 1)]
        let d = try delivery("own-1", items: [programItem("claude.p", rev: 1, steps: ["own.x"])])
        let (after, result) = apply(d, to: base, lastSnapshotAt: nil, now: now)
        XCTAssertEqual(result, .applied)
        let created = try XCTUnwrap(after.sets.first { $0.claude?.itemId == "claude.p" }, "neues Programm fehlt")
        XCTAssertEqual(created.phases.map(\.name), ["Eigene"])
        XCTAssertEqual(created.phases.map(\.exerciseId), ["own.x"])

        // Beleg ueber den Beispielsatz.
        var base2 = empty()
        base2.sets = [WorkoutSet(name: "Vorhanden", emoji: "💪", phases: [
            WorkoutPhase(name: "Schulterkreisen", workDuration: 30, restDuration: 10,
                         exerciseId: "own.7d3e9c1a-52b4-4f08-8e6a-0c9b1d2e3f45")], repetitions: 1)]
        let sample = try sampleDelivery("own-exercise-reference.json")
        let (after2, result2) = apply(sample, to: base2, lastSnapshotAt: nil, now: now)
        XCTAssertEqual(result2, .applied)
        let prog = try XCTUnwrap(after2.sets.first { $0.claude?.itemId == "claude.ruecken-a" }, "Programm Ruecken A fehlt")
        XCTAssertEqual(prog.name, "Rücken A")
        XCTAssertEqual(prog.phases.map(\.name), ["Schulterkreisen"])
    }

    /// Verhalten: Ein own.-Verweis ohne passende Phase im Zustand lehnt die Lieferung ab; nichts aendert sich.
    func testOwnVerweisOhnePhaseLehntMitExerciseUnknownAb() throws {
        let before = try stateWithExercise(base: try seeded())
        let d = try delivery("own-2", items: [programItem("claude.p", rev: 1, steps: ["builtin.planke", "own.gibt-es-nicht"])])
        let (after, result) = apply(d, to: before, lastSnapshotAt: nil, now: now)
        assertRejected(result, "EXERCISE_UNKNOWN")
        XCTAssertEqual(after.sets, before.sets)
        XCTAssertEqual(after.presets, before.presets)
        XCTAssertEqual(after.exercises, before.exercises)
        XCTAssertEqual(after.log.count, before.log.count + 1)
        XCTAssertEqual(after.log.last?.deliveryId, "own-2")
        XCTAssertEqual(after.log.last?.result, result)
    }

    /// Verhalten: Ein claude.-Verweis nimmt den Namen aus der Lieferung (auch wenn die Uebung nach dem Programm steht), sonst aus dem Zustand.
    func testClaudeVerweisNutztLieferungOderZustand() throws {
        // (a) Uebung steht in der Lieferung erst nach dem Programm.
        let sample = try sampleDelivery("program-before-exercise.json")
        let (stateA, resultA) = apply(sample, to: empty(), lastSnapshotAt: nil, now: now)
        XCTAssertEqual(resultA, .applied)
        XCTAssertEqual(try first(stateA.sets, "Programm").phases.map(\.name), ["Vierfüßler diagonal"])
        XCTAssertEqual(stateA.exercises.count, 1)
        XCTAssertEqual(try first(stateA.exercises, "Uebung").claude.itemId, "claude.vierfuessler-diagonal")

        // (b) Uebung stammt aus einer frueheren Lieferung im Zustand.
        let beforeB = try stateWithExercise("claude.ex", rev: 1, name: "Aus Zustand")
        let dB = try delivery("claude-ref-b", items: [programItem("claude.p", rev: 1, steps: ["claude.ex"])])
        let (stateB, resultB) = apply(dB, to: beforeB, lastSnapshotAt: nil, now: now)
        XCTAssertEqual(resultB, .applied)
        XCTAssertEqual(try first(stateB.sets, "Programm").phases.map(\.name), ["Aus Zustand"])
        XCTAssertEqual(stateB.exercises, beforeB.exercises)

        // (c) Randfall: Uebung der Lieferung ohne Wirkung (gleiche Revision), Name aus der Lieferung fuer die Phase.
        let beforeC = try stateWithExercise("claude.ex", rev: 2, name: "Alt")
        let dC = try delivery("claude-ref-c", items: [exerciseItem("claude.ex", rev: 2, name: "Neu"),
                                                      programItem("claude.p", rev: 1, steps: ["claude.ex"])])
        let (stateC, resultC) = apply(dC, to: beforeC, lastSnapshotAt: nil, now: now)
        XCTAssertEqual(resultC, .applied)
        let exC = try first(stateC.exercises, "Uebung")
        XCTAssertEqual(exC.name, "Alt")
        XCTAssertEqual(exC.claude.revision, 2)
        XCTAssertEqual(try first(stateC.sets, "Programm").phases.map(\.name), ["Neu"])
    }

    /// Verhalten: Ein claude.-Verweis, den weder Lieferung noch Zustand kennt, lehnt ab; Bausteine bleiben.
    func testClaudeVerweisUnbekanntLehntAb() throws {
        let before = try stateWithExercise(base: try seeded())
        let d = try delivery("claude-unk", items: [breathItem("claude.neu", rev: 1),
                                                   programItem("claude.p", rev: 1, steps: ["claude.gibt-es-nicht"])])
        let (after, result) = apply(d, to: before, lastSnapshotAt: nil, now: now)
        assertRejected(result, "EXERCISE_UNKNOWN")
        XCTAssertEqual(after.sets, before.sets)
        XCTAssertEqual(after.presets, before.presets)
        XCTAssertEqual(after.exercises, before.exercises)
        XCTAssertEqual(after.log.last?.deliveryId, "claude-unk")
        XCTAssertEqual(after.log.last?.result, result)
    }

    /// Verhalten: Alle neun englischen Kategorien werden auf den deutschen Fall abgebildet; gespeichert wird der englische Text.
    func testAlleNeunKategorienWerdenAbgebildet() throws {
        let table: [(en: String, de: String, expected: ExerciseCategory)] = [
            ("strength", "Kraft", .strength), ("stretching", "Dehnung", .stretching), ("core", "Core", .core),
            ("cardio", "Cardio", .cardio), ("legs", "Beine", .legs), ("upperBody", "Oberkörper", .upperBody),
            ("fullBody", "Ganzkörper", .fullBody), ("warmup", "Aufwärmen", .warmup), ("cooldown", "Cool-Down", .cooldown)]
        XCTAssertEqual(table.count, ExerciseCategory.allCases.count, "Tabelle muss alle Kategorien abdecken")
        XCTAssertEqual(Set(table.map(\.de)), Set(ExerciseCategory.allCases.map(\.rawValue)))
        for row in table {
            let mapped = mapCategory(row.en)
            XCTAssertEqual(mapped, row.expected, row.en)
            XCTAssertEqual(mapped?.rawValue, row.de, row.en)

            let d = try delivery("cat-\(row.en)", items: [exerciseItem("claude.cat", category: row.en)])
            let (state, result) = apply(d, to: empty(), lastSnapshotAt: nil, now: now)
            XCTAssertEqual(result, .applied, row.en)
            XCTAssertEqual(state.exercises.first?.category, row.en, row.en)
        }
        XCTAssertNil(mapCategory("Kraft"))
        XCTAssertNil(mapCategory("unbekannt"))
    }

    /// Verhalten: Eine unbekannte Kategorie lehnt die ganze Lieferung ab, auch wenn die Position sonst ohne Wirkung waere.
    func testUnbekannteKategorieLehntMitCategoryUnknownAb() throws {
        // (a) ganze Lieferung wird abgelehnt, nichts uebernommen.
        let before = try seeded()
        let d = try delivery("cat-unk", items: [breathItem("claude.neu", rev: 1),
                                                exerciseItem("claude.ex", category: "unbekannt")])
        let (after, result) = apply(d, to: before, lastSnapshotAt: nil, now: now)
        assertRejected(result, "CATEGORY_UNKNOWN")
        XCTAssertEqual(after.presets, before.presets)
        XCTAssertEqual(after.sets, before.sets)
        XCTAssertEqual(after.exercises, before.exercises)
        XCTAssertEqual(after.log.count, before.log.count + 1)
        XCTAssertEqual(after.log.last?.deliveryId, "cat-unk")
        XCTAssertEqual(after.log.last?.result, result)

        // (b) gleiche Revision wie gespeichert: trotzdem Ablehnung, nicht noEffect.
        let stored = try stateWithExercise("claude.ex", rev: 1, name: "Gespeichert", category: "core")
        let d2 = try delivery("cat-unk-same", items: [exerciseItem("claude.ex", rev: 1, category: "unbekannt")])
        let (after2, result2) = apply(d2, to: stored, lastSnapshotAt: nil, now: now)
        assertRejected(result2, "CATEGORY_UNKNOWN", "gleiche Revision")
        XCTAssertEqual(after2.exercises, stored.exercises)
        XCTAssertEqual(after2.log.last?.result, result2)
    }

    // MARK: - Runde 2a-3: Ruecknahme

    private func withdrawal(item: String? = nil, package: String? = nil) -> Json {
        var j: Json = ["kind": "withdrawal"]
        if let item { j["itemId"] = item }
        if let package { j["packageId"] = package }
        return j
    }

    /// Wendet eine Vorbereitungs-Lieferung an und prueft, dass sie wirkt.
    private func applied(_ items: [Json], to state: ClaudeApplyState, id: String,
                         package: (String, String)? = nil) throws -> ClaudeApplyState {
        let d = try delivery(id, items: items, package: package)
        let (next, result) = apply(d, to: state, lastSnapshotAt: nil, now: t(100))
        XCTAssertEqual(result, .applied, "Vorbereitung \(id)")
        return next
    }

    private func ownSet(_ name: String = "Eigenes", exerciseId: String? = nil, modifiedAt: Date? = nil) -> WorkoutSet {
        var s = WorkoutSet(name: name, emoji: "💪", phases: [
            WorkoutPhase(name: "Phase", workDuration: 30, restDuration: 10, exerciseId: exerciseId)], repetitions: 1)
        s.modifiedAt = modifiedAt
        return s
    }

    private func ownPreset(_ name: String = "Eigener Atem", modifiedAt: Date? = nil) -> AtemView.Preset {
        AtemView.Preset(name: name, emoji: "🧘", inhale: 4, holdIn: 0, exhale: 6, holdOut: 0, repetitions: 5,
                        modifiedAt: modifiedAt)
    }

    private struct RawSample { let name: String; let delivery: Json; let context: Json? }

    private func rawSamples(file: StaticString = #filePath) throws -> [RawSample] {
        let dir = URL(fileURLWithPath: "\(file)").deletingLastPathComponent()
            .appendingPathComponent("../Contracts/deliveries/valid").standardized
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".json") }.sorted()
        return try names.map { name in
            let data = try Data(contentsOf: dir.appendingPathComponent(name))
            let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? Json, name)
            let delivery = try XCTUnwrap(root["delivery"] as? Json, "\(name): delivery fehlt")
            return RawSample(name: name, delivery: delivery, context: root["context"] as? Json)
        }
    }

    /// Verhalten: Jede lesbare Beispiellieferung laesst sich anwenden, ohne Absturz und nie abgelehnt (auch keine Ruecknahme).
    func testAlleLesbarenBeispieleLassenSichAnwenden() throws {
        var count = 0
        for s in try rawSamples() {
            guard let d = try? ClaudeDelivery.read(try JSONSerialization.data(withJSONObject: s.delivery)) else { continue }
            count += 1
            var state = empty()
            let known = (s.context?["knownExercises"] as? [Json]) ?? []
            for k in known {
                guard let id = k["id"] as? String, let name = k["name"] as? String else { continue }
                if id.hasPrefix("claude.") {
                    state.exercises.append(ClaudeStoredExercise(
                        id: UUID(), name: name, nameEn: nil, category: "core", effect: "Effekt", instructions: "Anleitung",
                        notes: nil, claude: ClaudeOrigin(itemId: id, revision: 1, why: "Test", packageId: nil,
                                                         packageName: nil, deliveredAt: t(50))))
                } else if id.hasPrefix("own.") {
                    state.sets.append(WorkoutSet(name: "Eigenes \(id)", emoji: "💪", phases: [
                        WorkoutPhase(name: name, workDuration: 30, restDuration: 10, exerciseId: id)], repetitions: 1))
                }
            }
            let (_, result) = apply(d, to: state, lastSnapshotAt: nil, now: now)
            if case .rejected(let code, let reason) = result {
                XCTFail("\(s.name) abgelehnt: \(code) \(reason)")
            }
        }
        XCTAssertGreaterThanOrEqual(count, 32, "mindestens 32 lesbare Beispiele muessen angewendet werden")
    }

    /// Verhalten: Der Beispielsatz ist vollstaendig (mindestens 51 Dateien, davon mindestens 32 lesbar).
    func testApplyBeispielsatzMindestanzahl() throws {
        let all = try rawSamples()
        XCTAssertGreaterThanOrEqual(all.count, 51)
        let readable = all.filter { (try? ClaudeDelivery.read(try JSONSerialization.data(withJSONObject: $0.delivery))) != nil }
        XCTAssertGreaterThanOrEqual(readable.count, 32)
    }

    /// Verhalten: Ein nach der Abschrift geaendertes Programm bzw. eine geaenderte Atemuebung wird nicht zurueckgenommen.
    func testRuecknahmeEinzelnGeaendertesProgrammAbgelehnt() throws {
        let cases: [(modified: Date?, snapshot: Date?, blocked: Bool)] = [
            (t(1000), t(500), true), (t(1000), nil, true),
            (nil, t(500), false), (nil, nil, false), (t(1000), t(1000), false), (t(1000), t(2000), false)]
        for (index, c) in cases.enumerated() {
            for id in ["claude.prog", "claude.atem"] {
                var before = try seeded()
                before.sets[0].modifiedAt = c.modified
                before.presets[0].modifiedAt = c.modified
                let deliveryId = "wd-chg-\(id)-\(index)"
                let d = try delivery(deliveryId, items: [withdrawal(item: id)])
                let (after, result) = apply(d, to: before, lastSnapshotAt: c.snapshot, now: now)
                let ctx = "\(id) Fall \(index)"
                if c.blocked {
                    assertRejected(result, "CHANGED_ON_IPHONE", ctx)
                    XCTAssertEqual(after.sets, before.sets, ctx)
                    XCTAssertEqual(after.presets, before.presets, ctx)
                } else {
                    XCTAssertEqual(result, .applied, ctx)
                    XCTAssertEqual(id == "claude.prog" ? after.sets.count : after.presets.count, 0, ctx)
                    XCTAssertEqual(id == "claude.prog" ? after.presets.count : after.sets.count, 1,
                                   "der andere Baustein bleibt: \(ctx)")
                }
                XCTAssertEqual(after.log.last?.deliveryId, deliveryId)
                XCTAssertEqual(after.log.last?.result, result)
            }
        }
    }

    /// Verhalten: Die Ruecknahme per itemId entfernt genau diesen Baustein, der andere bleibt; sind beide Kennungen gesetzt, gilt die Vereinigung.
    func testRuecknahmeEinzelnEntferntBaustein() throws {
        let base = try stateWithExercise("claude.ex", base: try seeded())
        let (s1, r1) = apply(try delivery("wd-1", items: [withdrawal(item: "claude.prog")]), to: base,
                             lastSnapshotAt: t(5), now: now)
        XCTAssertEqual(r1, .applied)
        XCTAssertTrue(s1.sets.isEmpty)
        XCTAssertEqual(s1.presets, base.presets)
        XCTAssertEqual(s1.exercises, base.exercises)
        XCTAssertEqual(s1.log.last?.result, .applied)

        let (s2, r2) = apply(try delivery("wd-2", items: [withdrawal(item: "claude.atem")]), to: base,
                             lastSnapshotAt: t(5), now: now)
        XCTAssertEqual(r2, .applied)
        XCTAssertTrue(s2.presets.isEmpty)
        XCTAssertEqual(s2.sets, base.sets)
        XCTAssertEqual(s2.exercises, base.exercises)

        let (s3, r3) = apply(try delivery("wd-3", items: [withdrawal(item: "claude.ex")]), to: base,
                             lastSnapshotAt: nil, now: now)
        XCTAssertEqual(r3, .applied)
        XCTAssertTrue(s3.exercises.isEmpty)
        XCTAssertEqual(s3.sets, base.sets)
        XCTAssertEqual(s3.presets, base.presets)

        // Beide Kennungen: itemId trifft das Programm, packageId die Atemuebung eines anderen Pakets; die Uebung bleibt.
        var both = empty()
        both = try applied([programItem("claude.a", rev: 1)], to: both, id: "b-1")
        both = try applied([breathItem("claude.b", rev: 1)], to: both, id: "b-2", package: ("pkg-b", "Paket B"))
        both = try applied([exerciseItem("claude.c")], to: both, id: "b-3")
        let (s4, r4) = apply(try delivery("wd-4", items: [withdrawal(item: "claude.a", package: "pkg-b")]),
                             to: both, lastSnapshotAt: t(5), now: now)
        XCTAssertEqual(r4, .applied)
        XCTAssertTrue(s4.sets.isEmpty)
        XCTAssertTrue(s4.presets.isEmpty)
        XCTAssertEqual(s4.exercises, both.exercises)
    }

    /// Verhalten: Eine unbekannte Kennung, eine Ruecknahme ganz ohne Kennung und eigene Bausteine bleiben ohne Wirkung.
    func testRuecknahmeUnbekannterKennungOhneWirkung() throws {
        let before = try stateWithExercise(base: try seeded())
        let items: [Json] = [withdrawal(item: "claude.gibt-es-nicht"), withdrawal(package: "pkg-gibt-es-nicht"), withdrawal()]
        for (index, item) in items.enumerated() {
            let (after, result) = apply(try delivery("wd-unk-\(index)", items: [item]), to: before,
                                        lastSnapshotAt: t(5), now: now)
            XCTAssertEqual(result, .noEffect, "Fall \(index)")
            XCTAssertEqual(after.sets, before.sets)
            XCTAssertEqual(after.presets, before.presets)
            XCTAssertEqual(after.exercises, before.exercises)
            XCTAssertEqual(after.log.last?.deliveryId, "wd-unk-\(index)")
            XCTAssertEqual(after.log.last?.result, .noEffect)
        }
        // Eigene Bausteine (claude == nil) werden nie getroffen, auch nicht bei gleichem Text; keine Sperrpruefung.
        var own = empty()
        own.sets = [ownSet("claude.prog", exerciseId: "claude.prog", modifiedAt: t(9000))]
        own.presets = [ownPreset("claude.atem", modifiedAt: t(9000))]
        let d = try delivery("wd-own", items: [withdrawal(item: "claude.prog"), withdrawal(item: "claude.atem"),
                                               withdrawal(package: "claude.prog")])
        let (after, result) = apply(d, to: own, lastSnapshotAt: nil, now: now)
        XCTAssertEqual(result, .noEffect)
        XCTAssertEqual(after.sets, own.sets)
        XCTAssertEqual(after.presets, own.presets)
    }

    /// Zustand mit einem Paket aus Programm, Atemuebung und Uebung, dazu Bausteine ohne Paket, aus anderem Paket und eigene.
    private func packageState() throws -> ClaudeApplyState {
        var state = empty()
        state = try applied([programItem("claude.p-pkg", rev: 1), breathItem("claude.a-pkg", rev: 1),
                             exerciseItem("claude.e-pkg")], to: state, id: "pk-1", package: ("pkg-1", "Paket 1"))
        state = try applied([programItem("claude.p-solo", rev: 1), breathItem("claude.a-solo", rev: 1)],
                            to: state, id: "pk-2")
        state = try applied([programItem("claude.p-other", rev: 1)], to: state, id: "pk-3", package: ("pkg-2", "Paket 2"))
        state.sets.append(ownSet())
        state.presets.append(ownPreset())
        return state
    }

    /// Verhalten: Die Ruecknahme eines Pakets entfernt alle Bausteine des Pakets; der Rest bleibt.
    func testRuecknahmePaketEntferntAlleBausteine() throws {
        let before = try packageState()
        XCTAssertEqual(before.sets.count, 4)
        XCTAssertEqual(before.presets.count, 3)
        XCTAssertEqual(before.exercises.count, 1)
        let (after, result) = apply(try delivery("wd-pkg", items: [withdrawal(package: "pkg-1")]), to: before,
                                    lastSnapshotAt: t(5), now: now)
        XCTAssertEqual(result, .applied)
        XCTAssertEqual(after.sets.compactMap { $0.claude?.itemId }.sorted(), ["claude.p-other", "claude.p-solo"])
        XCTAssertEqual(after.sets.count, 3, "eigenes Programm bleibt")
        XCTAssertEqual(after.presets.compactMap { $0.claude?.itemId }, ["claude.a-solo"])
        XCTAssertEqual(after.presets.count, 2, "eigene Atemuebung bleibt")
        XCTAssertTrue(after.exercises.isEmpty)
        XCTAssertEqual(after.log.last?.result, .applied)

        // Beispielsatz: neues Programm anlegen und altes im selben Zug zuruecknehmen (Positionen der Reihe nach).
        let seedState = try applied([programItem("claude.ruecken-a", rev: 1)], to: empty(), id: "pk-seed")
        let sample = try sampleDelivery("package-with-withdrawal.json")
        let (s2, r2) = apply(sample, to: seedState, lastSnapshotAt: t(5), now: now)
        XCTAssertEqual(r2, .applied)
        XCTAssertEqual(s2.sets.compactMap { $0.claude?.itemId }, ["claude.ruecken-a2"])
    }

    /// Verhalten: Ist ein Baustein des Pakets nach der Abschrift geaendert, wird alles abgelehnt; nichts wird entfernt.
    func testRuecknahmePaketMitGeaendertemBausteinAbgelehnt() throws {
        var before = try packageState()
        let i = try XCTUnwrap(before.presets.firstIndex { $0.claude?.itemId == "claude.a-pkg" })
        before.presets[i].modifiedAt = t(2000)
        let d = try delivery("wd-pkg-chg", items: [withdrawal(package: "pkg-1")])
        let (after, result) = apply(d, to: before, lastSnapshotAt: t(1000), now: now)
        assertRejected(result, "CHANGED_ON_IPHONE")
        XCTAssertEqual(after.sets, before.sets)
        XCTAssertEqual(after.presets, before.presets)
        XCTAssertEqual(after.exercises, before.exercises)
        XCTAssertEqual(after.log.last?.deliveryId, "wd-pkg-chg")
        XCTAssertEqual(after.log.last?.result, result)

        // Ohne Abschrift gilt ein gesetztes modifiedAt ebenfalls als geaendert.
        let (after2, result2) = apply(try delivery("wd-pkg-chg2", items: [withdrawal(package: "pkg-1")]), to: before,
                                      lastSnapshotAt: nil, now: now)
        assertRejected(result2, "CHANGED_ON_IPHONE", "ohne Abschrift")
        XCTAssertEqual(after2.sets, before.sets)
        XCTAssertEqual(after2.presets, before.presets)

        // Ein geaenderter Baustein ausserhalb des Pakets blockiert nicht.
        var other = try packageState()
        let j = try XCTUnwrap(other.presets.firstIndex { $0.claude?.itemId == "claude.a-solo" })
        other.presets[j].modifiedAt = t(2000)
        let (after3, result3) = apply(try delivery("wd-pkg-ok", items: [withdrawal(package: "pkg-1")]), to: other,
                                      lastSnapshotAt: t(1000), now: now)
        XCTAssertEqual(result3, .applied)
        XCTAssertEqual(after3.presets.compactMap { $0.claude?.itemId }, ["claude.a-solo"])
    }

    /// Verhalten: Wird eine Uebung zurueckgenommen, bleibt das Programm mit seinen Phasen unveraendert; Uebungen sind nie gesperrt.
    func testRuecknahmeUebungLaesstProgrammphasenStehen() throws {
        var state = try stateWithExercise("claude.ex", name: "Meine Uebung")
        state = try applied([programItem("claude.p", rev: 1, steps: ["claude.ex", "builtin.planke"])], to: state, id: "ue-1")
        let phasesBefore = try first(state.sets, "Programm").phases
        XCTAssertEqual(phasesBefore.map(\.exerciseId), ["claude.ex", "builtin.planke"])
        let (after, result) = apply(try delivery("wd-ex", items: [withdrawal(item: "claude.ex")]), to: state,
                                    lastSnapshotAt: nil, now: now)
        XCTAssertEqual(result, .applied)
        XCTAssertTrue(after.exercises.isEmpty)
        XCTAssertEqual(after.sets, state.sets)
        let phasesAfter = try first(after.sets, "Programm").phases
        XCTAssertEqual(phasesAfter.map(\.name), phasesBefore.map(\.name))
        XCTAssertEqual(phasesAfter.map(\.exerciseId), ["claude.ex", "builtin.planke"])
        XCTAssertEqual(phasesAfter.first?.name, "Meine Uebung")
    }

    /// Verhalten: Ergebnis und Zustand lassen sich speichern und unveraendert wieder lesen.
    func testResultUndStateRoundTrip() throws {
        let results: [ClaudeApplyResult] = [.applied, .noEffect, .rejected(code: "CHANGED_ON_IPHONE", reason: "Grund")]
        for r in results {
            let back = try JSONDecoder().decode(ClaudeApplyResult.self, from: try JSONEncoder().encode(r))
            XCTAssertEqual(back, r)
        }
        var state = try stateWithExercise("claude.ex", name: "Uebung")
        state = try applied([programItem("claude.p", rev: 1, steps: ["claude.ex"]), breathItem("claude.a", rev: 1)],
                            to: state, id: "rt-1", package: ("pkg", "Paket"))
        let bad = try delivery("rt-bad", items: [programItem("claude.x", rev: 1, steps: ["builtin.gibt-es-nicht"])])
        state = apply(bad, to: state, lastSnapshotAt: nil, now: t(200)).0
        XCTAssertTrue(state.log.contains { if case .rejected = $0.result { return true } else { return false } })
        _ = try first(state.sets); _ = try first(state.presets); _ = try first(state.exercises)
        let back = try JSONDecoder().decode(ClaudeApplyState.self, from: try JSONEncoder().encode(state))
        XCTAssertEqual(back, state)
    }

    /// Verhalten: Die Anwende-Datei importiert nur Foundation und hat keine Seiteneffekte (kein Speicher, keine Benachrichtigung, keine Echtzeit).
    func testApplyDateiIstFoundationOnlyUndOhneSeiteneffekte() throws {
        let file = #filePath
        let url = URL(fileURLWithPath: "\(file)").deletingLastPathComponent()
            .appendingPathComponent("../Meditationstimer iOS/Models/ClaudeApply.swift").standardized
        let text = try String(contentsOf: url, encoding: .utf8)
        let code = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.hasPrefix("//") }
        let imports = code.filter { $0.hasPrefix("import ") }
        XCTAssertFalse(imports.isEmpty, "mindestens ein import erwartet")
        for line in imports { XCTAssertEqual(line, "import Foundation") }
        let joined = code.joined(separator: "\n")
        for forbidden in ["UserDefaults", "NotificationCenter", "Date()"] {
            XCTAssertFalse(joined.contains(forbidden), "\(forbidden) darf nicht vorkommen")
        }
    }
}
