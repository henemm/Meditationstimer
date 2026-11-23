//
//  ClaudeKennzeichenTests.swift
//  LeanHealthTimerTests
//
//  TDD RED #51 Schnitt 3: Kennzeichen "von Claude", gelieferte Uebungen im Info-Blatt.
//  Rundenspec: DOCS/specs/features/feature-51-s3-kennzeichen.md (AC-1 bis AC-5, Unit-Teil von AC-12).
//  Neue APIs (fehlen noch, daher Compile-Fehler = RED):
//    ClaudeStore.storedExercise(id:defaults:) -> ExerciseInfo?
//    ClaudeStore.badgeText(modifiedAt:) -> String
//

import XCTest
@testable import Lean_Health_Timer

final class ClaudeKennzeichenTests: XCTestCase {

    private var suiteNames: [String] = []

    override func tearDown() {
        for name in suiteNames { UserDefaults().removePersistentDomain(forName: name) }
        suiteNames = []
        super.tearDown()
    }

    // MARK: - Hilfen

    private func makeDefaults() -> UserDefaults {
        let name = "ClaudeKennzeichenTests.\(UUID().uuidString)"
        suiteNames.append(name)
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func origin(_ itemId: String) -> ClaudeOrigin {
        ClaudeOrigin(itemId: itemId, revision: 1, why: "Weil es dem Ruecken guttut.", packageId: "claude.paket",
                     packageName: "Paket", deliveredAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    private func stored(_ itemId: String, name: String, category: String, effect: String,
                        instructions: String, notes: String? = nil) -> ClaudeStoredExercise {
        ClaudeStoredExercise(id: UUID(), name: name, nameEn: nil, category: category, effect: effect,
                             instructions: instructions, notes: notes, claude: origin(itemId))
    }

    private func seed(_ defaults: UserDefaults, _ exercises: [ClaudeStoredExercise]) throws {
        let state = ClaudeStoredState(exercises: exercises, log: [])
        defaults.set(try JSONEncoder().encode(state), forKey: ClaudeStore.stateKey)
    }

    private func seededDefaults() throws -> UserDefaults {
        let defaults = makeDefaults()
        try seed(defaults, [
            stored("claude.vierfuessler-diagonal", name: "Vierfuessler diagonal", category: "core",
                   effect: "Staerkt den Rumpf.", instructions: "1) Vierfuessler\n2) Arm und Bein strecken"),
            stored("claude.mit-hinweis", name: "Mit Hinweis", category: "core",
                   effect: "Wirkung", instructions: "Ausfuehrung", notes: "Langsam"),
            stored("claude.kategorie-unbekannt", name: "Kategorie unbekannt", category: "unknown",
                   effect: "Wirkung", instructions: "Ausfuehrung")
        ])
        return defaults
    }

    // MARK: - AC-1

    /// Verhalten: Eine von Claude gelieferte Uebung wird ueber ihre Kennung aus dem gespeicherten Zustand gelesen,
    /// mit Name, Kategorie, Wirkung und Ausfuehrung unveraendert.
    func testStoredExerciseResolvesClaudeIdFromState() throws {
        let defaults = try seededDefaults()
        let info = try XCTUnwrap(ClaudeStore.storedExercise(id: "claude.vierfuessler-diagonal", defaults: defaults),
                                 "Gelieferte Uebung wird nicht aufgeloest")
        XCTAssertEqual(info.name, "Vierfuessler diagonal")
        XCTAssertEqual(info.category, .core)
        XCTAssertEqual(info.effect, "Staerkt den Rumpf.")
        XCTAssertEqual(info.instructions, "1) Vierfuessler\n2) Arm und Bein strecken")
        XCTAssertNil(info.notes)
    }

    // MARK: - AC-2 und AC-12 (Unit)

    /// Verhalten: Katalog-, eigene und unbekannte Kennungen sowie ein leerer Zustand liefern nichts;
    /// der Katalog bleibt Sache von `ExerciseDatabase`.
    func testStoredExerciseReturnsNilForUnknownOrBuiltinId() throws {
        let defaults = try seededDefaults()
        XCTAssertNil(ClaudeStore.storedExercise(id: "builtin.planke", defaults: defaults))
        XCTAssertNil(ClaudeStore.storedExercise(id: "own.mein-schritt", defaults: defaults))
        XCTAssertNil(ClaudeStore.storedExercise(id: "claude.gibt-es-nicht", defaults: defaults))
        XCTAssertNil(ClaudeStore.storedExercise(id: "claude.vierfuessler-diagonal", defaults: makeDefaults()),
                     "Leerer claudeState darf nichts liefern")
        XCTAssertNotNil(ClaudeStore.storedExercise(id: "claude.vierfuessler-diagonal", defaults: defaults),
                        "Kontrolle: die gelieferte Uebung selbst muss aufloesbar sein")
    }

    // MARK: - AC-3

    /// Verhalten: Hinweise werden uebernommen; eine unbekannte Kategorie fuehrt nicht zu "nicht verfuegbar",
    /// sondern faellt auf Ganzkoerper zurueck.
    func testExerciseInfoMapsCategoryEffectInstructions() throws {
        let defaults = try seededDefaults()
        let withNotes = try XCTUnwrap(ClaudeStore.storedExercise(id: "claude.mit-hinweis", defaults: defaults))
        XCTAssertEqual(withNotes.notes, "Langsam")
        let unknown = try XCTUnwrap(ClaudeStore.storedExercise(id: "claude.kategorie-unbekannt", defaults: defaults),
                                    "Unbekannte Kategorie darf die Uebung nicht verschwinden lassen")
        XCTAssertEqual(unknown.category, .fullBody)
        XCTAssertEqual(unknown.effect, "Wirkung")
        XCTAssertEqual(unknown.instructions, "Ausfuehrung")
    }

    // MARK: - AC-4 und AC-5

    /// Verhalten: Ohne Bearbeitung steht in der Kapsel nur "von Claude" (ohne Zusatz).
    func testBadgeTextPlainWhenNotModified() {
        let text = ClaudeStore.badgeText(modifiedAt: nil)
        XCTAssertTrue(text.localizedCaseInsensitiveContains("Claude"), "Kapseltext nennt Claude nicht: \(text)")
        XCTAssertFalse(text.contains("·"), "Ohne Bearbeitung kein Zusatz: \(text)")
        XCTAssertNotEqual(text, text.uppercased(), "Kapseltext erscheint als Grossbuchstaben-Schluessel: \(text)")
    }

    /// Verhalten: Nach Bearbeitung durch Henning steht "von Claude · angepasst"; der Grundtext bleibt Teil davon.
    func testBadgeTextShowsAngepasstWhenModified() {
        let plain = ClaudeStore.badgeText(modifiedAt: nil)
        let edited = ClaudeStore.badgeText(modifiedAt: Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertNotEqual(edited, plain)
        XCTAssertTrue(edited.hasPrefix(plain), "Bearbeiteter Text beginnt nicht mit dem Grundtext: \(edited)")
        XCTAssertTrue(edited.contains("·"), "Trenner fehlt: \(edited)")
        XCTAssertNotEqual(edited, edited.uppercased(), "Kapseltext erscheint als Grossbuchstaben-Schluessel: \(edited)")
    }
}
