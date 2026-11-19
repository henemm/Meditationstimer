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
