//
//  FocusManager.swift
//  Meditationstimer
//
//  Created by AI on 23.10.2025.
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Manager für die Aktivierung/Deaktivierung von iOS Focus Modi während Sessions.
class FocusManager {
    static let shared = FocusManager()
    
    private var previousFocusMode: String?
    
    /// Aktiviert den angegebenen Focus Modus.
    /// - Parameter mode: Der Name des Focus Modus (z.B. "Do Not Disturb").
    func activateFocusMode(_ mode: String) {
        #if os(iOS) && canImport(ActivityKit)
        if #available(iOS 16.0, *) {
            do {
                // Versuche, den Modus zu aktivieren
                try ActivityManager.shared.requestFocusMode(mode: mode)
                previousFocusMode = getCurrentFocusMode()
            } catch {
                print("Fehler beim Aktivieren des Focus Modus: \(error)")
                // Fallback: Do Not Disturb
                activateDoNotDisturb()
            }
        } else {
            // Fallback für ältere iOS-Versionen
            activateDoNotDisturb()
        }
        #endif
    }
    
    /// Deaktiviert den aktuellen Focus Modus und kehrt zum vorherigen zurück.
    func deactivateFocusMode() {
        #if os(iOS) && canImport(ActivityKit)
        if #available(iOS 16.0, *) {
            // Kehre zum vorherigen Modus zurück oder deaktiviere
            if let previous = previousFocusMode {
                try? ActivityManager.shared.requestFocusMode(mode: previous)
            } else {
                // Deaktiviere alle Focus Modi
                try? ActivityManager.shared.requestFocusMode(mode: nil)
            }
        } else {
            deactivateDoNotDisturb()
        }
        #endif
        previousFocusMode = nil
    }
    
    private func getCurrentFocusMode() -> String? {
        // Placeholder: Aktueller Modus abrufen (falls verfügbar)
        return nil
    }
    
    private func activateDoNotDisturb() {
        // Fallback: Aktiviere Do Not Disturb via UIApplication (ältere API)
        // Hinweis: Dies ist eine Vereinfachung; echte Implementierung erfordert Berechtigungen
        print("Fallback: Aktiviere Do Not Disturb")
    }
    
    private func deactivateDoNotDisturb() {
        print("Fallback: Deaktiviere Do Not Disturb")
    }
}