//
//  ExerciseCatalogTests.swift
//  LeanHealthTimerTests
//
//  TDD RED Phase #48: Übungskatalog mit festen Kennungen.
//  Oberfläche laut docs/artifacts/feature-48-uebungskatalog/test-api-vertrag.md.
//

import XCTest
@testable import Lean_Health_Timer

final class ExerciseCatalogTests: XCTestCase {

    // MARK: - Hilfen

    private struct JsonEntry: Decodable { let id: String; let name: String; let category: String }
    private struct JsonCatalog: Decodable { let catalogVersion: Int; let exercises: [JsonEntry] }

    private func loadJson(file: StaticString = #filePath) throws -> JsonCatalog {
        let testFile = URL(fileURLWithPath: "\(file)")
        let url = testFile.deletingLastPathComponent()
            .appendingPathComponent("../Contracts/catalog/builtin-exercises.json").standardized
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(JsonCatalog.self, from: data)
    }

    private let idRegex = #"^(builtin|own|claude)\.[a-z0-9][a-z0-9-]{1,62}$"#

    private func langBundle(_ code: String) throws -> Bundle {
        let app = Bundle(for: Tracker.self)
        let path = try XCTUnwrap(app.path(forResource: code, ofType: "lproj"), "Sprach-Bundle \(code) fehlt")
        return try XCTUnwrap(Bundle(path: path))
    }

    /// Heutige 43 Einträge (Stand vor #48) aus Contracts/catalog/builtin-exercises.json.
    private let first43: [(id: String, name: String, category: String)] = [
        ("builtin.burpees", "Burpees", "fullBody"),
        ("builtin.mountain-climbers", "Mountain Climbers", "cardio"),
        ("builtin.high-knees", "High Knees", "cardio"),
        ("builtin.hampelmaenner", "Hampelmänner", "cardio"),
        ("builtin.butt-kicks", "Butt Kicks", "cardio"),
        ("builtin.marschieren-auf-der-stelle", "Marschieren auf der Stelle", "warmup"),
        ("builtin.jump-kniebeugen", "Jump-Kniebeugen", "legs"),
        ("builtin.planke", "Planke", "core"),
        ("builtin.planke-knie", "Planke (Knie)", "core"),
        ("builtin.seitliche-planke-links", "Seitliche Planke links", "core"),
        ("builtin.seitliche-planke-rechts", "Seitliche Planke rechts", "core"),
        ("builtin.fahrrad-crunches", "Fahrrad-Crunches", "core"),
        ("builtin.beinheben", "Beinheben", "core"),
        ("builtin.russian-twists", "Russian Twists", "core"),
        ("builtin.kniebeugen", "Kniebeugen", "legs"),
        ("builtin.ausfallschritte", "Ausfallschritte", "legs"),
        ("builtin.reverse-ausfallschritte", "Reverse-Ausfallschritte", "legs"),
        ("builtin.ausfallschritte-gehend", "Ausfallschritte gehend", "legs"),
        ("builtin.glute-bridges", "Glute Bridges", "legs"),
        ("builtin.einbeiniges-kreuzheben-links", "Einbeiniges Kreuzheben links", "legs"),
        ("builtin.einbeiniges-kreuzheben-rechts", "Einbeiniges Kreuzheben rechts", "legs"),
        ("builtin.bulgarische-split-kniebeugen-links", "Bulgarische Split-Kniebeugen links", "legs"),
        ("builtin.bulgarische-split-kniebeugen-rechts", "Bulgarische Split-Kniebeugen rechts", "legs"),
        ("builtin.wadenheben", "Wadenheben", "legs"),
        ("builtin.knieheben-stehend", "Knieheben stehend", "legs"),
        ("builtin.liegestuetze", "Liegestütze", "upperBody"),
        ("builtin.wandliegestuetze", "Wandliegestütze", "upperBody"),
        ("builtin.diamond-liegestuetze", "Diamond-Liegestütze", "upperBody"),
        ("builtin.breite-liegestuetze", "Breite Liegestütze", "upperBody"),
        ("builtin.pike-liegestuetze", "Pike-Liegestütze", "upperBody"),
        ("builtin.planke-zu-herabschauender-hund", "Planke zu Herabschauender Hund", "fullBody"),
        ("builtin.quadrizeps-dehnung-links", "Quadrizeps-Dehnung links", "stretching"),
        ("builtin.quadrizeps-dehnung-rechts", "Quadrizeps-Dehnung rechts", "stretching"),
        ("builtin.hamstring-dehnung-links", "Hamstring-Dehnung links", "stretching"),
        ("builtin.hamstring-dehnung-rechts", "Hamstring-Dehnung rechts", "stretching"),
        ("builtin.hueftbeuger-dehnung-links", "Hüftbeuger-Dehnung links", "stretching"),
        ("builtin.hueftbeuger-dehnung-rechts", "Hüftbeuger-Dehnung rechts", "stretching"),
        ("builtin.waden-dehnung-links", "Waden-Dehnung links", "stretching"),
        ("builtin.waden-dehnung-rechts", "Waden-Dehnung rechts", "stretching"),
        ("builtin.schmetterlings-dehnung", "Schmetterlings-Dehnung", "stretching"),
        ("builtin.kindspose", "Kindspose", "cooldown"),
        ("builtin.beinpendel", "Beinpendel", "warmup"),
        ("builtin.hueftkreisen", "Hüftkreisen", "warmup"),
    ]

