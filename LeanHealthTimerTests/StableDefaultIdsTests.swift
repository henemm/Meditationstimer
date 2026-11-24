//
//  StableDefaultIdsTests.swift
//  LeanHealthTimerTests
//
//  TDD RED #117: Die 10 mitgelieferten Vorgaben (4 Programme, 6 Atemuebungen) tragen feste Kennungen.
//  Spec: DOCS/specs/features/feature-117-stabile-kennungen.md (AC-1 bis AC-8; AC-9 = bestehende Suite).
//
//  Die erwarteten UUIDs stehen als Literale hier im Test. Jeder Testlauf ist ein neuer Prozess; eine je Prozess
//  neu erzeugte Zufallskennung faellt daher sofort durch. Verglichen wird nur ueber id/name.
//

import XCTest
@testable import Lean_Health_Timer

final class StableDefaultIdsTests: XCTestCase {

    // MARK: - Golden-Werte (nie aus dem Code ableiten)

    private let goldenSets: [(name: String, id: String)] = [
        ("Tabata Classic", "5a1e8c32-7b4d-4f19-9c60-2d3e8a41b701"),
        ("Core Circuit", "9f3b72d4-1c85-4a6e-b2f7-6e0d54c8a912"),
        ("Full Body Burn", "c47d09ab-e2f6-4358-8a1b-93b7f5d20c43"),
        ("Quick Burn", "2b86f1e7-04ca-4d92-a5e3-7c18d9b36f04"),
    ]

    private let goldenPresets: [(name: String, id: String)] = [
        ("Box Breathing", "e1d5a3c9-6f28-47b0-9d14-b5a07e8c2f65"),
        ("Calming Breath", "73c9b0f4-8a2e-4e61-bf05-1d6c4a97e836"),
        ("Coherent Breathing", "a8f24d61-3b97-4c0a-8e72-f40b6d1359c7"),
        ("Deep Calm", "0d6e9b35-c7a1-4f83-a248-8b9e31f5d078"),
        ("Relaxing Breath", "4f91c7e8-52d0-4b3a-9c86-a2e7d0481b59"),
        ("Rhythmic Breath", "b3a07f52-9e64-4d1c-85f9-3c5d82e6a41a"),
    ]

    // MARK: - Hilfen

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var suiteNames: [String] = []

    override func tearDown() {
        for name in suiteNames { UserDefaults().removePersistentDomain(forName: name) }
        suiteNames = []
        super.tearDown()
    }

