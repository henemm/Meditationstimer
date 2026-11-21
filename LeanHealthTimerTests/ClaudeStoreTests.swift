//
//  ClaudeStoreTests.swift
//  LeanHealthTimerTests
//
//  TDD RED #51 Schnitt 2b, Runde 2b-1: Speichern, Laden, Neu-Laden der Claude-Bausteine.
//  Rundenspec: DOCS/specs/features/feature-51-s2b-speichern.md (AC-1 bis AC-8, AC-10; Quelltext-Waechter AC-15/AC-17).
//
//  Vom QA-Writer festgelegte Namen (Vorgabe fuer den Developer, Spec Festlegung 4 nennt sie nur beschreibend):
//    enum ClaudeListState: Equatable { case missing, stored, unreadable }
//    ClaudeStore.loadSets(from: UserDefaults, now: Date = Date())    -> (list: [WorkoutSet], state: ClaudeListState)
//    ClaudeStore.loadPresets(from: UserDefaults, now: Date = Date()) -> (list: [AtemView.Preset], state: ClaudeListState)
//  Dekodiert wird `claudeState` mit einem Standard-`JSONDecoder()` (wie die Listen, keine Sonderstrategie fuer Datum).
//

import XCTest
@testable import Lean_Health_Timer

final class ClaudeStoreTests: XCTestCase {

    private typealias Json = [String: Any]

    private let setsKey = "workoutProgramSets"
    private let presetsKey = "atemPresets"
    private let stateKey = "claudeState"
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let unreadableText = "Die gespeicherten Programme oder Atemübungen sind nicht lesbar; bitte später neu lesen."
    private var suiteNames: [String] = []

    override func tearDown() {
        for name in suiteNames { UserDefaults().removePersistentDomain(forName: name) }
        suiteNames = []
        super.tearDown()
    }

    // MARK: - Hilfen

    private func newSuiteName() -> String {
        let name = "ClaudeStoreTests.\(UUID().uuidString)"
        suiteNames.append(name)
        return name
    }