    /// Frühere englische Vorschlagsnamen bestehender Katalogübungen (Spec-Tabelle, 37 Zeilen).
    private let englishExisting: [(en: String, id: String)] = [
        ("Plank", "builtin.planke"),
        ("Side Plank Left", "builtin.seitliche-planke-links"),
        ("Side Plank Right", "builtin.seitliche-planke-rechts"),
        ("Bicycle Crunches", "builtin.fahrrad-crunches"),
        ("Leg Raises", "builtin.beinheben"),
        ("Plank to Downward Dog", "builtin.planke-zu-herabschauender-hund"),
        ("Push-ups", "builtin.liegestuetze"),
        ("Diamond Push-ups", "builtin.diamond-liegestuetze"),
        ("Wide Push-ups", "builtin.breite-liegestuetze"),
        ("Pike Push-ups", "builtin.pike-liegestuetze"),
        ("Wall Push-ups", "builtin.wandliegestuetze"),
        ("Squats", "builtin.kniebeugen"),
        ("Jump Squats", "builtin.jump-kniebeugen"),
        ("Lunges", "builtin.ausfallschritte"),
        ("Reverse Lunges", "builtin.reverse-ausfallschritte"),
        ("Walking Lunges", "builtin.ausfallschritte-gehend"),
        ("Bulgarian Split Squats Left", "builtin.bulgarische-split-kniebeugen-links"),
        ("Bulgarian Split Squats Right", "builtin.bulgarische-split-kniebeugen-rechts"),
        ("Single-Leg Deadlift Left", "builtin.einbeiniges-kreuzheben-links"),
        ("Single-Leg Deadlift Right", "builtin.einbeiniges-kreuzheben-rechts"),
        ("Calf Raises", "builtin.wadenheben"),
        ("Standing Knee Raises", "builtin.knieheben-stehend"),
        ("Jumping Jacks", "builtin.hampelmaenner"),
        ("Marching in Place", "builtin.marschieren-auf-der-stelle"),
        ("Child's Pose", "builtin.kindspose"),
        ("Butterfly Stretch", "builtin.schmetterlings-dehnung"),
        ("Hip Flexor Stretch Left", "builtin.hueftbeuger-dehnung-links"),
        ("Hip Flexor Stretch Right", "builtin.hueftbeuger-dehnung-rechts"),
        ("Quadriceps Stretch Left", "builtin.quadrizeps-dehnung-links"),
        ("Quadriceps Stretch Right", "builtin.quadrizeps-dehnung-rechts"),
        ("Hamstring Stretch Left", "builtin.hamstring-dehnung-links"),
        ("Hamstring Stretch Right", "builtin.hamstring-dehnung-rechts"),
        ("Calf Stretch Left", "builtin.waden-dehnung-links"),
        ("Calf Stretch Right", "builtin.waden-dehnung-rechts"),
        ("Hip Circles", "builtin.hueftkreisen"),
        ("Leg Swing Left", "builtin.beinpendel"),
        ("Leg Swing Right", "builtin.beinpendel"),
    ]

