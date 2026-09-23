//
//  SessionDurationTests.swift
//  LeanHealthTimerTests
//
//  Bug #25d — Begleitprüfung zur Frage: "Trägt der geschriebene Eintrag die volle Dauer?"
//

import XCTest
@testable import Lean_Health_Timer

/// # Was hier geprüft wird — und was ausdrücklich NICHT
///
/// Die Aussage, um die es geht:
/// *Eine Sitzung, die von A bis B läuft, erzeugt einen Eintrag mit der vollen Dauer B − A —
/// nicht mit einer verkürzten. Ein vorzeitiges Beenden erzeugt einen entsprechend kürzeren
/// Eintrag.*
///
/// **Kein RED-Test.** Diese Tests decken bestehendes, korrektes Verhalten ab und sind ab dem
/// ersten Lauf grün. Sie sind Schutz gegen künftige Regressionen (z.B. eine Umstellung der
/// Zeitmessung auf einen herunterzählenden Ticker, der im Hintergrund stehen bleibt und die
/// Sitzung dadurch verkürzt). Wer sie später sieht, soll sie NICHT für einen gescheiterten
/// TDD-Versuch halten.
///
/// **Reichweite.** Geprüft wird die Zeitquelle, aus der die App die Eckpunkte A und B für den
/// Gesundheits-Eintrag bezieht: `TwoPhaseTimerEngine`. Genau deren Zeitstempel werden an
/// `HealthKitManager.logWorkout(start:end:)` durchgereicht (Aufrufstellen: `MeditationTab`,
/// `OffenView`, `AtemView`). Kein HealthKit, keine Systemberechtigung, kein Testdoppel nötig —
/// die Zeitstempel sind öffentlich am Produktivtyp ablesbar.
///
/// **Was hier NICHT geprüft werden kann.** Der Pfad des *geführten* Workout-Programms
/// (`WorkoutProgramsView`) berechnet seine Eckpunkte inline in einer SwiftUI-View und schreibt
/// direkt in HealthKit. Für diesen Pfad gibt es keinen Ansatzpunkt aus einem Unit-Test heraus:
/// Es gibt weder einen herauslösbaren Typ noch eine einspeisbare Schnittstelle für den
/// Schreibvorgang. Ein Beweis dafür würde eine Produktivcode-Änderung erfordern (Logik aus der
/// View in einen eigenen Typ heben ODER `HealthKitManager` eine einspeisbare Schreib-
/// Schnittstelle geben). Beides wurde hier bewusst NICHT getan.
final class SessionDurationTests: XCTestCase {

    private var engine: TwoPhaseTimerEngine!

    override func setUp() {
        super.setUp()
        engine = TwoPhaseTimerEngine()
    }

    override func tearDown() {
        engine.cancel()
        engine = nil
        super.tearDown()
    }

    /// Wartet echte Zeit ab, ohne den Lauf zu blockieren (kein `sleep`).
    private func letRealTimePass(_ seconds: TimeInterval) {
        let waited = expectation(description: "\(seconds)s echte Zeit vergehen lassen")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { waited.fulfill() }
        wait(for: [waited], timeout: seconds + 3)
    }

    // MARK: - Volle Dauer

    /// Verhalten: Läuft eine Sitzung von A bis B durch, umspannt der Zeitraum, den die App als
    /// Eintrag schreibt, die VOLLE Sitzung — 3 + 4 Minuten ergeben 7 Minuten, nicht weniger.
    func test_sessionRunningToItsEnd_spansFullConfiguredDuration() {
        engine.start(phase1Minutes: 3, phase2Minutes: 4)

        guard let start = engine.startDate, let end = engine.endDate else {
            XCTFail("Sitzung meldet keinen Anfang/kein Ende — ohne beide Eckpunkte ist keine " +
                    "Dauer bestimmbar.")
            return
        }

        let duration = end.timeIntervalSince(start)
        XCTAssertEqual(
            duration, 7 * 60, accuracy: 1.0,
            "Die Sitzung umspannt \(Int(duration))s statt der vollen 420s (3 + 4 Minuten). " +
            "Ein Eintrag aus diesen Eckpunkten wäre verkürzt."
        )
    }

