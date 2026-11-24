//
//  TranscriptBuilderTests.swift
//  LeanHealthTimerTests
//
//  #57 Schnitt 3: Abschrift Fassung 1 (Regeln R1 bis R14, AC-1 bis AC-21 und AC-25), umgesetzt in TranscriptBuilder.swift.
//  Spec: DOCS/specs/features/feature-57-s3-abschrift.md
//
//  Getestete API:
//    TranscriptBuilder.build(sets:presets:claudeExercises:log:now:) -> Data
//    TranscriptBuilder.readCurrent(defaults:) -> TranscriptInput   (sets, presets, claudeExercises, log, unreadable)
//    ClaudeStore.readState(from:) -> (state: ClaudeStoredState, unreadable: Bool)
//
//  Goldendateien: Contracts/transcript/app-generated/{empty,full,limits}.json. Sie wurden einmalig aus `emptyFixture()`,
//  `fullFixture()` und `limitsFixture()` (mit `goldenNow`) erzeugt und von Hand im Diff geprueft.
//  Kein Test schreibt eine Goldendatei.
//

import XCTest
@testable import Lean_Health_Timer

final class TranscriptBuilderTests: XCTestCase {

    // MARK: - Hilfen

    private typealias Json = [String: Any]

    private struct Fixture {
        var sets: [WorkoutSet] = []
        var presets: [AtemView.Preset] = []
        var exercises: [ClaudeStoredExercise] = []
        var log: [ClaudeApplyLogEntry] = []
    }

