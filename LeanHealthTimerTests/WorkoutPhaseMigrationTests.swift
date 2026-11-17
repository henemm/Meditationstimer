//
//  WorkoutPhaseMigrationTests.swift
//  LeanHealthTimerTests
//
//  TDD RED Phase #48: Schritt-Modell (exerciseId, hint), Laden/Sicherung, Ansagetext, Auswahl.
//  Oberfläche laut DOCS/context/feature-48-test-api-vertrag.md.
//

import XCTest
@testable import Lean_Health_Timer

final class WorkoutPhaseMigrationTests: XCTestCase {

    private let storeKey = "workoutProgramSets"
    private var suiteNames: [String] = []

    override func tearDown() {
        for name in suiteNames { UserDefaults().removePersistentDomain(forName: name) }
        suiteNames = []
        super.tearDown()
    }

    // MARK: - Hilfen

    private func makeDefaults() -> UserDefaults {
        let name = "WorkoutPhaseMigrationTests.\(UUID().uuidString)"
        suiteNames.append(name)
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func langBundle(_ code: String) throws -> Bundle {
        let app = Bundle(for: Tracker.self)
        let path = try XCTUnwrap(app.path(forResource: code, ofType: "lproj"), "Sprach-Bundle \(code) fehlt")
        return try XCTUnwrap(Bundle(path: path))
    }

    private func decodeSets(_ json: String) throws -> [WorkoutSet] {
        try JSONDecoder().decode([WorkoutSet].self, from: Data(json.utf8))
    }

    private func decodePhase(_ json: String) throws -> WorkoutPhase {
        try JSONDecoder().decode(WorkoutPhase.self, from: Data(json.utf8))
    }

    private func oldPhaseJson(name: String) -> String {
        #"{"id":"11111111-1111-1111-1111-111111111111","name":"\#(name)","workDuration":30,"restDuration":10}"#
    }

    private let idRegex = #"^(builtin|own|claude)\.[a-z0-9][a-z0-9-]{1,62}$"#

    private let oldJson = """
    [
      {"id":"AAAAAAAA-0000-0000-0000-000000000001","name":"Core Circuit","repetitions":3,"emoji":"🔥",
       "phases":[
         {"id":"BBBBBBBB-0000-0000-0000-000000000001","name":"Planke","workDuration":30,"restDuration":10},
         {"id":"BBBBBBBB-0000-0000-0000-000000000002","name":"Plank","workDuration":40,"restDuration":15}
       ]},
      {"id":"AAAAAAAA-0000-0000-0000-000000000002","name":"Eigenes","repetitions":2,"emoji":"💪",
       "phases":[
         {"id":"BBBBBBBB-0000-0000-0000-000000000003","name":"Mein Lauf!","workDuration":20,"restDuration":5}
       ]}
    ]
    """

    // MARK: - AC-10

    /// AC-10: Given JSON im alten Format, When es dekodiert wird, Then bleibt alles gleich,
    /// hint ist nil und exerciseId abgeleitet.
    func test_oldJson_loadsLossless() throws {
        let sets = try decodeSets(oldJson)
        XCTAssertEqual(sets.count, 2)
        XCTAssertEqual(sets[0].id, UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001"))
        XCTAssertEqual(sets[0].name, "Core Circuit")
        XCTAssertEqual(sets[0].repetitions, 3)
        XCTAssertEqual(sets[0].emoji, "🔥")
        XCTAssertEqual(sets[0].phases.count, 2)
        XCTAssertEqual(sets[0].phases[0].id, UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000001"))
        XCTAssertEqual(sets[0].phases[0].name, "Planke")
        XCTAssertEqual(sets[0].phases[0].workDuration, 30)
        XCTAssertEqual(sets[0].phases[0].restDuration, 10)
        XCTAssertEqual(sets[0].phases[1].name, "Plank")
        XCTAssertEqual(sets[0].phases[1].workDuration, 40)
        XCTAssertEqual(sets[0].phases[1].restDuration, 15)
        XCTAssertEqual(sets[1].name, "Eigenes")
        XCTAssertEqual(sets[1].repetitions, 2)
        XCTAssertEqual(sets[1].emoji, "💪")
        XCTAssertEqual(sets[1].phases[0].workDuration, 20)
        XCTAssertEqual(sets[1].phases[0].restDuration, 5)
        for phase in sets.flatMap(\.phases) { XCTAssertNil(phase.hint) }
        XCTAssertEqual(sets[0].phases[0].exerciseId, "builtin.planke")
        XCTAssertEqual(sets[0].phases[1].exerciseId, "builtin.planke")
        XCTAssertEqual(sets[1].phases[0].exerciseId, "own.mein-lauf")
    }

    // MARK: - AC-11

    /// AC-11: Given alte Schritte ohne Kennung, When sie geladen werden, Then Kennung aus dem Namen
    /// und der gespeicherte Name wörtlich erhalten.
    func test_missingExerciseId_derivedFromName() throws {
        let cases: [(name: String, id: String)] = [
            ("Planke", "builtin.planke"),
            ("Plank", "builtin.planke"),
            ("Beinpendel links", "builtin.beinpendel"),
            ("Mein Lauf!", "own.mein-lauf"),
        ]
        for c in cases {
            let phase = try decodePhase(oldPhaseJson(name: c.name))
            XCTAssertEqual(phase.exerciseId, c.id, c.name)
            XCTAssertEqual(phase.name, c.name, "Name bleibt wörtlich")
        }
        // Leere oder nur aus Leerraum bestehende Kennung gilt als fehlend
        for stored in ["", "   "] {
            let json = #"{"id":"11111111-1111-1111-1111-111111111111","name":"Planke","workDuration":30,"restDuration":10,"exerciseId":"\#(stored)"}"#
            XCTAssertEqual(try decodePhase(json).exerciseId, "builtin.planke", "Kennung '\(stored)'")
        }
        let nullJson = #"{"id":"11111111-1111-1111-1111-111111111111","name":"Planke","workDuration":30,"restDuration":10,"exerciseId":null}"#
        XCTAssertEqual(try decodePhase(nullJson).exerciseId, "builtin.planke")
    }

    // MARK: - AC-12

    /// AC-12: Given die Namen der Slug-Regel, When own.<slug> gebildet wird, Then die erwarteten Kennungen;
    /// jede Ausgabe passt zur Regex.
    func test_ownSlug_rules() {
        let cases: [(String, String)] = [
            ("Übung 1", "own.uebung-1"),
            ("Ä", "own.ae"),
            ("!!", "own.uebung"),
            ("", "own.uebung"),
            ("Mein Lauf!", "own.mein-lauf"),
            ("Größe ß", "own.groesse-ss"),
            ("  --Hallo   Welt--  ", "own.hallo-welt"),
        ]
        for (name, expected) in cases {
            XCTAssertEqual(ExerciseDatabase.ownExerciseId(forName: name), expected, "Name '\(name)'")
        }
        let long = String(repeating: "a", count: 100)
        let longId = ExerciseDatabase.ownExerciseId(forName: long)
        let slug = String(longId.dropFirst("own.".count))
        XCTAssertLessThanOrEqual(slug.count, 63)
        XCTAssertFalse(slug.hasSuffix("-"))
        // Abschneiden mitten in einer Trennstelle: danach folgende "-" entfernen
        let withDashes = String(repeating: "a", count: 62) + " b"
        let dashId = ExerciseDatabase.ownExerciseId(forName: withDashes)
        XCTAssertFalse(dashId.hasSuffix("-"))
        XCTAssertLessThanOrEqual(dashId.count - "own.".count, 63)
        for name in cases.map(\.0) + [long, withDashes, "x", "é", "日本語"] {
            let id = ExerciseDatabase.ownExerciseId(forName: name)
            XCTAssertNotNil(id.range(of: idRegex, options: .regularExpression), "Ungültig: \(id) für '\(name)'")
        }
    }

    // MARK: - AC-13

    /// AC-13: Given ein Schritt mit exerciseId und hint, When kodiert und dekodiert wird, Then alles gleich.
    func test_roundTrip_keepsExerciseIdAndHint() throws {
        let phase = WorkoutPhase(name: "Planke", workDuration: 45, restDuration: 12,
                                 exerciseId: "builtin.planke", hint: "Hüfte hoch halten")
        let data = try JSONEncoder().encode(phase)
        let back = try JSONDecoder().decode(WorkoutPhase.self, from: data)
        XCTAssertEqual(back, phase)
        XCTAssertEqual(back.exerciseId, "builtin.planke")
        XCTAssertEqual(back.hint, "Hüfte hoch halten")
        XCTAssertEqual(back.workDuration, 45)
        XCTAssertEqual(back.restDuration, 12)
    }

    /// AC-13: Given gespeicherte exerciseId und davon abweichender Name, When geladen wird,
    /// Then bleibt die Kennung (keine Neuberechnung).
    func test_storedExerciseId_notRecomputed() throws {
        let json = #"{"id":"11111111-1111-1111-1111-111111111111","name":"Planke","workDuration":30,"restDuration":10,"exerciseId":"own.x-1"}"#
        let phase = try decodePhase(json)
        XCTAssertEqual(phase.exerciseId, "own.x-1")
        XCTAssertEqual(phase.name, "Planke")
    }

    // MARK: - AC-14

    /// AC-14: Given die Hinweisfälle der Spec, When normalisiert wird, Then erwartete Ergebnisse;
    /// Kürzung auf 80 UTF-16-Einheiten ohne halbes Zeichen; auch beim Dekodieren.
    func test_hint_normalization() throws {
        XCTAssertEqual(WorkoutPhase.normalizedHint("  langsam  "), "langsam")
        XCTAssertEqual(WorkoutPhase.normalizedHint("a\nb"), "a b")
        XCTAssertEqual(WorkoutPhase.normalizedHint("a\tb"), "a b")
        XCTAssertEqual(WorkoutPhase.normalizedHint("a\u{2028}b"), "a b")
        XCTAssertNil(WorkoutPhase.normalizedHint(""))
        XCTAssertNil(WorkoutPhase.normalizedHint("   "))
        XCTAssertNil(WorkoutPhase.normalizedHint("\u{00A0}"))
        XCTAssertNil(WorkoutPhase.normalizedHint(nil))

        // Weitere verbotene Zeichen und Läufe von Leerraum
        XCTAssertEqual(WorkoutPhase.normalizedHint("a\u{0007}b"), "a b")
        XCTAssertEqual(WorkoutPhase.normalizedHint("a\u{0085}b"), "a b")
        XCTAssertEqual(WorkoutPhase.normalizedHint("a\u{200E}b"), "a b")
        XCTAssertEqual(WorkoutPhase.normalizedHint("a\n\nb"), "a b")
        XCTAssertEqual(WorkoutPhase.normalizedHint("a   b"), "a b")
        for raw in ["  a \n\t b  ", "a\u{00A0}\u{2029}b", String(repeating: "ab ", count: 40) + "💪"] {
            let once = WorkoutPhase.normalizedHint(raw)
            XCTAssertEqual(WorkoutPhase.normalizedHint(once), once, "Nicht idempotent für '\(raw)'")
        }

        // 79 "a" + Emoji (2 UTF-16-Einheiten) = 81 -> darf das Emoji nicht zerreißen
        let emojiCase = String(repeating: "a", count: 79) + "💪"
        let cut = try XCTUnwrap(WorkoutPhase.normalizedHint(emojiCase))
        XCTAssertLessThanOrEqual(cut.utf16.count, 80)
        XCTAssertEqual(String(decoding: Array(cut.utf16), as: UTF16.self), cut)
        let last = try XCTUnwrap(cut.utf16.last)
        XCTAssertFalse((0xD800...0xDFFF).contains(last), "Endet auf einsames Surrogat")

        let longA = try XCTUnwrap(WorkoutPhase.normalizedHint(String(repeating: "a", count: 100)))
        XCTAssertEqual(longA.utf16.count, 80)

        // Beim Dekodieren gleichermaßen
        let json = #"{"id":"11111111-1111-1111-1111-111111111111","name":"Planke","workDuration":30,"restDuration":10,"hint":"a\nb"}"#
        XCTAssertEqual(try decodePhase(json).hint, "a b")
    }

    // MARK: - AC-15

    /// AC-15: Given nicht dekodierbare Daten unter workoutProgramSets, When geladen wird, Then nil und die Rohdaten
    /// liegen byte-gleich unter dem Sicherungsschlüssel; ein vorhandener Schlüssel derselben Sekunde bleibt unverändert.
    func test_corruptJson_isBackedUpBeforeFallback() throws {
        let defaults = makeDefaults()
        let raw = Data([0x7B, 0x22, 0xFF, 0xFE, 0x00, 0x5B])
        defaults.set(raw, forKey: storeKey)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertNil(WorkoutSet.loadStored(from: defaults, key: storeKey, now: now))

        let backupKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(WorkoutSet.backupKeyPrefix) }
        XCTAssertEqual(backupKeys.count, 1)
        let firstKey = try XCTUnwrap(backupKeys.first)
        XCTAssertEqual(defaults.data(forKey: firstKey), raw, "Sicherung nicht byte-gleich")

        // Zweiter Fall: Sicherungsschlüssel derselben Sekunde existiert schon mit anderen Bytes
        let defaults2 = makeDefaults()
        let existingKey = WorkoutSet.backupKeyPrefix + "1800000000"
        let existing = Data([0x01, 0x02, 0x03])
        defaults2.set(existing, forKey: existingKey)
        let raw2 = Data([0x5B, 0x7B, 0xEE])
        defaults2.set(raw2, forKey: storeKey)

        XCTAssertNil(WorkoutSet.loadStored(from: defaults2, key: storeKey, now: now))

        XCTAssertEqual(defaults2.data(forKey: existingKey), existing, "Vorhandene Sicherung überschrieben")
        let others = defaults2.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(WorkoutSet.backupKeyPrefix) && $0 != existingKey }
        XCTAssertEqual(others.count, 1, "Neue Rohdaten müssen unter weiterem Schlüssel liegen")
        let otherKey = try XCTUnwrap(others.first)
        XCTAssertEqual(otherKey, existingKey + "-2", "Ausweichen mit Suffix -2")
        XCTAssertEqual(defaults2.data(forKey: otherKey), raw2)
        XCTAssertEqual(defaults2.data(forKey: storeKey), raw2, "Originalschlüssel bleibt mit Rohdaten stehen")

        // Erneutes Laden derselben kaputten Daten, auch später: keine weitere Sicherung
        let later = Date(timeIntervalSince1970: 1_800_000_100)
        XCTAssertNil(WorkoutSet.loadStored(from: defaults2, key: storeKey, now: now))
        XCTAssertNil(WorkoutSet.loadStored(from: defaults2, key: storeKey, now: later))
        let afterReload = defaults2.dictionaryRepresentation().keys.filter { $0.hasPrefix(WorkoutSet.backupKeyPrefix) }
        XCTAssertEqual(Set(afterReload), [existingKey, existingKey + "-2"], "Byte-gleiche Daten doppelt gesichert")
    }

    // MARK: - AC-16

    /// AC-16: Given fehlender Schlüssel (Erststart) oder gültiges JSON, When geladen wird,
    /// Then keine Sicherung; bei gültigem JSON kommen die Programme zurück.
    func test_noBackup_whenKeyMissingOrValid() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let empty = makeDefaults()
        XCTAssertNil(WorkoutSet.loadStored(from: empty, key: storeKey, now: now))
        XCTAssertTrue(empty.dictionaryRepresentation().keys.filter { $0.hasPrefix(WorkoutSet.backupKeyPrefix) }.isEmpty)

        let valid = makeDefaults()
        valid.set(Data(oldJson.utf8), forKey: storeKey)
        let sets = try XCTUnwrap(WorkoutSet.loadStored(from: valid, key: storeKey, now: now))
        XCTAssertEqual(sets.count, 2)
        XCTAssertTrue(valid.dictionaryRepresentation().keys.filter { $0.hasPrefix(WorkoutSet.backupKeyPrefix) }.isEmpty)
    }