    /// Die 24 neuen Katalogübungen (Spec-Tabelle): Kennung, deutscher Name, englischer Name, Kategorie.
    private let newExercises: [(id: String, de: String, en: String, category: String)] = [
        ("builtin.hollow-hold", "Hollow Hold", "Hollow Hold", "core"),
        ("builtin.dead-bug", "Dead Bug", "Dead Bug", "core"),
        ("builtin.flutter-kicks", "Flutter Kicks", "Flutter Kicks", "core"),
        ("builtin.v-ups", "V-Ups", "V-Ups", "core"),
        ("builtin.sit-ups", "Sit-ups", "Sit-ups", "core"),
        ("builtin.crunches", "Crunches", "Crunches", "core"),
        ("builtin.archer-liegestuetze", "Archer-Liegestütze", "Archer Push-ups", "upperBody"),
        ("builtin.decline-liegestuetze", "Decline-Liegestütze", "Decline Push-ups", "upperBody"),
        ("builtin.dips", "Dips", "Dips", "upperBody"),
        ("builtin.klimmzuege", "Klimmzüge", "Pull-ups", "upperBody"),
        ("builtin.chin-ups", "Chin-ups", "Chin-ups", "upperBody"),
        ("builtin.australische-klimmzuege", "Australische Klimmzüge", "Australian Pull-ups", "upperBody"),
        ("builtin.umgekehrtes-rudern", "Umgekehrtes Rudern", "Inverted Rows", "upperBody"),
        ("builtin.step-ups", "Step-ups", "Step-ups", "legs"),
        ("builtin.wandsitzen", "Wandsitzen", "Wall-Sit", "legs"),
        ("builtin.box-jumps", "Box Jumps", "Box Jumps", "legs"),
        ("builtin.skater-hops", "Skater Hops", "Skater Hops", "cardio"),
        ("builtin.seilspringen", "Seilspringen", "Jump Rope", "cardio"),
        ("builtin.herabschauender-hund", "Herabschauender Hund", "Downward Dog", "stretching"),
        ("builtin.cobra-dehnung", "Kobra-Dehnung", "Cobra Stretch", "stretching"),
        ("builtin.cat-cow", "Katze-Kuh", "Cat-Cow", "warmup"),
        ("builtin.sitzende-vorbeuge", "Vorbeuge im Sitzen", "Seated Forward Bend", "stretching"),
        ("builtin.schulter-dehnung-links", "Schulter-Dehnung links", "Shoulder Stretch Left", "stretching"),
        ("builtin.schulter-dehnung-rechts", "Schulter-Dehnung rechts", "Shoulder Stretch Right", "stretching"),
    ]

    // MARK: - AC-1

    /// AC-1: Given die Vertrags-JSON, When sie mit dem Katalog verglichen wird,
    /// Then gleiche Anzahl, Reihenfolge, Kennung, Name und Kategorie (Endstand 67).
    func test_catalog_matchesBuiltinExercisesJson() throws {
        let json = try loadJson()
        let catalog = ExerciseDatabase.catalog
        XCTAssertGreaterThanOrEqual(json.exercises.count, 43, "JSON-Vertrag zu klein gelesen")
        XCTAssertEqual(json.exercises.count, 67, "Endstand: JSON hat 67 Einträge")
        XCTAssertEqual(catalog.count, 67, "Endstand: Katalog hat 67 Einträge")
        XCTAssertEqual(catalog.count, json.exercises.count)
        for (index, entry) in json.exercises.enumerated() where index < catalog.count {
            XCTAssertEqual(catalog[index].id, entry.id, "Kennung an Position \(index)")
            XCTAssertEqual(catalog[index].name, entry.name, "Name an Position \(index)")
            XCTAssertEqual(String(describing: catalog[index].category), entry.category, "Kategorie an Position \(index)")
        }
    }

    // MARK: - AC-2

    /// AC-2: Given alle Katalogkennungen, When gegen die Regex geprüft, Then passt jede und keine doppelt.
    func test_catalogIds_matchRegexAndAreUnique() {
        let ids = ExerciseDatabase.catalog.map(\.id)
        XCTAssertGreaterThanOrEqual(ids.count, 43)
        for id in ids {
            XCTAssertNotNil(id.range(of: idRegex, options: .regularExpression), "Ungültige Kennung \(id)")
        }
        XCTAssertEqual(Set(ids).count, ids.count, "Doppelte Kennung im Katalog")
    }