    private func utc(_ s: String) -> Date {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")!
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)!
    }

    /// Fester Zeitpunkt aller Goldendateien: 2026-11-24T08:30:00Z.
    private var goldenNow: Date { utc("2026-11-24T08:30:00Z") }

    private func uuid(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", n))!
    }

    private func origin(_ itemId: String, rev: Int = 1, why: String = "Passt zu deinem Plan.",
                        pkgId: String? = nil, pkgName: String? = nil,
                        at: String = "2026-11-12T18:00:00Z") -> ClaudeOrigin {
        ClaudeOrigin(itemId: itemId, revision: rev, why: why, packageId: pkgId, packageName: pkgName, deliveredAt: utc(at))
    }

    private func phase(_ exId: String?, work: Int = 30, rest: Int = 10, hint: String? = nil) -> WorkoutPhase {
        WorkoutPhase(name: "Phase", workDuration: work, restDuration: rest, exerciseId: exId, hint: hint)
    }

    private func program(_ name: String, id: UUID = UUID(), emoji: String = "💪", phases: [WorkoutPhase]? = nil,
                         reps: Int = 2, desc: String? = nil, claude: ClaudeOrigin? = nil,
                         modified: Date? = nil) -> WorkoutSet {
        WorkoutSet(id: id, name: name, emoji: emoji, phases: phases ?? [phase("builtin.planke")], repetitions: reps,
                   description: desc, claude: claude, modifiedAt: modified)
    }

    private func breath(_ name: String, id: UUID = UUID(), emoji: String = "🌬️", rhythm: (Int, Int, Int, Int) = (4, 4, 4, 4),
                        reps: Int = 5, desc: String? = nil, claude: ClaudeOrigin? = nil,
                        modified: Date? = nil) -> AtemView.Preset {
        AtemView.Preset(id: id, name: name, emoji: emoji, inhale: rhythm.0, holdIn: rhythm.1, exhale: rhythm.2,
                        holdOut: rhythm.3, repetitions: reps, description: desc, claude: claude, modifiedAt: modified)
    }

    private func exercise(_ itemId: String, name: String = "Claude-Übung", cat: String = "core",
                          effect: String = "Stärkt den Rumpf.", instructions: String = "Langsam ausführen.",
                          nameEn: String? = nil, notes: String? = nil, claude: ClaudeOrigin? = nil) -> ClaudeStoredExercise {
        ClaudeStoredExercise(id: UUID(), name: name, nameEn: nameEn, category: cat, effect: effect,
                             instructions: instructions, notes: notes, claude: claude ?? origin(itemId))
    }

    private func entry(_ id: String, _ result: ClaudeApplyResult = .applied) -> ClaudeApplyLogEntry {
        ClaudeApplyLogEntry(deliveryId: id, result: result, at: utc("2026-05-05T05:05:05Z"))
    }

    private func build(_ f: Fixture = Fixture(), now: Date? = nil) -> Data {
        TranscriptBuilder.build(sets: f.sets, presets: f.presets, claudeExercises: f.exercises, log: f.log,
                                now: now ?? goldenNow)
    }

    private func root(_ d: Data) throws -> Json {
        try XCTUnwrap(try JSONSerialization.jsonObject(with: d) as? Json)
    }

    private func list(_ d: Data, _ key: String) throws -> [Json] {
        try XCTUnwrap(try root(d)[key] as? [Json], "Liste \(key) fehlt")
    }

    private func text(_ d: Data) -> String { String(decoding: d, as: UTF8.self) }

    private func scalars(_ s: String) -> Int { s.unicodeScalars.count }

    private func byName(_ items: [Json], _ name: String, file: StaticString = #filePath, line: UInt = #line) -> Json {
        guard let found = items.first(where: { $0["name"] as? String == name }) else {
            XCTFail("Baustein „\(name)“ fehlt in der Ausgabe", file: file, line: line)
            return [:]
        }
        return found
    }

    private func byId(_ items: [Json], _ id: String, file: StaticString = #filePath, line: UInt = #line) -> Json {
        guard let found = items.first(where: { $0["id"] as? String == id }) else {
            XCTFail("Baustein „\(id)“ fehlt in der Ausgabe", file: file, line: line)
            return [:]
        }
        return found
    }

    private func ownId(_ n: Int) -> String { "own." + uuid(n).uuidString.lowercased() }

    private func golden(_ name: String, file: StaticString = #filePath) throws -> Data {
        let url = URL(fileURLWithPath: "\(file)").deletingLastPathComponent()
            .appendingPathComponent("../Contracts/transcript/app-generated/\(name).json").standardized
        return try Data(contentsOf: url)
    }

    private func containsNull(_ any: Any) -> Bool {
        if any is NSNull { return true }
        if let d = any as? Json { return d.values.contains { containsNull($0) } }
        if let a = any as? [Any] { return a.contains { containsNull($0) } }
        return false
    }

    private func allKeys(_ any: Any) -> Set<String> {
        if let d = any as? Json { return Set(d.keys).union(d.values.reduce(into: Set<String>()) { $0.formUnion(allKeys($1)) }) }
        if let a = any as? [Any] { return a.reduce(into: Set<String>()) { $0.formUnion(allKeys($1)) } }
        return []
    }

    private func allDateStrings(_ r: Json) -> [String] {
        var out = [r["generatedAt"] as? String].compactMap { $0 }
        for key in ["exercises", "programs", "breaths"] {
            for item in r[key] as? [Json] ?? [] { if let d = item["deliveredAt"] as? String { out.append(d) } }
        }
        return out
    }

    private func makeSuite() -> (UserDefaults, String) {
        let name = UUID().uuidString
        let d = UserDefaults(suiteName: name)!
        addTeardownBlock { d.removePersistentDomain(forName: name) }
        return (d, name)
    }

    private let dateRegex = "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"

    private let catalogCategoryTable: [String: String] = [
        "Kraft": "strength", "Dehnung": "stretching", "Core": "core", "Cardio": "cardio", "Beine": "legs",
        "Oberkörper": "upperBody", "Ganzkörper": "fullBody", "Aufwärmen": "warmup", "Cool-Down": "cooldown",
    ]

    // MARK: - Fixtures fuer die Goldendateien

    /// Goldendatei `empty.json`: leere Listen.
    private func emptyFixture() -> Fixture { Fixture() }

    /// Goldendatei `full.json`: fester Bestand, jede Art und jeder Zustand mindestens einmal.
    private func fullFixture() -> Fixture {
        let ownProgram = WorkoutSet(
            id: UUID(uuidString: "A1B2C3D4-0000-4000-8000-00000000000A")!, name: "Kern 20", emoji: "💪",
            phases: [phase("builtin.planke", work: 45, rest: 15, hint: "Arm/Bein diagonal, ruhig atmen"),
                     phase("OWN.Schulterkreisen-1A", work: 30, rest: 0)],
            repetitions: 3, description: "Kurzes Rumpftraining.\nZweite Zeile.")
        let claudeProgram = program("Rücken A", id: uuid(2), emoji: "🧘", phases: [
            phase("claude.vierfuessler-diagonal-x3f9k2", work: 40, rest: 15, hint: "Je Seite 8 Mal"),
            phase("builtin.planke", work: 30, rest: 15)], reps: 2, desc: "Kurz für den Rücken.",
            claude: origin("claude.kern-runde", rev: 2, why: "Zwei kurze Einheiten.", pkgId: "claude.ruecken-november",
                           pkgName: "Rücken November", at: "2026-11-12T18:00:00Z"))
        let claudeProgramEdited = program("Rücken B", id: uuid(3), emoji: "🌿", phases: [phase("builtin.planke")], reps: 1,
            claude: origin("claude.ruecken-b-7hq2mz", rev: 3, why: "Angepasst an dein Training.", at: "2026-11-13T07:15:30Z"),
            modified: utc("2026-11-20T09:00:00Z"))
        let ownBreath = breath("Meine Ruhe", id: UUID(uuidString: "B1B2C3D4-0000-4000-8000-00000000000B")!,
                               emoji: "🪷", rhythm: (4, 2, 6, 1), reps: 8, desc: "Zum Runterkommen.")
        let claudeBreath = breath("Abendatem", id: uuid(5), emoji: "✨", rhythm: (4, 0, 6, 0), reps: 10, desc: "Verlängerte Ausatmung.",
            claude: origin("claude.abendatem-k2m9", rev: 1, why: "Gegen Anspannung am Abend.", pkgId: "claude.ruecken-november",
                           pkgName: "Rücken November", at: "2026-11-12T18:00:00Z"))
        let claudeBreathEdited = breath("Morgenatem", id: uuid(6), emoji: "🌀", rhythm: (5, 5, 5, 5), reps: 6,
            claude: origin("claude.morgenatem-p4r8", rev: 2, why: "Wach werden.", at: "2026-11-14T06:00:00Z"),
            modified: utc("2026-11-21T06:30:00Z"))
        let ex1 = exercise("claude.vierfuessler-diagonal-x3f9k2", name: "Vierfüßler diagonal", cat: "core",
            effect: "Stärkt Rücken und Rumpf.", instructions: "Arm und Bein diagonal strecken.",
            nameEn: "Bird Dog", notes: "Langsam bleiben.",
            claude: origin("claude.vierfuessler-diagonal-x3f9k2", rev: 1, why: "Fehlte für Rücken A.",
                           pkgId: "claude.ruecken-november", pkgName: "Rücken November", at: "2026-11-12T18:00:00Z"))
        let ex2 = exercise("claude.seitstuetz-k8m2", name: "Seitstütz", cat: "upperBody",
            effect: "Kräftigt die seitliche Rumpfmuskulatur.", instructions: "Auf den Unterarm stützen.",
            claude: origin("claude.seitstuetz-k8m2", rev: 2, why: "", at: "2026-11-13T10:00:00Z"))
        let log = [entry("lieferung-0001", .applied), entry("lieferung-0002", .noEffect),
                   entry("lieferung-0003", .rejected(code: "CHANGED_ON_IPHONE", reason: "Bitte neu lesen"))]
        return Fixture(sets: [ownProgram, claudeProgram, claudeProgramEdited],
                       presets: [ownBreath, claudeBreath, claudeBreathEdited],
                       exercises: [ex2, ex1], log: log)
    }

    /// Goldendatei `limits.json`: Schemagrenzen, Klemmen, Kuerzen, Bereinigen, Auslassen.
    private func limitsFixture() -> Fixture {
        func a(_ n: Int) -> String { String(repeating: "a", count: n) }
        let fire16 = String(repeating: "🔥", count: 16), fire17 = String(repeating: "🔥", count: 17)
        let family = "👨‍👩‍👧‍👦"   // 7 Skalare
        func steps(_ n: Int) -> [WorkoutPhase] {
            (1...n).map { phase(String(format: "builtin.schritt-%02d", $0), work: 20 + $0, rest: 5) }
        }
        let sets = [
            program(a(40), id: uuid(1), emoji: fire16, phases: [phase("builtin.planke", hint: a(80))], desc: a(500)),
            program(a(41), id: uuid(2), phases: [phase("builtin.planke", hint: a(81))], desc: a(501)),
            program("Symbol17", id: uuid(3), emoji: fire17),
            program("Schritte40", id: uuid(4), phases: steps(40)),
            program("Schritte41", id: uuid(5), phases: steps(41)),
            program("Zahlen unten", id: uuid(6), phases: [phase("builtin.planke", work: 0, rest: -5)], reps: 0),
            program("Zahlen oben", id: uuid(7), phases: [phase("builtin.planke", work: 601, rest: 601)], reps: 100),
            program("Zahlen an der Grenze", id: uuid(8), phases: [phase("builtin.planke", work: 600, rest: 0)], reps: 99),
            program("Steuer\u{07}zeichen\nName", id: uuid(9), desc: "Zeile1\nZeile2\u{85}\u{202E}Ende"),
            program(String(repeating: "a", count: 39) + family, id: uuid(10), emoji: family + "🏳️‍🌈"),
            program("Gekürzt Claude", id: uuid(11), claude: origin("claude.gekuerzt-programm", rev: 0, why: a(301),
                    pkgId: "claude.paket-grenze", pkgName: a(41), at: "2026-11-01T00:00:00Z")),
        ]
        let presets = [
            breath(a(40), id: uuid(21), emoji: fire16, rhythm: (60, 60, 60, 60), reps: 99, desc: a(500)),
            breath(a(41), id: uuid(22), rhythm: (0, -1, 0, -1), reps: 0, desc: a(501)),
            breath("Oben", id: uuid(23), rhythm: (61, 61, 61, 61), reps: 100),
            breath("Symbol17", id: uuid(24), emoji: fire17),
            breath("Atem\u{07}Steuer\nzeichen", id: uuid(25), desc: "A\u{85}B\nC"),
        ]
        let exercises = [
            exercise("claude.grenze-uebung", name: a(41), cat: "fullBody", effect: a(601), instructions: a(1501),
                     nameEn: a(41), notes: a(601),
                     claude: origin("claude.grenze-uebung", rev: 1_000_001, why: a(301), pkgId: "claude.paket-grenze",
                                    pkgName: a(41), at: "2026-11-02T12:00:00Z")),
            exercise("claude.zerlegt-e", name: "e\u{0301}" + String(repeating: "e\u{0301}", count: 20), cat: "warmup",
                     claude: origin("claude.zerlegt-e", at: "2026-11-03T12:00:00Z")),
        ]
        let log = (1...51).map { n -> ClaudeApplyLogEntry in
            let r: ClaudeApplyResult = n % 3 == 0 ? .rejected(code: "X", reason: "Y") : (n % 3 == 1 ? .applied : .noEffect)
            return entry(String(format: "lieferung-%03d", n), r)
        }
        return Fixture(sets: sets, presets: presets, exercises: exercises, log: log)
    }

    // MARK: - AC-1 bis AC-3: Goldendateien

    /// Verhalten: Ohne Bestand entsteht die eingecheckte leere Abschrift mit allen 67 Katalogübungen.
    func testLeereAbschriftGleichGoldendatei() throws {
        // GIVEN leere Listen, fester Zeitpunkt  WHEN gebaut
        let data = build(emptyFixture())
        // THEN Bytes gleich Goldendatei und Inhalt wie beschrieben
        XCTAssertTrue(data == (try golden("empty")), "Bytes weichen von app-generated/empty.json ab")
        let r = try root(data)
        XCTAssertEqual(r["version"] as? Int, 1)
        XCTAssertEqual(r["generatedAt"] as? String, "2026-11-24T08:30:00Z")
        let ex = try list(data, "exercises")
        XCTAssertEqual(ex.count, 67)
        XCTAssertTrue(ex.allSatisfy { $0["origin"] as? String == "builtin" })
        XCTAssertEqual(try list(data, "programs").count, 0)
        XCTAssertEqual(try list(data, "breaths").count, 0)
        XCTAssertEqual(try list(data, "deliveries").count, 0)
    }

    /// Verhalten: Der feste Bestand ergibt Byte für Byte die eingecheckte vollständige Abschrift.
    func testVollstaendigeAbschriftGleichGoldendatei() throws {
        let data = build(fullFixture())
        XCTAssertTrue(data == (try golden("full")), "Bytes weichen von app-generated/full.json ab")
        XCTAssertEqual(try list(data, "programs").count, 3)
        XCTAssertEqual(try list(data, "breaths").count, 3)
        XCTAssertEqual(try list(data, "deliveries").count, 3)
        XCTAssertEqual(try list(data, "exercises").count, 69)
    }

    /// Verhalten: Grenzfälle (Klemmen, Kürzen, Auslassen, Bereinigen) ergeben die eingecheckte Datei und bleiben unter 256 KiB.
    func testGrenzfaelleGleichGoldendatei() throws {
        let data = build(limitsFixture())
        XCTAssertTrue(data == (try golden("limits")), "Bytes weichen von app-generated/limits.json ab")
        XCTAssertLessThan(data.count, 256 * 1024)
        XCTAssertEqual(try list(data, "deliveries").count, 50)
    }

    // MARK: - AC-4, AC-5: Form

    /// Verhalten: Gleiche Eingabe gleiche Bytes, Schlüssel sortiert, genau ein Zeilenumbruch am Ende, Schrägstriche unmaskiert.
    func testAbschriftIstDeterministisch() throws {
        let first = build(fullFixture()), second = build(fullFixture())
        XCTAssertTrue(first == second, "Zwei Läufe liefern verschiedene Bytes")
        let s = text(first)
        XCTAssertTrue(s.hasSuffix("}\n"), "Ende muss } und genau ein Zeilenumbruch sein")
        XCTAssertFalse(s.hasSuffix("\n\n"))
        XCTAssertTrue(s.contains("Arm/Bein"), "Schrägstrich darf nicht maskiert werden")
        XCTAssertFalse(s.contains("\\/"))
        // Schlüssel je Objekt alphabetisch: Einrückung als Objektgrenze
        var stack: [(indent: Int, last: String)] = []
        for line in s.split(separator: "\n", omittingEmptySubsequences: false) {
            let indent = line.prefix { $0 == " " }.count
            while let top = stack.last, top.indent > indent { stack.removeLast() }
            guard let m = line.range(of: "^ *\"([^\"]+)\" : ", options: .regularExpression) else { continue }
            let key = String(line[m].drop { $0 == " " }.dropFirst().prefix { $0 != "\"" })
            if let top = stack.last, top.indent == indent {
                XCTAssertLessThan(top.last, key, "Schlüssel nicht sortiert: \(top.last) vor \(key)")
                stack[stack.count - 1].last = key
            } else {
                stack.append((indent, key))
            }
        }
    }

    /// Verhalten: Die oberste Ebene hat genau die Schemafelder; version ist 1; nirgends null.
    func testHuelleHatGenauDieSchemafelder() throws {
        for f in [emptyFixture(), fullFixture(), limitsFixture()] {
            let data = build(f)
            let r = try root(data)
            XCTAssertEqual(Set(r.keys), ["version", "generatedAt", "exercises", "programs", "breaths", "deliveries"])
            XCTAssertEqual(r["version"] as? Int, 1)
            XCTAssertTrue(text(data).contains("\"version\" : 1"), "version muss die Zahl 1 sein")
            XCTAssertFalse(containsNull(r), "kein Wert darf null sein")
            let g = try XCTUnwrap(r["generatedAt"] as? String)
            XCTAssertNotNil(g.range(of: dateRegex, options: .regularExpression))
        }
    }

    // MARK: - AC-6, AC-7: Herkunft

    /// Verhalten: Eigene Bausteine heißen own.<uuid klein>, Claude-Bausteine tragen die itemId; nur Claude hat Claude-Felder.
    func testKennungenUndHerkunftsfelder() throws {
        let f = Fixture(
            sets: [program("Eigen", id: UUID(uuidString: "A1B2C3D4-AAAA-4000-8000-0000000000FF")!),
                   program("Von Claude", id: uuid(2), claude: origin("claude.kern-runde", rev: 2, pkgId: "claude.paket-a", pkgName: "Paket A"))],
            presets: [breath("Eigen Atem", id: UUID(uuidString: "C1B2C3D4-AAAA-4000-8000-0000000000EE")!)],
            exercises: [exercise("claude.uebung-x")], log: [])
        let data = build(f)
        let programs = try list(data, "programs"), breaths = try list(data, "breaths"), ex = try list(data, "exercises")
        XCTAssertEqual(byName(programs, "Eigen")["id"] as? String, "own.a1b2c3d4-aaaa-4000-8000-0000000000ff")
        XCTAssertEqual(byName(programs, "Von Claude")["id"] as? String, "claude.kern-runde")
        XCTAssertEqual(byName(breaths, "Eigen Atem")["id"] as? String, "own.c1b2c3d4-aaaa-4000-8000-0000000000ee")
        let claudeOnly = ["revision", "state", "packageId", "packageName", "why", "deliveredAt"]
        for item in [byName(programs, "Eigen"), byName(breaths, "Eigen Atem")] {
            XCTAssertEqual(item["origin"] as? String, "own")
            for k in claudeOnly { XCTAssertNil(item[k], "own darf \(k) nicht tragen") }
        }
        let builtins = ex.filter { $0["origin"] as? String == "builtin" }
        XCTAssertEqual(builtins.count, 67)
        for b in builtins {
            for k in claudeOnly + ["effect", "instructions", "notes"] { XCTAssertNil(b[k], "builtin darf \(k) nicht tragen") }
        }
        for item in ex + programs + breaths {
            let id = try XCTUnwrap(item["id"] as? String), origin = try XCTUnwrap(item["origin"] as? String)
            XCTAssertTrue(id.hasPrefix(origin + "."), "\(id) passt nicht zur Herkunft \(origin)")
            XCTAssertNotNil(id.range(of: "^(builtin|own|claude)\\.[a-z0-9][a-z0-9-]{1,62}$", options: .regularExpression), id)
        }
    }

    /// Verhalten: adapted genau bei gesetztem modifiedAt, sonst active; Übungen immer active; Herkunftswerte stimmen.
    func testZustandActiveUndAdapted() throws {
        let data = build(fullFixture())
        let programs = try list(data, "programs"), breaths = try list(data, "breaths"), ex = try list(data, "exercises")
        XCTAssertEqual(byId(programs, "claude.kern-runde")["state"] as? String, "active")
        XCTAssertEqual(byId(programs, "claude.ruecken-b-7hq2mz")["state"] as? String, "adapted")
        XCTAssertEqual(byId(breaths, "claude.abendatem-k2m9")["state"] as? String, "active")
        XCTAssertEqual(byId(breaths, "claude.morgenatem-p4r8")["state"] as? String, "adapted")
        for e in ex where e["origin"] as? String == "claude" { XCTAssertEqual(e["state"] as? String, "active") }
        XCTAssertFalse(text(data).contains("withdrawn"))
        let p = byId(programs, "claude.kern-runde")
        XCTAssertEqual(p["revision"] as? Int, 2)
        XCTAssertEqual(p["packageId"] as? String, "claude.ruecken-november")
        XCTAssertEqual(p["packageName"] as? String, "Rücken November")
        XCTAssertEqual(p["why"] as? String, "Zwei kurze Einheiten.")
        XCTAssertEqual(p["deliveredAt"] as? String, "2026-11-12T18:00:00Z")
        let b = byId(breaths, "claude.morgenatem-p4r8")
        XCTAssertEqual(b["revision"] as? Int, 2)
        XCTAssertEqual(b["why"] as? String, "Wach werden.")
        XCTAssertEqual(b["deliveredAt"] as? String, "2026-11-14T06:00:00Z")
        XCTAssertNil(b["packageId"])
        let e = byId(ex, "claude.vierfuessler-diagonal-x3f9k2")
        XCTAssertEqual(e["revision"] as? Int, 1)
        XCTAssertEqual(e["packageName"] as? String, "Rücken November")
        XCTAssertEqual(e["deliveredAt"] as? String, "2026-11-12T18:00:00Z")
    }

    // MARK: - AC-8: Kategorien

    /// Verhalten: Alle neun deutschen Katalog-Kategorien und alle neun englischen Claude-Texte ergeben den Schema-Wert.
    func testKategorienAbbildung() throws {
        let english = ["strength", "stretching", "core", "cardio", "legs", "upperBody", "fullBody", "warmup", "cooldown"]
        let claude = english.map { exercise("claude.kat-\($0.lowercased())", name: "Kat \($0)", cat: $0) }
        let ex = try list(build(Fixture(exercises: claude)), "exercises")
        // Katalog: Erwartung aus fest kodierter Tabelle, je Rohwert mindestens eine Übung
        var seen = Set<String>()
        for info in ExerciseDatabase.catalog {
            let expected = try XCTUnwrap(catalogCategoryTable[info.category.rawValue], info.category.rawValue)
            XCTAssertEqual(byId(ex, info.id)["category"] as? String, expected, info.id)
            seen.insert(info.category.rawValue)
        }
        // Der Katalog enthält keine Übung der Kategorie „Kraft“ (Stand 67 Übungen); geprüft wird daher nur,
        // dass jede vorkommende Kategorie in der Tabelle steht. „strength“ deckt der Claude-Teil unten ab.
        // Berichtigt in GREEN mit PO-Freigabe 2026-11-24 (#57 S3).
        XCTAssertTrue(seen.isSubset(of: Set(catalogCategoryTable.keys)), "Unbekannte Katalog-Kategorie")
        XCTAssertFalse(seen.isEmpty, "Katalog leer")
        for c in english { XCTAssertEqual(byId(ex, "claude.kat-\(c.lowercased())")["category"] as? String, c) }
    }

    /// Verhalten: Eine Claude-Übung mit unbekannter Kategorie fehlt, die übrigen bleiben.
    func testUnbekannteKategorieLaesstUebungAus() throws {
        let f = Fixture(exercises: [exercise("claude.gut-eins", name: "Gut Eins"),
                                    exercise("claude.kaputt", name: "Kaputt", cat: "Unsinn"),
                                    exercise("claude.gut-zwei", name: "Gut Zwei", cat: "legs")])
        let ex = try list(build(f), "exercises")
        XCTAssertEqual(ex.count, 69)
        XCTAssertFalse(ex.contains { $0["id"] as? String == "claude.kaputt" })
        XCTAssertTrue(ex.contains { $0["id"] as? String == "claude.gut-eins" })
        XCTAssertTrue(ex.contains { $0["id"] as? String == "claude.gut-zwei" })
    }

    // MARK: - AC-9: Klemmen

    /// Verhalten: Zahlen außerhalb der Schemagrenzen werden geklemmt, Werte innerhalb bleiben.
    func testZahlenWerdenGeklemmt() throws {
        let f = Fixture(
            sets: [program("Unten", id: uuid(1), phases: [phase("builtin.planke", work: 0, rest: -5)], reps: 0),
                   program("Oben", id: uuid(2), phases: [phase("builtin.planke", work: 601, rest: 601)], reps: 100),
                   program("Innen", id: uuid(3), phases: [phase("builtin.planke", work: 45, rest: 15)], reps: 7),
                   program("Rev", id: uuid(4), claude: origin("claude.rev-prog", rev: 0)),
                   program("RevOben", id: uuid(5), claude: origin("claude.rev-prog-oben", rev: 1_000_001))],
            presets: [breath("Unten", id: uuid(11), rhythm: (0, -1, 0, -1), reps: 0),
                      breath("Oben", id: uuid(12), rhythm: (61, 61, 61, 61), reps: 100),
                      breath("Innen", id: uuid(13), rhythm: (4, 2, 6, 1), reps: 9),
                      breath("Rev", id: uuid(14), claude: origin("claude.rev-atem", rev: 0)),
                      breath("RevOben", id: uuid(15), claude: origin("claude.rev-atem-oben", rev: 1_000_001))],
            exercises: [exercise("claude.rev-ex", claude: origin("claude.rev-ex", rev: 0)),
                        exercise("claude.rev-ex-oben", claude: origin("claude.rev-ex-oben", rev: 1_000_001))])
        let data = build(f)
        let programs = try list(data, "programs"), breaths = try list(data, "breaths"), ex = try list(data, "exercises")
        func step(_ p: Json) throws -> Json { try XCTUnwrap((p["steps"] as? [Json])?.first) }
        var s = try step(byName(programs, "Unten"))
        XCTAssertEqual(s["workSeconds"] as? Int, 1); XCTAssertEqual(s["restSeconds"] as? Int, 0)
        XCTAssertEqual(byName(programs, "Unten")["rounds"] as? Int, 1)
        s = try step(byName(programs, "Oben"))
        XCTAssertEqual(s["workSeconds"] as? Int, 600); XCTAssertEqual(s["restSeconds"] as? Int, 600)
        XCTAssertEqual(byName(programs, "Oben")["rounds"] as? Int, 99)
        s = try step(byName(programs, "Innen"))
        XCTAssertEqual(s["workSeconds"] as? Int, 45); XCTAssertEqual(s["restSeconds"] as? Int, 15)
        XCTAssertEqual(byName(programs, "Innen")["rounds"] as? Int, 7)
        func rhythm(_ b: Json) -> [Int?] {
            ["inhaleSeconds", "holdInSeconds", "exhaleSeconds", "holdOutSeconds", "rounds"].map { b[$0] as? Int }
        }
        XCTAssertEqual(rhythm(byName(breaths, "Unten")), [1, 0, 1, 0, 1])
        XCTAssertEqual(rhythm(byName(breaths, "Oben")), [60, 60, 60, 60, 99])
        XCTAssertEqual(rhythm(byName(breaths, "Innen")), [4, 2, 6, 1, 9])
        XCTAssertEqual(byName(programs, "Rev")["revision"] as? Int, 1)
        XCTAssertEqual(byName(programs, "RevOben")["revision"] as? Int, 1_000_000)
        XCTAssertEqual(byName(breaths, "Rev")["revision"] as? Int, 1)
        XCTAssertEqual(byName(breaths, "RevOben")["revision"] as? Int, 1_000_000)
        XCTAssertEqual(byId(ex, "claude.rev-ex")["revision"] as? Int, 1)
        XCTAssertEqual(byId(ex, "claude.rev-ex-oben")["revision"] as? Int, 1_000_000)
    }

    // MARK: - AC-10: Texte

    /// Verhalten: Jedes Textfeld mit Höchstlänge plus 1 wird auf genau die Höchstlänge in Unicode-Skalaren gekürzt.
    func testTexteWerdenGekuerzt() throws {
        func a(_ n: Int) -> String { String(repeating: "x", count: n) }
        let longEx = exercise("claude.lang-ex", name: a(41), effect: a(601), instructions: a(1501), nameEn: a(41), notes: a(601),
                              claude: origin("claude.lang-ex", why: a(301), pkgId: "claude.lang-paket", pkgName: a(41)))
        let f = Fixture(
            sets: [program(a(41), id: uuid(1), phases: [phase("builtin.planke", hint: a(81))], desc: a(501)),
                   program("Claude lang", id: uuid(2), claude: origin("claude.lang-prog", why: a(301), pkgId: "claude.lang-paket", pkgName: a(41)))],
            presets: [breath(a(41), id: uuid(3), desc: a(501))],
            exercises: [longEx])
        let data = build(f)
        let p = byId(try list(data, "programs"), ownId(1))
        XCTAssertEqual(scalars(p["name"] as? String ?? ""), 40)
        XCTAssertEqual(scalars(p["description"] as? String ?? ""), 500)
        XCTAssertEqual(scalars((((p["steps"] as? [Json])?.first)?["hint"] as? String) ?? ""), 80)
        let cp = byId(try list(data, "programs"), "claude.lang-prog")
        XCTAssertEqual(scalars(cp["why"] as? String ?? ""), 300)
        XCTAssertEqual(scalars(cp["packageName"] as? String ?? ""), 40)
        let b = byId(try list(data, "breaths"), ownId(3))
        XCTAssertEqual(scalars(b["name"] as? String ?? ""), 40)
        XCTAssertEqual(scalars(b["description"] as? String ?? ""), 500)
        let e = byId(try list(data, "exercises"), "claude.lang-ex")
        for (k, n) in [("name", 40), ("nameEn", 40), ("effect", 600), ("instructions", 1500), ("notes", 600),
                       ("why", 300), ("packageName", 40)] {
            XCTAssertEqual(scalars(e[k] as? String ?? ""), n, "Feld \(k)")
        }
        // Zählung in Skalaren, nicht in Zeichen: 21 mal e + Combining Acute = 42 Skalare, 21 Zeichen
        let combining = String(repeating: "e\u{0301}", count: 21)
        let c = try list(build(Fixture(sets: [program(combining, id: uuid(9))])), "programs")
        XCTAssertEqual(scalars(byId(c, ownId(9))["name"] as? String ?? ""), 40)
    }

    /// Verhalten: Verbotene Zeichen fallen weg; der Zeilenumbruch bleibt nur in description, effect, instructions, notes.
    func testVerboteneZeichenWerdenEntfernt() throws {
        let dirty = "A\u{07}B\u{85}C\u{202E}D\nE"
        let noBreak = "ABCDE", withBreak = "ABCD\nE"
        let ex = exercise("claude.schmutz-ex", name: dirty, effect: dirty, instructions: dirty, nameEn: dirty, notes: dirty,
                          claude: origin("claude.schmutz-ex", why: dirty, pkgId: "claude.schmutz-paket", pkgName: dirty))
        let f = Fixture(sets: [program(dirty, id: uuid(1), phases: [phase("builtin.planke", hint: dirty)], desc: dirty)],
                        presets: [breath(dirty, id: uuid(2), desc: dirty)], exercises: [ex])
        let data = build(f)
        let p = byId(try list(data, "programs"), ownId(1))
        XCTAssertEqual(p["name"] as? String, noBreak)
        XCTAssertEqual(p["description"] as? String, withBreak)
        XCTAssertEqual(((p["steps"] as? [Json])?.first)?["hint"] as? String, noBreak)
        let b = byId(try list(data, "breaths"), ownId(2))
        XCTAssertEqual(b["name"] as? String, noBreak)
        XCTAssertEqual(b["description"] as? String, withBreak)
        let e = byId(try list(data, "exercises"), "claude.schmutz-ex")
        for k in ["name", "nameEn", "why", "packageName"] { XCTAssertEqual(e[k] as? String, noBreak, k) }
        for k in ["effect", "instructions", "notes"] { XCTAssertEqual(e[k] as? String, withBreak, k) }
    }

    // MARK: - AC-11, AC-12: Auslassen

    /// Verhalten: Ungültige Bausteine entfallen ganz, gültige Nachbarn bleiben.
    func testUngueltigeBausteineWerdenAusgelassen() throws {
        let f = Fixture(
            sets: [program("Nachbar P", id: uuid(1)),
                   program("Fall a", id: uuid(2), phases: []),
                   program("Fall b", id: uuid(3), phases: [phase(nil), phase("kein-praefix"), phase("foo.bar-baz"), phase("builtin.")]),
                   program("   ", id: uuid(4)),
                   program("Fall e", id: uuid(5), emoji: ""),
                   program("Fall e3", id: uuid(6), emoji: String(repeating: "🔥", count: 17)),
                   program("Fall g", id: uuid(7), claude: origin("claude."))],
            presets: [breath("Nachbar A", id: uuid(11)),
                      breath("Fall d", id: uuid(12), emoji: "AB"),
                      breath("Fall e2", id: uuid(13), emoji: "🌬\u{202E}"),
                      breath("Fall g2", id: uuid(14), claude: origin("claude."))],
            exercises: [exercise("claude.nachbar-ex", name: "Nachbar E"),
                        exercise("claude.fall-f", name: "Fall f", effect: "   "),
                        exercise("claude.fall-f2", name: "Fall f2", instructions: "\u{00A0}\n "),
                        exercise("claude.", name: "Fall g3")])
        let data = build(f)
        let programs = try list(data, "programs"), breaths = try list(data, "breaths"), ex = try list(data, "exercises")
        XCTAssertEqual(programs.compactMap { $0["name"] as? String }, ["Nachbar P"])
        XCTAssertEqual(breaths.compactMap { $0["name"] as? String }, ["Nachbar A"])
        let claudeEx = ex.filter { $0["origin"] as? String == "claude" }.compactMap { $0["name"] as? String }
        XCTAssertEqual(claudeEx, ["Nachbar E"])
    }

    /// Verhalten: Eine ungültige packageId entfällt nur als Feld; teilweise ungültige Phasen lassen nur sich selbst weg.
    func testUngueltigePackageIdEntfaelltNurAlsFeld() throws {
        let f = Fixture(
            sets: [program("Paket Programm", id: uuid(1), claude: origin("claude.paket-prog", pkgId: "paket-ohne-praefix", pkgName: "Paket")),
                   program("Teilweise", id: uuid(2), phases: [phase("builtin.planke", work: 11), phase(nil), phase("builtin.liegestuetze", work: 22),
                                                               phase("ungueltig", work: 33), phase("claude.dritte-uebung", work: 44)])],
            exercises: [exercise("claude.paket-ex", name: "Paket Übung", claude: origin("claude.paket-ex", pkgId: "paket-ohne-praefix"))])
        let data = build(f)
        let p = byId(try list(data, "programs"), "claude.paket-prog")
        XCTAssertNil(p["packageId"])
        let e = byId(try list(data, "exercises"), "claude.paket-ex")
        XCTAssertNil(e["packageId"])
        let t = byName(try list(data, "programs"), "Teilweise")
        let steps = try XCTUnwrap(t["steps"] as? [Json])
        XCTAssertEqual(steps.compactMap { $0["exerciseId"] as? String }, ["builtin.planke", "builtin.liegestuetze", "claude.dritte-uebung"])
        XCTAssertEqual(steps.compactMap { $0["workSeconds"] as? Int }, [11, 22, 44])
    }

    /// Verhalten: Mehr als 40 Schritte werden auf die ersten 40 gekürzt; exerciseId wird kleingeschrieben.
    func testSchritteWerdenAuf40GekuerztUndKleingeschrieben() throws {
        let many = (1...45).map { phase(String(format: "builtin.s-%02d", $0), work: $0) }
        let f = Fixture(sets: [program("Viele", id: uuid(1), phases: many),
                               program("Gross", id: uuid(2), phases: [phase("OWN.Planke-ABC")])])
        let programs = try list(build(f), "programs")
        let steps = try XCTUnwrap(byName(programs, "Viele")["steps"] as? [Json])
        XCTAssertEqual(steps.count, 40)
        XCTAssertEqual(steps.first?["exerciseId"] as? String, "builtin.s-01")
        XCTAssertEqual(steps.last?["exerciseId"] as? String, "builtin.s-40")
        XCTAssertEqual(steps.compactMap { $0["workSeconds"] as? Int }, Array(1...40))
        let big = try XCTUnwrap(byName(programs, "Gross")["steps"] as? [Json])
        XCTAssertEqual(big.first?["exerciseId"] as? String, "own.planke-abc")
    }

    /// Verhalten: Leere oder nur aus Leerzeichen bestehende optionale Felder entfallen (kein "" und kein null), der Baustein bleibt.
    func testLeereOptionaleFelderEntfallen() throws {
        let blank = "  \u{00A0}\n "
        for value in [blank, nil] as [String?] {
            let f = Fixture(
                sets: [program("Programm", id: uuid(1), phases: [phase("builtin.planke", hint: value)], desc: value,
                               claude: origin("claude.leer-prog", why: value ?? "", pkgId: "claude.leer-paket", pkgName: value))],
                presets: [breath("Atem", id: uuid(2), desc: value)],
                exercises: [exercise("claude.leer-ex", nameEn: value, notes: value,
                                     claude: origin("claude.leer-ex", why: value ?? "", pkgId: "claude.leer-paket", pkgName: value))])
            let data = build(f)
            let p = byName(try list(data, "programs"), "Programm")
            XCTAssertNil(p["description"]); XCTAssertNil(p["why"]); XCTAssertNil(p["packageName"])
            XCTAssertNil(((p["steps"] as? [Json])?.first)?["hint"])
            XCTAssertNotNil(((p["steps"] as? [Json])?.first)?["exerciseId"])
            XCTAssertNil(byName(try list(data, "breaths"), "Atem")["description"])
            let e = byId(try list(data, "exercises"), "claude.leer-ex")
            for k in ["nameEn", "notes", "why", "packageName"] { XCTAssertNil(e[k], "\(k) muss entfallen") }
            XCTAssertEqual(e["name"] as? String, "Claude-Übung")
            XCTAssertFalse(text(data).contains("null"))
        }
    }

    // MARK: - AC-13 bis AC-15: Eindeutigkeit, Reihenfolge, Höchstzahlen

    /// Verhalten: Je Liste jede Kennung höchstens einmal; bei Doppelten gewinnt der erste in Ausgabereihenfolge.
    func testKeineDoppeltenKennungen() throws {
        let f = Fixture(
            sets: [program("Erstes", id: uuid(1), claude: origin("claude.doppelt")),
                   program("Zweites", id: uuid(2), claude: origin("claude.doppelt"))],
            presets: [breath("Atem Erste", id: uuid(7)), breath("Atem Zweite", id: uuid(7))],
            exercises: [exercise("claude.doppel-ex", name: "Spät", claude: origin("claude.doppel-ex", at: "2026-11-10T10:00:00Z")),
                        exercise("claude.doppel-ex", name: "Früh", claude: origin("claude.doppel-ex", at: "2026-11-01T10:00:00Z")),
                        exercise("builtin.planke", name: "Falsche Planke")])
        let data = build(f)
        for key in ["exercises", "programs", "breaths"] {
            let ids = try list(data, key).compactMap { $0["id"] as? String }
            XCTAssertEqual(ids.count, Set(ids).count, "doppelte Kennung in \(key)")
        }
        let programs = try list(data, "programs")
        XCTAssertEqual(programs.compactMap { $0["name"] as? String }, ["Erstes"])
        XCTAssertEqual(try list(data, "breaths").compactMap { $0["name"] as? String }, ["Atem Erste"])
        let ex = try list(data, "exercises")
        XCTAssertEqual(byId(ex, "claude.doppel-ex")["name"] as? String, "Früh")
        XCTAssertFalse(ex.contains { $0["name"] as? String == "Falsche Planke" })
        XCTAssertEqual(ex.filter { $0["id"] as? String == "builtin.planke" }.count, 1)
        XCTAssertEqual(ex.count, 68)
    }

    /// Verhalten: Programme und Atemübungen bleiben in gespeicherter Reihenfolge; Übungen: Katalog, dann Claude nach Zeit und itemId.
    func testReihenfolgeIstFest() throws {
        let f = Fixture(
            sets: [program("B", id: uuid(1)), program("A", id: uuid(2)), program("C", id: uuid(3))],
            presets: [breath("Y", id: uuid(4)), breath("X", id: uuid(5))],
            exercises: [exercise("claude.zz", claude: origin("claude.zz", at: "2026-11-05T10:00:00Z")),
                        exercise("claude.aa", claude: origin("claude.aa", at: "2026-11-05T10:00:00Z")),
                        exercise("claude.mm", claude: origin("claude.mm", at: "2026-11-01T10:00:00Z"))])
        let data = build(f)
        XCTAssertEqual(try list(data, "programs").compactMap { $0["name"] as? String }, ["B", "A", "C"])
        XCTAssertEqual(try list(data, "breaths").compactMap { $0["name"] as? String }, ["Y", "X"])
        let ids = try list(data, "exercises").compactMap { $0["id"] as? String }
        XCTAssertEqual(ids.count, 70)
        XCTAssertEqual(Array(ids[0..<67]), ExerciseDatabase.catalog.map(\.id))
        XCTAssertEqual(Array(ids[67...]), ["claude.mm", "claude.aa", "claude.zz"])
    }

    /// Verhalten: 200 Programme, 200 Atemübungen, 500 Übungen und 50 Lieferergebnisse als Obergrenze.
    func testHoechstzahlenWerdenEingehalten() throws {
        let sets = (1...250).map { program(String(format: "P-%03d", $0), id: uuid($0)) }
        let presets = (1...250).map { breath(String(format: "A-%03d", $0), id: uuid(1000 + $0)) }
        let exs = (1...600).map { n in
            exercise(String(format: "claude.ex-%03d", n), name: String(format: "E-%03d", n),
                     claude: origin(String(format: "claude.ex-%03d", n), at: "2026-10-01T00:00:00Z").withDeliveredAt(utc("2026-10-01T00:00:00Z").addingTimeInterval(Double(n) * 60)))
        }
        let log = (1...60).map { entry(String(format: "lieferung-%03d", $0)) }
        let data = build(Fixture(sets: sets, presets: presets, exercises: exs, log: log))
        let programs = try list(data, "programs"), breaths = try list(data, "breaths")
        let ex = try list(data, "exercises"), deliveries = try list(data, "deliveries")
        XCTAssertEqual(programs.count, 200)
        XCTAssertEqual(programs.first?["name"] as? String, "P-001")
        XCTAssertEqual(programs.last?["name"] as? String, "P-200")
        XCTAssertEqual(breaths.count, 200)
        XCTAssertEqual(breaths.last?["name"] as? String, "A-200")
        XCTAssertEqual(ex.count, 500)
        XCTAssertEqual(ex.filter { $0["origin"] as? String == "builtin" }.count, 67)
        XCTAssertEqual(ex.last?["id"] as? String, "claude.ex-433")
        XCTAssertEqual(deliveries.count, 50)
        XCTAssertEqual(deliveries.first?["deliveryId"] as? String, "lieferung-011")
        XCTAssertEqual(deliveries.last?["deliveryId"] as? String, "lieferung-060")
    }

    // MARK: - AC-16: Lieferergebnisse

    /// Verhalten: applied und noEffect werden accepted, rejected bleibt rejected; ungültige Kennungen fehlen; nur zwei Felder.
    func testLieferergebnisseAbbildung() throws {
        let at = utc("2026-05-05T05:05:05Z")
        let f = Fixture(log: [
            ClaudeApplyLogEntry(deliveryId: "lieferung-a1", result: .applied, at: at),
            ClaudeApplyLogEntry(deliveryId: "lieferung-a2", result: .noEffect, at: at),
            ClaudeApplyLogEntry(deliveryId: "abc", result: .applied, at: at),
            ClaudeApplyLogEntry(deliveryId: "lieferung-a3", result: .rejected(code: "GEHEIMER_CODE", reason: "Geheimer Grund"), at: at),
        ])
        let data = build(f)
        let d = try list(data, "deliveries")
        XCTAssertEqual(d.compactMap { $0["deliveryId"] as? String }, ["lieferung-a1", "lieferung-a2", "lieferung-a3"])
        XCTAssertEqual(d.compactMap { $0["outcome"] as? String }, ["accepted", "accepted", "rejected"])
        XCTAssertTrue(d.allSatisfy { Set($0.keys) == ["deliveryId", "outcome"] })
        let s = text(data)
        for forbidden in ["GEHEIMER_CODE", "Geheimer Grund", "2026-05-05"] { XCTAssertFalse(s.contains(forbidden), forbidden) }
        // 51 Einträge: die letzten 50
        let many = try list(build(Fixture(log: (1...51).map { entry(String(format: "lieferung-%03d", $0)) })), "deliveries")
        XCTAssertEqual(many.count, 50)
        XCTAssertEqual(many.first?["deliveryId"] as? String, "lieferung-002")
        XCTAssertEqual(many.last?["deliveryId"] as? String, "lieferung-051")
        // Doppelte Kennung: der erste Eintrag gewinnt
        let dup = try list(build(Fixture(log: [entry("lieferung-dopp", .rejected(code: "C", reason: "R")), entry("lieferung-dopp", .applied)])), "deliveries")
        XCTAssertEqual(dup.count, 1)
        XCTAssertEqual(dup.first?["outcome"] as? String, "rejected")
    }

    // MARK: - AC-17: Datum

    /// Verhalten: Datumsfelder sind ISO 8601 in UTC, ganze Sekunden abgerundet, echte Kalenderdaten, unabhängig von der Zeitzone.
    func testDatumsformatUtcUndEchteKalenderdaten() throws {
        let base = utc("2026-12-31T23:59:59Z")
        let f = Fixture(exercises: [
            exercise("claude.datum-a", claude: origin("claude.datum-a", at: "2028-02-29T23:59:59Z")),
            exercise("claude.datum-b", claude: origin("claude.datum-b", at: "2026-12-31T23:59:59Z")),
            exercise("claude.datum-c", claude: origin("claude.datum-c", at: "2026-01-01T00:00:00Z")),
            exercise("claude.datum-d", claude: origin("claude.datum-d").withDeliveredAt(base.addingTimeInterval(0.9))),
        ])
        let now = utc("2028-02-29T23:59:59Z")
        let saved = NSTimeZone.default
        defer { NSTimeZone.default = saved }
        NSTimeZone.default = TimeZone(identifier: "Asia/Tokyo")!
        let tokyo = build(f, now: now)
        NSTimeZone.default = TimeZone(identifier: "UTC")!
        let utcRun = build(f, now: now)
        XCTAssertTrue(tokyo == utcRun, "Ausgabe hängt von der Systemzeitzone ab")
        let r = try root(tokyo)
        XCTAssertEqual(r["generatedAt"] as? String, "2028-02-29T23:59:59Z")
        let ex = try list(tokyo, "exercises")
        XCTAssertEqual(byId(ex, "claude.datum-a")["deliveredAt"] as? String, "2028-02-29T23:59:59Z")
        XCTAssertEqual(byId(ex, "claude.datum-b")["deliveredAt"] as? String, "2026-12-31T23:59:59Z")
        XCTAssertEqual(byId(ex, "claude.datum-c")["deliveredAt"] as? String, "2026-01-01T00:00:00Z")
        XCTAssertEqual(byId(ex, "claude.datum-d")["deliveredAt"] as? String, "2026-12-31T23:59:59Z", "Sekundenbruchteil muss abgerundet werden")
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let dates = allDateStrings(r)
        XCTAssertGreaterThanOrEqual(dates.count, 5)
        for s in dates {
            XCTAssertNotNil(s.range(of: dateRegex, options: .regularExpression), s)
            let n = s.split(whereSeparator: { "-T:Z".contains($0) }).compactMap { Int($0) }
            XCTAssertEqual(n.count, 6, s)
            let comps = DateComponents(year: n[0], month: n[1], day: n[2], hour: n[3], minute: n[4], second: n[5])
            let date = try XCTUnwrap(cal.date(from: comps), s)
            XCTAssertEqual(cal.dateComponents(parts, from: date), cal.dateComponents(parts, from: cal.date(from: comps)!))
            XCTAssertEqual([cal.component(.year, from: date), cal.component(.month, from: date), cal.component(.day, from: date),
                            cal.component(.hour, from: date), cal.component(.minute, from: date), cal.component(.second, from: date)],
                           n, "kein echtes Kalenderdatum: \(s)")
        }
    }

    // MARK: - AC-18 bis AC-21: readCurrent

    private func encode<T: Encodable>(_ v: T) -> Data { try! JSONEncoder().encode(v) }

    /// Verhalten: Ohne gespeicherte Werte zeigt die Abschrift, was das iPhone zeigt: Vorgaben; Claude-Listen leer.
    func testReadCurrentFehlendZeigtVorgaben() {
        let (d, _) = makeSuite()
        let r = TranscriptBuilder.readCurrent(defaults: d)
        XCTAssertEqual(r.sets.map(\.name), defaultWorkoutSets.map(\.name))
        XCTAssertEqual(r.presets.map(\.name), MeditationTab.defaultPresets.map(\.name))
        XCTAssertEqual(r.sets.count, 4)
        XCTAssertEqual(r.presets.count, 6)
        XCTAssertTrue(r.claudeExercises.isEmpty)
        XCTAssertTrue(r.log.isEmpty)
        XCTAssertFalse(r.unreadable)
    }

    /// Verhalten: Gespeicherte Werte kommen in Reihenfolge zurück, ergänzt um fehlende Vorgaben, ohne Doppelte.
    func testReadCurrentLiestGespeicherteWerte() {
        let (d, _) = makeSuite()
        let own = program("Mein Programm", id: uuid(1))
        let tabata = program("Tabata Classic", id: uuid(2), desc: "Eigene Beschreibung")
        let myBreath = breath("Meine Atmung", id: uuid(3))
        let ex = exercise("claude.gelesen-ex", name: "Gelesen")
        let log = [entry("lieferung-gelesen")]
        d.set(encode([own, tabata]), forKey: ClaudeStore.setsKey)
        d.set(encode([myBreath]), forKey: ClaudeStore.presetsKey)
        d.set(encode(ClaudeStoredState(exercises: [ex], log: log)), forKey: ClaudeStore.stateKey)
        let r = TranscriptBuilder.readCurrent(defaults: d)
        let expectedSets = ["Mein Programm", "Tabata Classic"] + defaultWorkoutSets.map(\.name).filter { $0 != "Tabata Classic" }
        XCTAssertEqual(r.sets.map(\.name), expectedSets)
        XCTAssertEqual(r.sets.filter { $0.name == "Tabata Classic" }.count, 1)
        XCTAssertEqual(r.sets.first?.id, uuid(1))
        XCTAssertEqual(r.sets[1].description, "Eigene Beschreibung")
        XCTAssertEqual(r.presets.map(\.name), ["Meine Atmung"] + MeditationTab.defaultPresets.map(\.name))
        XCTAssertEqual(r.claudeExercises, [ex])
        XCTAssertEqual(r.log, log)
        XCTAssertFalse(r.unreadable)
    }

    /// Verhalten: Unlesbare Werte ergeben leere zugehörige Listen und unreadable; die übrigen Listen bleiben lesbar.
    func testReadCurrentUnlesbarIstLeerUndMarkiert() {
        let garbage = Data("kein json {".utf8)
        let ex = exercise("claude.rest-ex", name: "Rest")
        func seeded(_ d: UserDefaults, broken: String?) {
            d.set(broken == ClaudeStore.setsKey ? garbage : encode([program("Rest P", id: uuid(1))]), forKey: ClaudeStore.setsKey)
            d.set(broken == ClaudeStore.presetsKey ? garbage : encode([breath("Rest A", id: uuid(2))]), forKey: ClaudeStore.presetsKey)
            d.set(broken == ClaudeStore.stateKey ? garbage : encode(ClaudeStoredState(exercises: [ex], log: [entry("lieferung-rest")])),
                  forKey: ClaudeStore.stateKey)
        }
        var (d, _) = makeSuite()
        seeded(d, broken: ClaudeStore.setsKey)
        var r = TranscriptBuilder.readCurrent(defaults: d)
        XCTAssertTrue(r.sets.isEmpty, "keine Vorgaben bei Unlesbarem")
        XCTAssertEqual(r.presets.first?.name, "Rest A")
        XCTAssertEqual(r.claudeExercises.count, 1); XCTAssertEqual(r.log.count, 1)
        XCTAssertTrue(r.unreadable)
        (d, _) = makeSuite()
        seeded(d, broken: ClaudeStore.presetsKey)
        r = TranscriptBuilder.readCurrent(defaults: d)
        XCTAssertTrue(r.presets.isEmpty)
        XCTAssertEqual(r.sets.first?.name, "Rest P")
        XCTAssertEqual(r.claudeExercises.count, 1); XCTAssertEqual(r.log.count, 1)
        XCTAssertTrue(r.unreadable)
        (d, _) = makeSuite()
        seeded(d, broken: ClaudeStore.stateKey)
        r = TranscriptBuilder.readCurrent(defaults: d)
        XCTAssertTrue(r.claudeExercises.isEmpty); XCTAssertTrue(r.log.isEmpty)
        XCTAssertEqual(r.sets.first?.name, "Rest P")
        XCTAssertEqual(r.presets.first?.name, "Rest A")
        XCTAssertTrue(r.unreadable)
    }

    /// Verhalten: readState unterscheidet fehlend, lesbar und unlesbar und legt dabei keine Sicherung an.
    func testReadStateUnterscheidetFehlendLesbarUnlesbar() {
        let (d, name) = makeSuite()
        var s = ClaudeStore.readState(from: d)
        XCTAssertEqual(s.state, ClaudeStoredState()); XCTAssertFalse(s.unreadable)
        let stored = ClaudeStoredState(exercises: [exercise("claude.state-ex")], log: [entry("lieferung-state")])
        d.set(encode(stored), forKey: ClaudeStore.stateKey)
        s = ClaudeStore.readState(from: d)
        XCTAssertEqual(s.state, stored); XCTAssertFalse(s.unreadable)
        d.set(Data("müll".utf8), forKey: ClaudeStore.stateKey)
        let before = d.persistentDomain(forName: name) as NSDictionary?
        s = ClaudeStore.readState(from: d)
        XCTAssertEqual(s.state, ClaudeStoredState()); XCTAssertTrue(s.unreadable)
        XCTAssertEqual(d.persistentDomain(forName: name) as NSDictionary?, before, "readState darf nichts schreiben")
    }

    /// Verhalten: Lesen und Bauen schreiben nichts: keine Sicherungsschlüssel, keine angelegten Listen, Speicher unverändert.
    func testLesenUndBauenSchreibenNichts() {
        let garbage = Data("kaputt".utf8)
        let scenarios: [(String, (UserDefaults) -> Void)] = [
            ("fehlend", { _ in }),
            ("lesbar", { d in
                d.set(self.encode([self.program("P", id: self.uuid(1))]), forKey: ClaudeStore.setsKey)
                d.set(self.encode([self.breath("A", id: self.uuid(2))]), forKey: ClaudeStore.presetsKey)
                d.set(self.encode(ClaudeStoredState(exercises: [self.exercise("claude.ro-ex")], log: [self.entry("lieferung-ro")])),
                      forKey: ClaudeStore.stateKey)
            }),
            ("unlesbar", { d in
                d.set(garbage, forKey: ClaudeStore.setsKey)
                d.set(garbage, forKey: ClaudeStore.presetsKey)
                d.set(garbage, forKey: ClaudeStore.stateKey)
            }),
        ]
        for (label, seed) in scenarios {
            let (d, name) = makeSuite()
            seed(d)
            let before = d.persistentDomain(forName: name) as NSDictionary?
            let input = TranscriptBuilder.readCurrent(defaults: d)
            _ = TranscriptBuilder.build(sets: input.sets, presets: input.presets, claudeExercises: input.claudeExercises,
                                        log: input.log, now: goldenNow)
            let after = d.persistentDomain(forName: name) as NSDictionary?
            XCTAssertEqual(before, after, "\(label): Speicher hat sich verändert")
            let keys = (after as? [String: Any])?.keys.map { $0 } ?? []
            for prefix in ["atemPresetsBackup.", "claudeStateBackup.", "workoutProgramSetsBackup."] {
                XCTAssertFalse(keys.contains { $0.hasPrefix(prefix) }, "\(label): Sicherung \(prefix) angelegt")
            }
            if label == "fehlend" {
                XCTAssertNil(d.object(forKey: ClaudeStore.setsKey))
                XCTAssertNil(d.object(forKey: ClaudeStore.presetsKey))
                XCTAssertNil(d.object(forKey: ClaudeStore.stateKey))
            }
        }
    }

    // MARK: - AC-25: Abdeckung

    /// Verhalten: Jeder Feldname des Beispiels valid/full.json kommt auch in der App-Goldendatei full.json vor.
    func testGoldendateiDecktFelderVonValidFullAb() throws {
        let url = URL(fileURLWithPath: "\(#filePath)").deletingLastPathComponent()
            .appendingPathComponent("../Contracts/transcript/valid/full.json").standardized
        let example = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? Json)
        let transcript = try XCTUnwrap(example["transcript"] as? Json)
        var exampleKeys = Set<String>()
        for k in ["exercises", "programs", "breaths"] { exampleKeys.formUnion(allKeys(transcript[k] ?? [])) }
        XCTAssertFalse(exampleKeys.isEmpty)
        let goldenRoot = try XCTUnwrap(try JSONSerialization.jsonObject(with: try golden("full")) as? Json)
        var goldenKeys = Set<String>()
        for k in ["exercises", "programs", "breaths"] { goldenKeys.formUnion(allKeys(goldenRoot[k] ?? [])) }
        XCTAssertEqual(exampleKeys.subtracting(goldenKeys), [], "Felder fehlen in app-generated/full.json")
    }
}

private extension ClaudeOrigin {
    func withDeliveredAt(_ d: Date) -> ClaudeOrigin { var c = self; c.deliveredAt = d; return c }
}