    // MARK: - AC-20

    /// AC-20: Given Schritt „Planke" mit und ohne Hinweis, When der Ansagetext gebildet wird,
    /// Then alle vier Satzformen in DE und EN, Hinweis wörtlich angehängt; own-Namen unverändert.
    func test_spokenText_withAndWithoutHint() throws {
        let de = try langBundle("de")
        let en = try langBundle("en")
        let hinted = WorkoutPhase(name: "Planke", workDuration: 30, restDuration: 10,
                                  exerciseId: "builtin.planke", hint: "Hüfte hoch halten")
        let plain = WorkoutPhase(name: "Planke", workDuration: 30, restDuration: 10,
                                 exerciseId: "builtin.planke", hint: nil)
        let spoken = WorkoutAnnouncement.spokenText

        XCTAssertEqual(spoken(.exercise(number: 2, total: 5), hinted, de), "Übung 2 von 5: Planke. Hüfte hoch halten")
        XCTAssertEqual(spoken(.exercise(number: 2, total: 5), plain, de), "Übung 2 von 5: Planke")
        XCTAssertEqual(spoken(.lastExercise, hinted, de), "letzte Übung: Planke. Hüfte hoch halten")
        XCTAssertEqual(spoken(.lastExercise, plain, de), "letzte Übung: Planke")
        XCTAssertEqual(spoken(.round(number: 2, total: 3), hinted, de), "Runde 2 von 3: Planke. Hüfte hoch halten")
        XCTAssertEqual(spoken(.round(number: 2, total: 3), plain, de), "Runde 2 von 3: Planke")
        XCTAssertEqual(spoken(.lastRound, hinted, de), "Letzte Runde: Planke. Hüfte hoch halten")
        XCTAssertEqual(spoken(.lastRound, plain, de), "Letzte Runde: Planke")

        XCTAssertEqual(spoken(.exercise(number: 2, total: 5), hinted, en), "Exercise 2 of 5: Plank. Hüfte hoch halten")
        XCTAssertEqual(spoken(.exercise(number: 2, total: 5), plain, en), "Exercise 2 of 5: Plank")
        XCTAssertEqual(spoken(.lastExercise, hinted, en), "Last exercise: Plank. Hüfte hoch halten")
        XCTAssertEqual(spoken(.lastExercise, plain, en), "Last exercise: Plank")
        XCTAssertEqual(spoken(.round(number: 2, total: 3), hinted, en), "Round 2 of 3: Plank. Hüfte hoch halten")
        XCTAssertEqual(spoken(.round(number: 2, total: 3), plain, en), "Round 2 of 3: Plank")
        XCTAssertEqual(spoken(.lastRound, hinted, en), "Last round: Plank. Hüfte hoch halten")
        XCTAssertEqual(spoken(.lastRound, plain, en), "Last round: Plank")

        let own = WorkoutPhase(name: "Mein Lauf", workDuration: 30, restDuration: 10,
                               exerciseId: "own.mein-lauf", hint: nil)
        XCTAssertEqual(spoken(.exercise(number: 1, total: 2), own, de), "Übung 1 von 2: Mein Lauf")
        XCTAssertEqual(spoken(.exercise(number: 1, total: 2), own, en), "Exercise 1 of 2: Mein Lauf")
    }