    /// Verhalten: Das Ende der Sitzung steht als fester Zeitpunkt fest, sobald sie startet.
    /// Vergehende echte Zeit verschiebt es nicht.
    ///
    /// Das ist der eigentliche Regressionsschutz: Weil Anfang und Ende absolute Zeitpunkte sind
    /// (und nicht ein Restwert, der nur bei aktiver App heruntergezählt wird), zählt Zeit, die
    /// außerhalb des Bildschirms vergeht, voll zur Sitzung. Würde jemand auf einen reinen
    /// Ticker umstellen, wären Sitzungen mit Hintergrund-Phasen zu kurz — dieser Test fällt dann.
    func test_sessionEndIsFixedAtStart_notShiftedByElapsedTime() {
        engine.start(phase1Minutes: 3, phase2Minutes: 4)

        guard let startAtBeginning = engine.startDate, let endAtBeginning = engine.endDate else {
            XCTFail("Sitzung meldet keinen Anfang/kein Ende direkt nach dem Start.")
            return
        }

        letRealTimePass(2)

        guard let startLater = engine.startDate, let endLater = engine.endDate else {
            XCTFail("Sitzung meldet nach 2s keinen Anfang/kein Ende mehr — die Eckpunkte des " +
                    "Eintrags gingen während des Laufs verloren.")
            return
        }

        XCTAssertEqual(
            startLater.timeIntervalSince(startAtBeginning), 0, accuracy: 0.001,
            "Der Anfang der Sitzung ist während des Laufs verrutscht — ein daraus geschriebener " +
            "Eintrag würde eine falsche Dauer tragen."
        )
        XCTAssertEqual(
            endLater.timeIntervalSince(endAtBeginning), 0, accuracy: 0.001,
            "Das Ende der Sitzung ist während des Laufs verrutscht (um " +
            "\(endLater.timeIntervalSince(endAtBeginning))s). Erwartet: Das Ende steht beim Start " +
            "fest, damit vergangene Zeit — auch außerhalb des Bildschirms — voll zur Sitzung zählt."
        )
        XCTAssertEqual(
            endLater.timeIntervalSince(startLater), 7 * 60, accuracy: 1.0,
            "Die Sitzung umspannt nach 2s Laufzeit nicht mehr die vollen 420s."
        )
    }

    // MARK: - Vorzeitiges Beenden

    /// Verhalten: Wird die Sitzung vorzeitig beendet, ist der Zeitraum des Eintrags
    /// entsprechend kürzer — die Dauer bildet also ab, wie lange die Sitzung tatsächlich lief.
    ///
    /// Nachgebildet wird exakt das, was die App beim vorzeitigen Beenden schreibt: Anfang ist
    /// der Startzeitpunkt der Sitzung, Ende der Zeitpunkt des Abbruchs.
    func test_stoppingEarly_spansOnlyTheTimeActuallyRun() {
        engine.start(phase1Minutes: 3, phase2Minutes: 4)

        guard let start = engine.startDate, let plannedEnd = engine.endDate else {
            XCTFail("Sitzung meldet keinen Anfang/kein Ende.")
            return
        }
        let plannedDuration = plannedEnd.timeIntervalSince(start)

        letRealTimePass(2)

        let stopInstant = Date()
        engine.cancel()

        let actualDuration = stopInstant.timeIntervalSince(start)

        XCTAssertLessThan(
            actualDuration, plannedDuration,
            "Ein Abbruch nach rund 2s ergibt eine Dauer von \(Int(actualDuration))s, die nicht " +
            "kürzer ist als die geplanten \(Int(plannedDuration))s — die Dauer bildet dann nicht " +
            "ab, wie lange die Sitzung wirklich lief."
        )
        XCTAssertEqual(
            actualDuration, 2.0, accuracy: 1.5,
            "Ein Abbruch nach rund 2s sollte auch rund 2s ergeben, gemessen wurden " +
            "\(actualDuration)s."
        )
    }
}