    private func makeDefaults() -> UserDefaults {
        let name = "StableDefaultIdsTests.\(UUID().uuidString)"
        suiteNames.append(name)
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    private func encode<T: Encodable>(_ v: T) -> Data { try! JSONEncoder().encode(v) }

    private func transcript(sets: [WorkoutSet], presets: [AtemView.Preset]) -> String {
        let data = TranscriptBuilder.build(sets: sets, presets: presets, claudeExercises: [], log: [], now: now)
        return String(decoding: data, as: UTF8.self)
    }

    private func ownId(_ uuid: String) -> String { "own." + uuid }

    private func program(_ name: String, id: UUID) -> WorkoutSet {
        WorkoutSet(id: id, name: name, emoji: "💪",
                   phases: [WorkoutPhase(name: "Phase", workDuration: 30, restDuration: 10, exerciseId: "builtin.planke", hint: nil)],
                   repetitions: 2, description: nil, claude: nil, modifiedAt: nil)
    }

    private func breath(_ name: String, id: UUID) -> AtemView.Preset {
        AtemView.Preset(id: id, name: name, emoji: "🌬️", inhale: 4, holdIn: 4, exhale: 4, holdOut: 4,
                        repetitions: 5, description: nil, claude: nil, modifiedAt: nil)
    }

    private func delivery() throws -> ClaudeDelivery {
        let prog: [String: Any] = ["kind": "program", "itemId": "claude.prog", "revision": 1, "name": "Programm P",
                                   "symbol": "💪", "rounds": 2,
                                   "steps": [["exerciseId": "builtin.planke", "workSeconds": 30, "restSeconds": 10]]]
        let atem: [String: Any] = ["kind": "breath", "itemId": "claude.atem", "revision": 1, "name": "Atem A",
                                   "symbol": "🌙", "inhaleSeconds": 4, "holdInSeconds": 2, "exhaleSeconds": 6,
                                   "holdOutSeconds": 0, "rounds": 10]
        let json: [String: Any] = ["format": "hhhaven.delivery/1", "deliveryId": "d-117", "source": "claude",
                                   "createdAt": "2026-11-13T10:15:00Z", "why": "Weil es passt.", "items": [prog, atem]]
        return try ClaudeDelivery.read(try JSONSerialization.data(withJSONObject: json))
    }

    // MARK: - AC-1 / AC-2: Golden

    /// Verhalten: Die 4 Programme tragen genau die festgelegten Kennungen.
    func testAC1_ProgrammeTragenGoldenKennungen() {
        XCTAssertEqual(defaultWorkoutSets.count, 4)
        for g in goldenSets {
            let found = defaultWorkoutSets.first { $0.name == g.name }
            XCTAssertNotNil(found, "Programm \(g.name) fehlt")
            XCTAssertEqual(found?.id.uuidString.lowercased(), g.id, "Kennung von \(g.name)")
        }
    }

    /// Verhalten: Die 6 Atemuebungen tragen genau die festgelegten Kennungen.
    func testAC2_AtemuebungenTragenGoldenKennungen() {
        XCTAssertEqual(MeditationTab.defaultPresets.count, 6)
        for g in goldenPresets {
            let found = MeditationTab.defaultPresets.first { $0.name == g.name }
            XCTAssertNotNil(found, "Atemuebung \(g.name) fehlt")
            XCTAssertEqual(found?.id.uuidString.lowercased(), g.id, "Kennung von \(g.name)")
        }
    }

    // MARK: - AC-3: verschieden (Schutztest)

    /// Verhalten: Alle 10 Kennungen sind paarweise verschieden; keine Vorgabe kommt ohne Golden-Wert dazu.
    func testAC3_ZehnKennungenPaarweiseVerschieden() {
        XCTAssertEqual(defaultWorkoutSets.count, 4)
        XCTAssertEqual(MeditationTab.defaultPresets.count, 6)
        let ids = defaultWorkoutSets.map(\.id) + MeditationTab.defaultPresets.map(\.id)
        XCTAssertEqual(Set(ids).count, 10)
        let golden = Set((goldenSets + goldenPresets).map(\.id))
        XCTAssertEqual(golden.count, 10, "Golden-Werte selbst muessen verschieden sein")
    }

    // MARK: - AC-4 / AC-5 / AC-6: Abschrift

    /// Verhalten: Ohne gespeicherte Listen zeigt die Abschrift fuer jede Vorgabe own.<golden>.
    func testAC4_AbschriftBeiFehlendemSchluesselZeigtGolden() {
        let d = makeDefaults()
        let input = TranscriptBuilder.readCurrent(defaults: d)
        let t = transcript(sets: input.sets, presets: input.presets)
        for g in goldenSets + goldenPresets {
            XCTAssertTrue(t.contains(ownId(g.id)), "Abschrift ohne \(ownId(g.id)) (\(g.name))")
        }
        let direct = ClaudeStore.loadSets(from: d, now: now)
        XCTAssertEqual(direct.state, .missing)
        let t2 = transcript(sets: direct.list, presets: ClaudeStore.loadPresets(from: d, now: now).list)
        for g in goldenSets + goldenPresets {
            XCTAssertTrue(t2.contains(ownId(g.id)), "loadSets/loadPresets: \(ownId(g.id)) fehlt (\(g.name))")
        }
    }

    /// Verhalten: Bei unlesbaren Listen zeigt die Abschrift fuer jede Vorgabe own.<golden>.
    func testAC5_AbschriftBeiUnlesbaremSchluesselZeigtGolden() {
        let d = makeDefaults()
        let garbage = Data("kein json {".utf8)
        d.set(garbage, forKey: ClaudeStore.setsKey)
        d.set(garbage, forKey: ClaudeStore.presetsKey)
        let s = ClaudeStore.loadSets(from: d, now: now)
        let p = ClaudeStore.loadPresets(from: d, now: now)
        XCTAssertEqual(s.state, .unreadable)
        XCTAssertEqual(p.state, .unreadable)
        let t = transcript(sets: s.list, presets: p.list)
        for g in goldenSets + goldenPresets {
            XCTAssertTrue(t.contains(ownId(g.id)), "Abschrift ohne \(ownId(g.id)) (\(g.name))")
        }
    }

    /// Verhalten: Haengt die Migration eine fehlende Vorgabe an, traegt sie in der Abschrift own.<golden>.
    func testAC6_AbschriftBeiAngehaengterVorgabeZeigtGolden() {
        let d = makeDefaults()
        // Gespeichert: eine eigene Vorgabe plus je eine Vorgabe mit alter Zufallskennung; alle uebrigen fehlen.
        d.set(encode([program("Mein Programm", id: UUID()), program("Tabata Classic", id: UUID())]),
              forKey: ClaudeStore.setsKey)
        d.set(encode([breath("Meine Atmung", id: UUID()), breath("Box Breathing", id: UUID())]),
              forKey: ClaudeStore.presetsKey)
        let input = TranscriptBuilder.readCurrent(defaults: d)
        XCTAssertFalse(input.unreadable)
        let t = transcript(sets: input.sets, presets: input.presets)
        for g in goldenSets where g.name != "Tabata Classic" {
            XCTAssertTrue(t.contains(ownId(g.id)), "angehaengtes Programm \(g.name): \(ownId(g.id)) fehlt")
        }
        for g in goldenPresets where g.name != "Box Breathing" {
            XCTAssertTrue(t.contains(ownId(g.id)), "angehaengte Atemuebung \(g.name): \(ownId(g.id)) fehlt")
        }
    }

    // MARK: - AC-7: gespeichert bleibt (Schutztest)

    /// Verhalten: Gespeicherte Vorgaben mit alten Zufallskennungen behalten diese; nichts wird umgeschrieben, kein Duplikat.
    func testAC7_GespeicherteZufallskennungenBleibenUnveraendert() {
        let d = makeDefaults()
        let setIds = goldenSets.map { _ in UUID() }
        let presetIds = goldenPresets.map { _ in UUID() }
        d.set(encode(zip(goldenSets, setIds).map { program($0.0.name, id: $0.1) }), forKey: ClaudeStore.setsKey)
        d.set(encode(zip(goldenPresets, presetIds).map { breath($0.0.name, id: $0.1) }), forKey: ClaudeStore.presetsKey)

        let input = TranscriptBuilder.readCurrent(defaults: d)
        XCTAssertEqual(input.sets.map(\.id), setIds)
        XCTAssertEqual(input.presets.map(\.id), presetIds)
        XCTAssertEqual(input.sets.count, 4, "kein Duplikat bei Programmen")
        XCTAssertEqual(input.presets.count, 6, "kein Duplikat bei Atemuebungen")

        let t = transcript(sets: input.sets, presets: input.presets)
        for id in setIds + presetIds {
            XCTAssertTrue(t.contains(ownId(id.uuidString.lowercased())), "gespeicherte Kennung \(id) fehlt")
        }
        for g in goldenSets + goldenPresets {
            XCTAssertFalse(t.contains(ownId(g.id)), "Golden-Kennung \(g.id) darf nicht an die Stelle gespeicherter treten")
        }
    }

    // MARK: - AC-8: apply bei .missing

    /// Verhalten: Wendet apply bei fehlenden Listen etwas an, stehen die Vorgaben mit Golden-Kennungen im Speicher.
    func testAC8_ApplyBeiFehlendenListenSchreibtGoldenKennungen() throws {
        let d = makeDefaults()
        XCTAssertEqual(ClaudeStore.loadSets(from: d, now: now).state, .missing)
        let result = ClaudeStore.apply(try delivery(), in: d, lastSnapshotAt: nil, now: now, center: NotificationCenter())
        XCTAssertEqual(result, .applied)
        let setsData = try XCTUnwrap(d.data(forKey: ClaudeStore.setsKey), "Programme nicht geschrieben")
        let presetsData = try XCTUnwrap(d.data(forKey: ClaudeStore.presetsKey), "Atemuebungen nicht geschrieben")
        let sets = try JSONDecoder().decode([WorkoutSet].self, from: setsData)
        let presets = try JSONDecoder().decode([AtemView.Preset].self, from: presetsData)
        for g in goldenSets {
            XCTAssertEqual(sets.first { $0.name == g.name }?.id.uuidString.lowercased(), g.id, "geschriebene Kennung \(g.name)")
        }
        for g in goldenPresets {
            XCTAssertEqual(presets.first { $0.name == g.name }?.id.uuidString.lowercased(), g.id, "geschriebene Kennung \(g.name)")
        }
    }
}