    // MARK: - AC-21

    /// AC-21: Given speakExerciseNames aus/an, When die Entscheidungsfunktion gefragt wird,
    /// Then nil bzw. der Text nach AC-20.
    func test_announcement_respectsSpeakSetting() throws {
        let de = try langBundle("de")
        let phase = WorkoutPhase(name: "Planke", workDuration: 30, restDuration: 10,
                                 exerciseId: "builtin.planke", hint: "Hüfte hoch halten")
        let form = WorkoutAnnouncementForm.exercise(number: 2, total: 5)
        XCTAssertNil(WorkoutAnnouncement.textToSpeak(form, phase: phase, speakExerciseNames: false, bundle: de))
        let on = WorkoutAnnouncement.textToSpeak(form, phase: phase, speakExerciseNames: true, bundle: de)
        XCTAssertEqual(on, WorkoutAnnouncement.spokenText(form, phase: phase, bundle: de))
        XCTAssertEqual(on, "Übung 2 von 5: Planke. Hüfte hoch halten")
    }

    // MARK: - AC-23

    /// AC-23: Given eine Auswahl (Katalog bzw. eigene Übung), When sie angewendet wird, Then Kennung und Name
    /// gesetzt, nach Kodieren/Dekodieren unverändert; neuer Schritt trägt den alphabetisch ersten Katalogeintrag.
    func test_selectingCatalogOrOwnExercise_setsExerciseId() throws {
        var phase = WorkoutPhase(name: "Etwas", workDuration: 30, restDuration: 10)
        phase.apply(.catalog(id: "builtin.planke"))
        XCTAssertEqual(phase.exerciseId, "builtin.planke")
        XCTAssertEqual(phase.name, "Planke")
        let backCatalog = try JSONDecoder().decode(WorkoutPhase.self, from: JSONEncoder().encode(phase))
        XCTAssertEqual(backCatalog, phase)

        phase.apply(.own(name: "Mein Lauf"))
        XCTAssertEqual(phase.exerciseId, "own.mein-lauf")
        XCTAssertEqual(phase.name, "Mein Lauf")
        let backOwn = try JSONDecoder().decode(WorkoutPhase.self, from: JSONEncoder().encode(phase))
        XCTAssertEqual(backOwn, phase)
        XCTAssertEqual(backOwn.exerciseId, "own.mein-lauf")
        XCTAssertEqual(backOwn.name, "Mein Lauf")

        let fresh = WorkoutPhase.newDefault(bundle: try langBundle("de"))
        XCTAssertEqual(fresh.exerciseId, "builtin.archer-liegestuetze")
        XCTAssertEqual(fresh.name, "Archer-Liegestütze")
    }