    // MARK: - AC-3

    /// AC-3: Given ein deutscher Katalogname, When die Kennung abgeleitet wird, Then die Kennung dieser Übung.
    func test_idForGermanName_returnsBuiltinId() {
        XCTAssertEqual(ExerciseDatabase.exerciseId(forName: "Planke"), "builtin.planke")
        XCTAssertGreaterThanOrEqual(ExerciseDatabase.catalog.count, 43)
        for info in ExerciseDatabase.catalog {
            XCTAssertEqual(ExerciseDatabase.exerciseId(forName: info.name), info.id, "Name \(info.name)")
        }
    }

    // MARK: - AC-4

    /// AC-4: Given die 37 früheren englischen Namen und die 24 englischen Namen der neuen Übungen,
    /// When die Kennung abgeleitet wird, Then die Kennung laut Spec-Tabelle.
    func test_idForEnglishName_returnsBuiltinId() {
        XCTAssertEqual(englishExisting.count, 37)
        for row in englishExisting {
            XCTAssertEqual(ExerciseDatabase.exerciseId(forName: row.en), row.id, "Englischer Name \(row.en)")
        }
        XCTAssertEqual(newExercises.count, 24)
        for row in newExercises {
            XCTAssertEqual(ExerciseDatabase.exerciseId(forName: row.en), row.id, "Englischer Name \(row.en)")
        }
        XCTAssertEqual(ExerciseDatabase.exerciseId(forName: "  plank "), "builtin.planke", "Groß/Klein und Ränder egal")
    }

    // MARK: - AC-5

    /// AC-5: Given „Beinpendel links/rechts", When die Kennung abgeleitet wird, Then builtin.beinpendel.
    func test_idForNameWithLeftRightSuffix_resolvesBase() {
        XCTAssertEqual(ExerciseDatabase.exerciseId(forName: "Beinpendel links"), "builtin.beinpendel")
        XCTAssertEqual(ExerciseDatabase.exerciseId(forName: "Beinpendel rechts"), "builtin.beinpendel")
        XCTAssertEqual(ExerciseDatabase.exerciseId(forName: "beinpendel LINKS "), "builtin.beinpendel")
    }

    /// AC-5: Given ein „links"-Name ohne Grundname im Katalog, When abgeleitet, Then own.*.
    func test_idForUnknownSuffixName_isOwn() {
        XCTAssertEqual(ExerciseDatabase.exerciseId(forName: "Zaubertanz links"), "own.zaubertanz-links")
        XCTAssertEqual(ExerciseDatabase.exerciseId(forName: "Mein Lauf!"), "own.mein-lauf")
    }

    // MARK: - AC-6

    /// AC-6: Given builtin/own/claude-Kennungen, When die Herkunft gelesen wird, Then aus dem Präfix.
    func test_origin_derivedFromPrefix() throws {
        XCTAssertEqual(ExerciseOrigin(exerciseId: "builtin.planke"), .builtin)
        XCTAssertEqual(ExerciseOrigin(exerciseId: "own.mein-lauf"), .own)
        XCTAssertEqual(ExerciseOrigin(exerciseId: "claude.x1"), .claude)
        XCTAssertNil(ExerciseOrigin(exerciseId: "foo.bar"))
        XCTAssertNil(ExerciseOrigin(exerciseId: "planke"))
        let planke = try XCTUnwrap(ExerciseDatabase.info(forId: "builtin.planke"))
        XCTAssertEqual(planke.origin, .builtin)
    }

    // MARK: - AC-7

    /// AC-7: Given der früher gespeicherte Name „Plank", When der Info-Knopf sucht (Ableitung, dann Suche per Kennung),
    /// Then „Planke" mit Wirkung und Anleitung.
    func test_infoForEnglishName_findsCatalogEntry() throws {
        let info = try XCTUnwrap(ExerciseDatabase.info(forId: ExerciseDatabase.exerciseId(forName: "Plank")))
        XCTAssertEqual(info.name, "Planke")
        XCTAssertFalse(info.effect.isEmpty)
        XCTAssertFalse(info.instructions.isEmpty)
    }

