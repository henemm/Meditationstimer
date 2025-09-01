import Foundation
import WatchKit

/// Hilfsklasse für WKExtendedRuntimeSession, damit die App bis ~30 Minuten aktiv bleibt.
/// Nutze sie beim Start der Sitzung und beende sie beim Abschluss/Abbruch.
final class RuntimeSessionHelper: NSObject, WKExtendedRuntimeSessionDelegate {

    private var session: WKExtendedRuntimeSession?
    private var onDidExpire: (() -> Void)?
    private var onInvalidation: ((WKExtendedRuntimeSessionInvalidationReason?) -> Void)?

    /// Startet (falls möglich) eine Extended Runtime Session.
    /// - Parameters:
    ///   - onDidExpire: Wird aufgerufen, wenn die Energiezeit abläuft (z. B. nach ~30 Min.).
    ///   - onInvalidation: Wird aufgerufen, wenn das System die Session beendet.
    func start(
        onDidExpire: @escaping () -> Void,
        onInvalidation: @escaping (WKExtendedRuntimeSessionInvalidationReason?) -> Void
    ) {
        // Bereits laufende Session sauber beenden
        stop()

        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        self.session = newSession
        self.onDidExpire = onDidExpire
        self.onInvalidation = onInvalidation

        if newSession.state == .notStarted {
            newSession.start()
        }
    }

    /// Beendet die Session, wenn aktiv.
    func stop() {
        guard let s = session else { return }
        if s.state == .running {
            s.invalidate()
        }
        session = nil
        onDidExpire = nil
        onInvalidation = nil
    }

    // MARK: - WKExtendedRuntimeSessionDelegate

    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        // Optionales Debug-Log
        // print("Extended runtime session started")
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        onDidExpire?()
    }

    func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        onInvalidation?(reason)
        stop()
    }
}