    // MARK: - AC-22 (Anzahl)

    /// AC-22: Given der Katalog als Quelle der Auswahl, When die deutschen Namen gebildet werden, Then 67 Einträge
    /// mit 67 verschiedenen, nicht leeren Namen; der alphabetisch erste ist der Standardname neuer Schritte.
    /// „Eigene Übung…" und die 67 Optionen in der Oberfläche prüft `test_exercisePicker_showsOnlyCatalogNames_german`.
    func test_pickerCatalog_has67DistinctLocalizedNames() throws {
        let de = try langBundle("de")
        let catalog = ExerciseDatabase.catalog
        XCTAssertEqual(catalog.count, 67, "Auswahl muss alle 67 Katalogübungen anbieten")
        let names = catalog.map { ExerciseDatabase.displayName(exerciseId: $0.id, storedName: "", bundle: de) }
        XCTAssertFalse(names.contains(""), "Katalogübung ohne deutschen Namen")
        XCTAssertEqual(Set(names).count, 67, "Deutsche Namen in der Auswahl nicht eindeutig")
        let first = names.sorted { $0.localizedCompare($1) == .orderedAscending }.first
        XCTAssertEqual(WorkoutPhase.newDefault(bundle: de).name, first,
                       "Standardname neuer Schritte muss der alphabetisch erste Auswahleintrag sein")
    }

    // MARK: - AC-30

    /// AC-30: Given ein Bestand mit allen Vorgaben (Zeit verändert) plus eigenem Programm, When die Vorgaben-Migration
    /// läuft, Then bleibt der Bestand unverändert; fehlt eine Vorgabe, wird sie angehängt.
    func test_existingUserStore_unchangedAfterPresetMigration() throws {
        XCTAssertFalse(defaultWorkoutSets.isEmpty)
        var stored = defaultWorkoutSets
        stored[0].phases[0].workDuration += 7
        let custom = try decodeSets(oldJson)[1]
        stored.append(custom)

        let migrated = WorkoutSet.migratingPresets(stored, presets: defaultWorkoutSets)
        XCTAssertEqual(migrated, stored)

        // Zweiter Fall: Bestand ohne eine Vorgabe
        var withoutOne = stored
        let missing = withoutOne.remove(at: 1)
        let migrated2 = WorkoutSet.migratingPresets(withoutOne, presets: defaultWorkoutSets)
        XCTAssertEqual(migrated2.count, withoutOne.count + 1)
        XCTAssertEqual(Array(migrated2.prefix(withoutOne.count)), withoutOne)
        XCTAssertEqual(migrated2.last?.name, missing.name)
    }
}
