import XCTest

extension XCUIApplication {
    /// Frischer Simulator: HealthKit zeigt das Zugriffsblatt ("Health-Zugriff") im App-Prozess oder in
    /// einem Health-Dienst-Prozess. Tab-Tipps gehen sonst ins Leere. Fuer die UI-Tests reicht Ablehnen;
    /// Tracker-Eintraege liegen in SwiftData. Mehrfach pruefen, weil je HealthKit-Typ ein eigenes Blatt kommen kann.
    /// Aufruf direkt nach `launch()`.
    func dismissHealthSheetIfAny() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let denyPredicate = NSPredicate(
            format: "identifier == 'UIA.Health.DoNotAllow.Button' OR label == 'Nicht erlauben' OR label == 'Don’t Allow' OR label == \"Don't Allow\""
        )
        let hosts: [XCUIApplication] = [
            self,
            XCUIApplication(bundleIdentifier: "com.apple.HealthPrivacyService"),
            XCUIApplication(bundleIdentifier: "com.apple.Health"),
            springboard,
        ]
        // Ablauf je Blatt: "Nicht erlauben", danach Bestaetigungsdialog "OK". Beide liegen im
        // Health-Dienst-Prozess; dort erst "OK" (liegt oben), dann "Nicht erlauben".
        // Normales tap() scheitert ("Element nicht mehr gueltig"), daher per Bildschirmkoordinate.
        func tapByCoordinate(_ element: XCUIElement) {
            let frame = element.frame
            coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
        }
        for _ in 0..<8 {
            var handled = false
            for host in hosts {
                let ok = host.buttons["OK"]
                if ok.waitForExistence(timeout: host === self ? 2 : 1) {
                    tapByCoordinate(ok)
                    handled = true
                    break
                }
            }
            if handled { continue }
            for host in hosts {
                let deny = host.buttons.matching(denyPredicate).firstMatch
                if deny.waitForExistence(timeout: host === self ? 3 : 1) {
                    tapByCoordinate(deny)
                    handled = true
                    break
                }
            }
            if handled { continue }
            // Langes Blatt (10 Themen): "Nicht erlauben" liegt unterhalb des sichtbaren Bereichs und
            // ist erst nach dem Scrollen als Knopf im Baum. Blatt erkennt man an der Titelleiste.
            let sheetBar = navigationBars["Health-Zugriff"]
            if sheetBar.exists, tables.firstMatch.exists {
                tables.firstMatch.swipeUp()
                continue
            }
            break
        }
    }
}

// MARK: - #122 Programmstart: Health-Rueckfragen

extension XCUIApplication {
    /// Alert "Health Access" (nie gefragt) vor dem Programmstart. Englische und deutsche Titel.
    var healthAccessAlert: XCUIElement {
        alerts.matching(NSPredicate(format: "label == 'Health Access' OR label == 'Health-Zugang'")).firstMatch
    }

    /// Rueckfrage "Training wird nicht gespeichert" (Schreiben verweigert).
    var workoutNotSavedAlert: XCUIElement {
        alerts.matching(NSPredicate(
            format: "label BEGINSWITH 'Workout won' OR label == 'Training wird nicht gespeichert'"
        )).firstMatch
    }

    /// Alert "Nicht in Health gespeichert" (Schreibfehler nach dem Ende).
    var workoutWriteFailedAlert: XCUIElement {
        alerts.matching(NSPredicate(format: "label == 'Not Saved to Health' OR label == 'Nicht in Health gespeichert'")).firstMatch
    }

    /// Alle Wirt-Prozesse, in denen das System-Blatt "Health-Zugriff" liegen kann.
    private var healthSheetHosts: [XCUIApplication] {
        [
            self,
            XCUIApplication(bundleIdentifier: "com.apple.HealthPrivacyService"),
            XCUIApplication(bundleIdentifier: "com.apple.Health"),
            XCUIApplication(bundleIdentifier: "com.apple.springboard"),
        ]
    }

    private func tapByCoordinate(_ element: XCUIElement) {
        let frame = element.frame
        coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
    }

    /// Erlaubt im System-Blatt alle Themen: "Turn On All" / "Alle aktivieren", danach "Allow" / "Erlauben".
    /// Gibt false zurueck, wenn das Blatt nicht erscheint.
    @discardableResult
    func allowHealthSheetCompletely(timeout: TimeInterval = 15) -> Bool {
        let turnOnAllPredicate = NSPredicate(format: "label == 'Turn On All' OR label == 'Alle aktivieren'")
        var turnedOn = false
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, !turnedOn {
            for host in healthSheetHosts {
                let all = host.descendants(matching: .any).matching(turnOnAllPredicate).firstMatch
                if all.waitForExistence(timeout: 1) {
                    tapByCoordinate(all)
                    turnedOn = true
                    break
                }
            }
        }
        guard turnedOn else { return false }
        let allowPredicate = NSPredicate(format: "label == 'Allow' OR label == 'Erlauben'")
        for host in healthSheetHosts {
            let allow = host.buttons.matching(allowPredicate).firstMatch
            if allow.waitForExistence(timeout: 3) {
                tapByCoordinate(allow)
                return true
            }
        }
        return false
    }

    /// Fuer Bestandstests, die ein Programm starten und die Freigabe nicht pruefen (AC-9):
    /// Bedient nach dem Tipp auf "Start" optional den Alert "Health Access" ("Allow"; danach Blatt ablehnen,
    /// das Programm startet trotzdem) oder die Rueckfrage "Training wird nicht gespeichert" ("Start Anyway").
    /// Ohne Alert kehrt die Funktion nach kurzer Wartezeit zurueck.
    func handleProgramStartHealthPrompts() {
        let allow = alerts.buttons.matching(NSPredicate(format: "label == 'Allow' OR label == 'Erlauben'")).firstMatch
        let startAnyway = alerts.buttons.matching(NSPredicate(format: "label == 'Start Anyway' OR label == 'Trotzdem starten'")).firstMatch
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if startAnyway.exists {
                startAnyway.tap()
                return
            }
            if allow.exists {
                allow.tap()
                dismissHealthSheetIfAny()
                return
            }
            _ = allow.waitForExistence(timeout: 0.3)
        }
    }
}