    private func makeDefaults(name: String? = nil) -> UserDefaults {
        let suite = name ?? newSuiteName()
        let defaults = UserDefaults(suiteName: suite)!
        if name == nil { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    /// Zeichnet jeden `set(_:forKey:)`-Aufruf mit seinem Key auf.
    private final class RecordingDefaults: UserDefaults {
        var written: [String] = []
        override func set(_ value: Any?, forKey defaultName: String) {
            written.append(defaultName)
            super.set(value, forKey: defaultName)
        }
    }

    private final class Counter { var count = 0 }

    private func counting(_ center: NotificationCenter) -> Counter {
        let counter = Counter()
        center.addObserver(forName: .claudeStoreDidChange, object: nil, queue: nil) { _ in counter.count += 1 }
        return counter
    }

    private func programItem(_ id: String, rev: Int = 1, name: String = "Programm P") -> Json {
        ["kind": "program", "itemId": id, "revision": rev, "name": name, "symbol": "💪", "rounds": 2,
         "steps": [["exerciseId": "builtin.planke", "workSeconds": 30, "restSeconds": 10] as Json]]
    }

    private func breathItem(_ id: String, rev: Int = 1, name: String = "Atem A") -> Json {
        ["kind": "breath", "itemId": id, "revision": rev, "name": name, "symbol": "🌙",
         "inhaleSeconds": 4, "holdInSeconds": 2, "exhaleSeconds": 6, "holdOutSeconds": 0, "rounds": 10]
    }

    private func exerciseItem(_ id: String, category: String = "core") -> Json {
        ["kind": "exercise", "itemId": id, "revision": 1, "name": "Vierfuessler", "category": category,
         "effect": "Rumpf", "instructions": "Langsam"]
    }

    private func delivery(_ id: String, items: [Json]) throws -> ClaudeDelivery {
        let json: Json = ["format": "hhhaven.delivery/1", "deliveryId": id, "source": "claude",
                          "createdAt": "2026-11-13T10:15:00Z", "why": "Weil es passt.", "items": items]
        return try ClaudeDelivery.read(try JSONSerialization.data(withJSONObject: json))
    }

    /// Standardlieferung: ein Programm und eine Atemuebung.
    private func standard(_ id: String = "d-1") throws -> ClaudeDelivery {
        try delivery(id, items: [programItem("claude.prog"), breathItem("claude.atem")])
    }

    private func sets(_ defaults: UserDefaults) throws -> [WorkoutSet] {
        let data = try XCTUnwrap(defaults.data(forKey: setsKey), "workoutProgramSets nicht geschrieben")
        return try JSONDecoder().decode([WorkoutSet].self, from: data)
    }

    private func presets(_ defaults: UserDefaults) throws -> [AtemView.Preset] {
        let data = try XCTUnwrap(defaults.data(forKey: presetsKey), "atemPresets nicht geschrieben")
        return try JSONDecoder().decode([AtemView.Preset].self, from: data)
    }

    private func state(_ defaults: UserDefaults) throws -> ClaudeStoredState {
        let data = try XCTUnwrap(defaults.data(forKey: stateKey), "claudeState nicht geschrieben")
        return try JSONDecoder().decode(ClaudeStoredState.self, from: data)
    }

    private func backupKeys(_ defaults: UserDefaults, prefix: String) -> [String] {
        defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }.sorted()
    }

    private func ownSets() -> [WorkoutSet] {
        [WorkoutSet(name: "Eigen Eins", emoji: "💪", phases: [
            WorkoutPhase(name: "Phase", workDuration: 30, restDuration: 10)], repetitions: 1),
         WorkoutSet(name: "Eigen Zwei", emoji: "🔥", phases: [
            WorkoutPhase(name: "Phase", workDuration: 20, restDuration: 5)], repetitions: 3)]
    }

    private func ownPresets() -> [AtemView.Preset] {
        [AtemView.Preset(name: "Eigen Atem Eins", emoji: "🧘", inhale: 3, holdIn: 1, exhale: 5, holdOut: 0, repetitions: 4),
         AtemView.Preset(name: "Eigen Atem Zwei", emoji: "🌿", inhale: 6, holdIn: 0, exhale: 6, holdOut: 0, repetitions: 7)]
    }

    private func seedValidLists(_ defaults: UserDefaults) throws {
        defaults.set(try JSONEncoder().encode(ownSets()), forKey: setsKey)
        defaults.set(try JSONEncoder().encode(ownPresets()), forKey: presetsKey)
    }

    // MARK: - AC-1

    /// Verhalten (AC-1): Given leere Defaults, When eine Lieferung (Programm + Atemuebung) angewendet wird,
    /// Then stehen in den gespeicherten Listen die Code-Vorgaben (in ihrer Reihenfolge) plus das Gelieferte, nie eine leere Liste.
    func testAC1_FehlendeListenErgebenVorgabenPlusGeliefertes() throws {
        let defaults = makeDefaults()
        let result = ClaudeStore.apply(try standard(), in: defaults, lastSnapshotAt: nil, now: now, center: NotificationCenter())
        XCTAssertEqual(result, .applied)

        let writtenSets = try sets(defaults)
        let defaultSets = defaultWorkoutSets
        XCTAssertFalse(defaultSets.isEmpty)
        XCTAssertEqual(writtenSets.map(\.name), defaultSets.map(\.name) + ["Programm P"])
        XCTAssertEqual(writtenSets.prefix(defaultSets.count).map(\.id), defaultSets.map(\.id))
        XCTAssertEqual(writtenSets.last?.claude?.itemId, "claude.prog")

        let writtenPresets = try presets(defaults)
        let defaultPresets = MeditationTab.defaultPresets
        XCTAssertFalse(defaultPresets.isEmpty)
        XCTAssertEqual(writtenPresets.map(\.name), defaultPresets.map(\.name) + ["Atem A"])
        XCTAssertEqual(writtenPresets.prefix(defaultPresets.count).map(\.id), defaultPresets.map(\.id))
        XCTAssertEqual(writtenPresets.last?.claude?.itemId, "claude.atem")
    }

    // MARK: - AC-2

    /// Verhalten (AC-2): Given gespeicherte Listen mit eigenen Eintraegen, When angewendet wird,
    /// Then bleiben die eigenen Eintraege unveraendert und in derselben Reihenfolge, das Gelieferte ist dabei.
    func testAC2_GespeicherteListenBleibenErhalten() throws {
        let defaults = makeDefaults()
        let seededSets = ownSets(), seededPresets = ownPresets()
        defaults.set(try JSONEncoder().encode(seededSets), forKey: setsKey)
        defaults.set(try JSONEncoder().encode(seededPresets), forKey: presetsKey)
        let result = ClaudeStore.apply(try standard(), in: defaults, lastSnapshotAt: nil, now: now, center: NotificationCenter())
        XCTAssertEqual(result, .applied)

        let writtenSets = try sets(defaults)
        XCTAssertEqual(Array(writtenSets.prefix(2)), seededSets, "eigene Programme unveraendert und in gleicher Reihenfolge")
        XCTAssertEqual(Array(try presets(defaults).prefix(2)), seededPresets, "eigene Atemuebungen unveraendert")
        XCTAssertEqual(writtenSets.prefix(2).map(\.name), ["Eigen Eins", "Eigen Zwei"])
        XCTAssertEqual(writtenSets.prefix(2).map(\.emoji), ["💪", "🔥"])
        XCTAssertEqual(writtenSets.prefix(2).map(\.repetitions), [1, 3])
        XCTAssertEqual(writtenSets.prefix(2).map { $0.phases.map(\.workDuration) }, [[30], [20]])
        XCTAssertTrue(writtenSets.contains { $0.claude?.itemId == "claude.prog" })
        XCTAssertEqual(writtenSets.filter { $0.claude != nil }.count, 1)

        let writtenPresets = try presets(defaults)
        XCTAssertEqual(writtenPresets.prefix(2).map(\.name), ["Eigen Atem Eins", "Eigen Atem Zwei"])
        XCTAssertEqual(writtenPresets.prefix(2).map(\.inhale), [3, 6])
        XCTAssertEqual(writtenPresets.prefix(2).map(\.repetitions), [4, 7])
        XCTAssertTrue(writtenPresets.contains { $0.claude?.itemId == "claude.atem" })
        XCTAssertEqual(writtenPresets.filter { $0.claude != nil }.count, 1)
    }

    // MARK: - AC-3

    /// Verhalten (AC-3): Given eine aufzeichnende UserDefaults-Unterklasse, When applied (Programm, Atemuebung, Uebung),
    /// Then ist die Schreibreihenfolge Programme, Atemuebungen, claudeState; claudeState enthaelt nur exercises und log.
    func testAC3_SchreibreihenfolgeUndInhaltVonClaudeState() throws {
        let name = newSuiteName()
        let defaults = RecordingDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let d = try delivery("d-3", items: [exerciseItem("claude.ex"), programItem("claude.prog"), breathItem("claude.atem")])
        let result = ClaudeStore.apply(d, in: defaults, lastSnapshotAt: nil, now: now, center: NotificationCenter())
        XCTAssertEqual(result, .applied)
        XCTAssertEqual(defaults.written, [setsKey, presetsKey, stateKey])

        let raw = try XCTUnwrap(defaults.data(forKey: stateKey))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: raw) as? Json)
        XCTAssertEqual(Set(json.keys), ["exercises", "log"], "claudeState darf weder sets noch presets enthalten")
        let stored = try JSONDecoder().decode(ClaudeStoredState.self, from: raw)
        XCTAssertEqual(stored.exercises.map(\.claude.itemId), ["claude.ex"])
        XCTAssertEqual(stored.log.map(\.deliveryId), ["d-3"])
        XCTAssertEqual(stored.log.first?.result, .applied)
    }

    // MARK: - AC-4

    /// Verhalten (AC-4a): Given eine schon angewendete Lieferung, When eine Lieferung gleicher Fassung (noEffect) kommt,
    /// Then bleiben die Listen byte-gleich, das Ergebnis steht im Gedaechtnis, und es wird nichts gemeldet.
    func testAC4_NoEffectSchreibtListenNichtUndMeldetNichts() throws {
        let defaults = makeDefaults()
        let center = NotificationCenter()
        XCTAssertEqual(ClaudeStore.apply(try standard("d-first"), in: defaults, lastSnapshotAt: nil, now: now, center: center), .applied)
        let setsBefore = defaults.data(forKey: setsKey), presetsBefore = defaults.data(forKey: presetsKey)
        let counter = counting(center)

        let result = ClaudeStore.apply(try standard("d-second"), in: defaults, lastSnapshotAt: nil,
                                       now: now.addingTimeInterval(60), center: center)
        XCTAssertEqual(result, .noEffect)
        XCTAssertEqual(defaults.data(forKey: setsKey), setsBefore)
        XCTAssertEqual(defaults.data(forKey: presetsKey), presetsBefore)
        XCTAssertEqual(try state(defaults).log.last?.deliveryId, "d-second")
        XCTAssertEqual(try state(defaults).log.last?.result, .noEffect)
        XCTAssertEqual(counter.count, 0)
    }

    /// Verhalten (AC-4b): Given leere Defaults, When eine von apply abgelehnte Lieferung (CATEGORY_UNKNOWN) kommt,
    /// Then werden die Listen nicht angelegt, die Ablehnung steht im Gedaechtnis, und es wird nichts gemeldet.
    func testAC4_AbgelehnteLieferungSchreibtListenNichtUndMeldetNichts() throws {
        let defaults = makeDefaults()
        let center = NotificationCenter()
        let counter = counting(center)
        let d = try delivery("d-rej", items: [exerciseItem("claude.ex", category: "unbekannt")])

        let result = ClaudeStore.apply(d, in: defaults, lastSnapshotAt: nil, now: now, center: center)
        guard case .rejected(let code, _) = result else { return XCTFail("erwartet rejected, war \(result)") }
        XCTAssertEqual(code, "CATEGORY_UNKNOWN")
        XCTAssertNil(defaults.data(forKey: setsKey), "Programmliste darf nicht angelegt werden")
        XCTAssertNil(defaults.data(forKey: presetsKey), "Atemliste darf nicht angelegt werden")
        let log = try state(defaults).log
        XCTAssertEqual(log.map(\.deliveryId), ["d-rej"])
        XCTAssertEqual(log.first?.result, result)
        XCTAssertEqual(counter.count, 0)
    }

    // MARK: - AC-5

    /// Verhalten (AC-5): Given eine angewendete Lieferung und ein Neustart (neue Defaults-Instanz, neues Center),
    /// When dieselbe Lieferung noch einmal kommt, Then gibt es das gemerkte Ergebnis, alle drei Keys bleiben byte-gleich, keine Meldung.
    func testAC5_IdempotenzUeberNeustart() throws {
        let name = newSuiteName()
        let first = makeDefaults(name: name)
        first.removePersistentDomain(forName: name)
        let d = try standard("d-5")
        XCTAssertEqual(ClaudeStore.apply(d, in: first, lastSnapshotAt: nil, now: now, center: NotificationCenter()), .applied)
        let before = [setsKey, presetsKey, stateKey].map { first.data(forKey: $0) }
        XCTAssertTrue(before.allSatisfy { $0 != nil }, "alle drei Keys muessen nach dem ersten Anwenden stehen")

        let restarted = makeDefaults(name: name)
        let center = NotificationCenter()
        let counter = counting(center)
        let result = ClaudeStore.apply(d, in: restarted, lastSnapshotAt: nil, now: now.addingTimeInterval(3600), center: center)
        XCTAssertEqual(result, .applied)
        XCTAssertEqual([setsKey, presetsKey, stateKey].map { restarted.data(forKey: $0) }, before)
        XCTAssertEqual(counter.count, 0)
    }

    // MARK: - AC-6

    /// Verhalten (AC-6a): Given unlesbare Rohdaten unter workoutProgramSets, When eine gueltige Lieferung kommt,
    /// Then LIST_UNREADABLE mit festem Text, Rohdaten gesichert und unveraendert, nichts sonst geschrieben, nicht gemerkt, keine Meldung.
    func testAC6_UnlesbareProgrammlisteLehntAb() throws {
        let defaults = makeDefaults()
        let raw = Data("kaputt-sets".utf8)
        defaults.set(raw, forKey: setsKey)
        let center = NotificationCenter()
        let counter = counting(center)
        let d = try standard("d-6a")

        let result = ClaudeStore.apply(d, in: defaults, lastSnapshotAt: nil, now: now, center: center)
        XCTAssertEqual(result, .rejected(code: "LIST_UNREADABLE", reason: unreadableText))
        let backups = backupKeys(defaults, prefix: "workoutProgramSetsBackup.")
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(backups.first.flatMap { defaults.data(forKey: $0) }, raw)
        XCTAssertEqual(defaults.data(forKey: setsKey), raw, "Rohdaten der Liste bleiben unangetastet")
        XCTAssertNil(defaults.data(forKey: presetsKey))
        XCTAssertNil(defaults.data(forKey: stateKey), "claudeState darf nicht geschrieben werden")
        XCTAssertEqual(counter.count, 0)

        // Nach Reparatur der Liste wird dieselbe Lieferung normal angewendet (nicht gemerkt).
        defaults.removeObject(forKey: setsKey)
        XCTAssertEqual(ClaudeStore.apply(d, in: defaults, lastSnapshotAt: nil, now: now, center: center), .applied)
    }

    /// Verhalten (AC-6b): Given unlesbare Rohdaten unter atemPresets (Programme fehlen), When eine gueltige Lieferung kommt,
    /// Then LIST_UNREADABLE, Sicherung unter atemPresetsBackup., Programme und claudeState bleiben ungeschrieben.
    func testAC6_UnlesbareAtemlisteLehntAb() throws {
        let defaults = makeDefaults()
        let raw = Data("kaputt-presets".utf8)
        defaults.set(raw, forKey: presetsKey)
        let center = NotificationCenter()
        let counter = counting(center)
        let d = try standard("d-6b")

        let result = ClaudeStore.apply(d, in: defaults, lastSnapshotAt: nil, now: now, center: center)
        XCTAssertEqual(result, .rejected(code: "LIST_UNREADABLE", reason: unreadableText))
        let backups = backupKeys(defaults, prefix: "atemPresetsBackup.")
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(backups.first.flatMap { defaults.data(forKey: $0) }, raw)
        XCTAssertEqual(defaults.data(forKey: presetsKey), raw)
        XCTAssertNil(defaults.data(forKey: setsKey))
        XCTAssertNil(defaults.data(forKey: stateKey))
        XCTAssertEqual(counter.count, 0)

        defaults.removeObject(forKey: presetsKey)
        XCTAssertEqual(ClaudeStore.apply(d, in: defaults, lastSnapshotAt: nil, now: now, center: center), .applied)
    }

    // MARK: - AC-7

    /// Verhalten (AC-7): Given gueltige Listen und unlesbarer claudeState, When eine gueltige Lieferung kommt,
    /// Then liegt der Rohwert unter claudeStateBackup.<Sekunden>, die Lieferung wird mit leerem Gedaechtnis angewendet,
    /// und claudeState ist danach lesbar und enthaelt sie.
    func testAC7_UnlesbarerClaudeStateWirdGesichert() throws {
        let defaults = makeDefaults()
        try seedValidLists(defaults)
        let raw = Data("kaputt-state".utf8)
        defaults.set(raw, forKey: stateKey)

        let result = ClaudeStore.apply(try standard("d-7"), in: defaults, lastSnapshotAt: nil, now: now, center: NotificationCenter())
        XCTAssertEqual(result, .applied)
        XCTAssertEqual(defaults.data(forKey: "claudeStateBackup.1800000000"), raw)
        let stored = try state(defaults)
        XCTAssertEqual(stored.log.map(\.deliveryId), ["d-7"])
        XCTAssertEqual(stored.log.first?.result, .applied)
        XCTAssertTrue(stored.exercises.isEmpty)
        XCTAssertTrue(try sets(defaults).contains { $0.claude?.itemId == "claude.prog" })
    }

    // MARK: - AC-8

    /// Verhalten (AC-8): Given unlesbare Rohdaten unter atemPresets, When Preset.loadStored mehrfach laeuft
    /// (gleiche Rohdaten zweimal, geaenderte Rohdaten in derselben Sekunde), Then ist das Ergebnis nil, die Rohdaten liegen
    /// genau einmal gesichert, die geaenderten unter Schluessel mit -2, nichts wird ueberschrieben; der Lader der Tabs meldet
    /// unlesbar und liefert die Vorgaben.
    func testAC8_SicherungUnlesbarerAtemlisteBeimLaden() throws {
        let defaults = makeDefaults()
        let raw1 = Data("kaputt-eins".utf8), raw2 = Data("kaputt-zwei".utf8)
        defaults.set(raw1, forKey: presetsKey)
        XCTAssertNil(AtemView.Preset.loadStored(from: defaults, key: presetsKey, now: now))
        XCTAssertNil(AtemView.Preset.loadStored(from: defaults, key: presetsKey, now: now))
        XCTAssertEqual(backupKeys(defaults, prefix: "atemPresetsBackup."), ["atemPresetsBackup.1800000000"])
        XCTAssertEqual(defaults.data(forKey: "atemPresetsBackup.1800000000"), raw1)

        defaults.set(raw2, forKey: presetsKey)
        XCTAssertNil(AtemView.Preset.loadStored(from: defaults, key: presetsKey, now: now))
        XCTAssertEqual(backupKeys(defaults, prefix: "atemPresetsBackup."),
                       ["atemPresetsBackup.1800000000", "atemPresetsBackup.1800000000-2"])
        XCTAssertEqual(defaults.data(forKey: "atemPresetsBackup.1800000000"), raw1, "nichts wird ueberschrieben")
        XCTAssertEqual(defaults.data(forKey: "atemPresetsBackup.1800000000-2"), raw2)

        let loaded = ClaudeStore.loadPresets(from: defaults, now: now)
        XCTAssertEqual(loaded.state, .unreadable)
        XCTAssertEqual(loaded.list, MeditationTab.defaultPresets)
        XCTAssertEqual(backupKeys(defaults, prefix: "atemPresetsBackup.").count, 2, "gleiche Bytes werden nicht doppelt gesichert")
    }

    // MARK: - Lader mit Vorgaben (Festlegung 4)

    /// Verhalten (Festlegung 4): Fehlender Key ergibt Vorgaben mit Zustand missing, gespeicherter Key wird mit Vorgaben ergaenzt
    /// (eigene Eintraege zuerst, unveraendert), Zustand stored; unlesbare Programme ergeben Vorgaben, unlesbar.
    func testLaderMitVorgabenMeldetFehlendGespeichertUnlesbar() throws {
        let empty = makeDefaults()
        let missingSets = ClaudeStore.loadSets(from: empty, now: now)
        XCTAssertEqual(missingSets.state, .missing)
        XCTAssertEqual(missingSets.list, defaultWorkoutSets)
        let missingPresets = ClaudeStore.loadPresets(from: empty, now: now)
        XCTAssertEqual(missingPresets.state, .missing)
        XCTAssertEqual(missingPresets.list, MeditationTab.defaultPresets)

        let stored = makeDefaults()
        try seedValidLists(stored)
        let loadedSets = ClaudeStore.loadSets(from: stored, now: now)
        XCTAssertEqual(loadedSets.state, .stored)
        XCTAssertEqual(loadedSets.list.prefix(2).map(\.name), ["Eigen Eins", "Eigen Zwei"])
        XCTAssertTrue(defaultWorkoutSets.allSatisfy { d in loadedSets.list.contains { $0.name == d.name } },
                      "fehlende Vorgaben werden per Migration ergaenzt")
        let loadedPresets = ClaudeStore.loadPresets(from: stored, now: now)
        XCTAssertEqual(loadedPresets.state, .stored)
        XCTAssertEqual(loadedPresets.list.prefix(2).map(\.name), ["Eigen Atem Eins", "Eigen Atem Zwei"])
        XCTAssertTrue(MeditationTab.defaultPresets.allSatisfy { d in loadedPresets.list.contains { $0.name == d.name } })

        let broken = makeDefaults()
        broken.set(Data("kaputt".utf8), forKey: setsKey)
        let unreadable = ClaudeStore.loadSets(from: broken, now: now)
        XCTAssertEqual(unreadable.state, .unreadable)
        XCTAssertEqual(unreadable.list, defaultWorkoutSets)
    }

    // MARK: - AC-10

    /// Verhalten (AC-10a): Given ein Beobachter, der beim Eintreffen alle drei Keys liest, When applied,
    /// Then genau eine Meldung claudeStoreDidChange, und der neue Stand steht dann schon in allen drei Keys.
    func testAC10_MeldungNachDemSchreibenGenauEinmal() throws {
        XCTAssertEqual(Notification.Name.claudeStoreDidChange.rawValue, "ClaudeStore.didChange")
        let defaults = makeDefaults()
        let center = NotificationCenter()
        var snapshots: [(sets: Bool, presets: Bool, log: Bool)] = []
        center.addObserver(forName: .claudeStoreDidChange, object: nil, queue: nil) { [self] _ in
            let s = (try? sets(defaults))?.contains { $0.claude?.itemId == "claude.prog" } ?? false
            let p = (try? presets(defaults))?.contains { $0.claude?.itemId == "claude.atem" } ?? false
            let l = (try? state(defaults))?.log.contains { $0.deliveryId == "d-10" } ?? false
            snapshots.append((s, p, l))
        }
        XCTAssertEqual(ClaudeStore.apply(try standard("d-10"), in: defaults, lastSnapshotAt: nil, now: now, center: center), .applied)
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertTrue(snapshots.first?.sets == true, "Programmliste beim Eintreffen nicht lesbar")
        XCTAssertTrue(snapshots.first?.presets == true, "Atemliste beim Eintreffen nicht lesbar")
        XCTAssertTrue(snapshots.first?.log == true, "claudeState beim Eintreffen nicht lesbar")
    }

    /// Verhalten (AC-10b): Given ein Beobachter, When noEffect, eine von apply abgelehnte Lieferung oder LIST_UNREADABLE,
    /// Then wird keine Meldung gesendet.
    func testAC10_KeineMeldungBeiNoEffectAblehnungUndUnlesbar() throws {
        let defaults = makeDefaults()
        let center = NotificationCenter()
        XCTAssertEqual(ClaudeStore.apply(try standard("d-a"), in: defaults, lastSnapshotAt: nil, now: now, center: center), .applied)
        let counter = counting(center)

        XCTAssertEqual(ClaudeStore.apply(try standard("d-b"), in: defaults, lastSnapshotAt: nil, now: now, center: center), .noEffect)
        let rejected = try delivery("d-c", items: [exerciseItem("claude.ex", category: "unbekannt")])
        if case .rejected = ClaudeStore.apply(rejected, in: defaults, lastSnapshotAt: nil, now: now, center: center) {} else {
            XCTFail("erwartet rejected")
        }
        defaults.set(Data("kaputt".utf8), forKey: setsKey)
        XCTAssertEqual(ClaudeStore.apply(try standard("d-d"), in: defaults, lastSnapshotAt: nil, now: now, center: center),
                       .rejected(code: "LIST_UNREADABLE", reason: unreadableText))
        XCTAssertEqual(counter.count, 0)
    }

    // MARK: - Quelltext-Waechter (AC-15, AC-17)

    private func sourceText(_ relative: String, file: StaticString = #filePath) throws -> String {
        let url = URL(fileURLWithPath: "\(file)").deletingLastPathComponent()
            .appendingPathComponent("../\(relative)").standardized
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Verhalten (AC-15): Der Testeinstieg (Startargument und Umgebungsvariablen) existiert und steht ausschliesslich in #if DEBUG.
    func testAC15_TesteinstiegStehtNurInDebug() throws {
        let text = try sourceText("Meditationstimer iOS/Meditationstimer_iOSApp.swift")
        var debugStack: [Bool] = []
        var hits = 0
        for line in text.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("#if ") { debugStack.append(t == "#if DEBUG") }
            else if t.hasPrefix("#else") || t.hasPrefix("#elseif") {
                if !debugStack.isEmpty { debugStack[debugStack.count - 1] = false }
            } else if t.hasPrefix("#endif") { _ = debugStack.popLast() }
            if line.contains("uitest-claude-apply") || line.contains("UITEST_CLAUDE_DELIVERY") || line.contains("UITEST_CLAUDE_DELAY") {
                hits += 1
                XCTAssertTrue(debugStack.contains(true), "ausserhalb von #if DEBUG: \(t)")
            }
        }
        XCTAssertGreaterThanOrEqual(hits, 3, "Testeinstieg (Startargument, DELIVERY, DELAY) fehlt")
    }

    /// Verhalten (AC-17): ClaudeStore.swift existiert und importiert nur Foundation.
    func testAC17_ClaudeStoreImportiertNurFoundation() throws {
        let text = try sourceText("Meditationstimer iOS/Models/ClaudeStore.swift")
        let imports = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("import ") }
        XCTAssertEqual(imports, ["import Foundation"])
    }
}