    // MARK: - AC-8

    /// AC-8: Given die Tabelle der 24 neuen Übungen, When der Katalog geladen wird,
    /// Then Kennung, deutscher Name, Kategorie und Texte DE/EN (Wirkung DE ≠ EN) vorhanden.
    func test_newExercises_haveTextsInDeAndEn_andCategory() throws {
        let de = try langBundle("de")
        let en = try langBundle("en")
        for row in newExercises {
            let info = try XCTUnwrap(ExerciseDatabase.info(forId: row.id), "Kennung \(row.id) fehlt")
            XCTAssertEqual(info.name, row.de, row.id)
            XCTAssertEqual(String(describing: info.category), row.category, row.id)
            let tDe = try XCTUnwrap(ExerciseDatabase.localizedTexts(forId: row.id, bundle: de), "DE \(row.id)")
            let tEn = try XCTUnwrap(ExerciseDatabase.localizedTexts(forId: row.id, bundle: en), "EN \(row.id)")
            XCTAssertFalse(tDe.effect.isEmpty, "DE Wirkung \(row.id)")
            XCTAssertFalse(tDe.instructions.isEmpty, "DE Anleitung \(row.id)")
            XCTAssertFalse(tEn.effect.isEmpty, "EN Wirkung \(row.id)")
            XCTAssertFalse(tEn.instructions.isEmpty, "EN Anleitung \(row.id)")
            XCTAssertEqual(tEn.name, row.en, "Englischer Name \(row.id)")
            XCTAssertNotEqual(tEn.effect, tDe.effect, "Englische Wirkung nicht übersetzt \(row.id)")
        }
    }

    /// AC-8: Given der Endstand nach A2d-2, When Katalog und JSON gelesen werden, Then 67 Einträge und catalogVersion 2.
    func test_catalog_has67EntriesAndVersion2() throws {
        let json = try loadJson()
        XCTAssertEqual(ExerciseDatabase.catalog.count, 67)
        XCTAssertEqual(json.catalogVersion, 2)
    }

    // MARK: - AC-9

    /// AC-9: Given die heutigen 43 Einträge, When der Katalog erweitert ist, Then stehen sie unverändert vorn
    /// (append-only) in Katalog und JSON; die Erweiterung existiert bereits (mehr als 43).
    func test_first43Entries_unchanged() throws {
        XCTAssertEqual(first43.count, 43)
        let json = try loadJson()
        let catalog = ExerciseDatabase.catalog
        XCTAssertGreaterThan(catalog.count, 43, "Erweiterung um die 24 neuen fehlt")
        XCTAssertGreaterThan(json.exercises.count, 43, "JSON nicht erweitert")
        for (index, row) in first43.enumerated() {
            guard index < catalog.count, index < json.exercises.count else { XCTFail("Eintrag \(index) fehlt"); continue }
            XCTAssertEqual(catalog[index].id, row.id, "Katalog Kennung \(index)")
            XCTAssertEqual(catalog[index].name, row.name, "Katalog Name \(index)")
            XCTAssertEqual(String(describing: catalog[index].category), row.category, "Katalog Kategorie \(index)")
            XCTAssertEqual(json.exercises[index].id, row.id, "JSON Kennung \(index)")
            XCTAssertEqual(json.exercises[index].name, row.name, "JSON Name \(index)")
            XCTAssertEqual(json.exercises[index].category, row.category, "JSON Kategorie \(index)")
        }
    }

    // MARK: - AC-27

    /// AC-27: Given die Vorgabeprogramme, When sie gebaut werden, Then trägt jeder Schritt eine builtin.-Kennung,
    /// die im Katalog existiert.
    func test_defaultPrograms_referenceExistingCatalogIds() {
        XCTAssertFalse(defaultWorkoutSets.isEmpty)
        for set in defaultWorkoutSets {
            for phase in set.phases {
                guard let id = phase.exerciseId else {
                    XCTFail("Schritt \(phase.name) in \(set.name) ohne exerciseId"); continue
                }
                XCTAssertTrue(id.hasPrefix("builtin."), "\(id) ohne Präfix builtin.")
                XCTAssertNotNil(ExerciseDatabase.info(forId: id), "\(id) nicht im Katalog")
            }
        }
    }
}
