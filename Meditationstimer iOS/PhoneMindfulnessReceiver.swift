//
//  PhoneMindfulnessReceiver.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 01.09.25.
//


//
//  PhoneMindfulnessReceiver.swift
//  Meditationstimer iOS
//
//  Created by Henning Emmrich on 01.09.25.
//

import Foundation
import WatchConnectivity
import HealthKit

/// Läuft in der iPhone‑App und speichert Mindfulness‑Sessions,
/// die von der Watch (Start/Ende) gemeldet werden.
/// – Hält WCSession aktiv
/// – Holt HealthKit‑Berechtigung
/// – Speichert ausschließlich .mindfulSession (nur Phase 1; Phase-Logik macht die Watch)
final class PhoneMindfulnessReceiver: NSObject, WCSessionDelegate {

    private let store = HKHealthStore()

    // MARK: - Lifecycle

    override init() {
        super.init()
        activateWCSession()
        requestHealthAuthorization()
    }

    // MARK: - HealthKit

    private func requestHealthAuthorization() {
        guard HKHealthStore.isHealthDataAvailable(),
              let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession)
        else { return }

        store.requestAuthorization(toShare: [mindful], read: []) { _, _ in
            // keine UI notwendig; stiller Abschluss
        }
    }

    private func saveMindful(start: Date, end: Date) {
        guard let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession),
              end > start
        else { return }

        let sample = HKCategorySample(type: mindful,
                                      value: HKCategoryValue.notApplicable.rawValue,
                                      start: start,
                                      end: end)

        store.save(sample) { _, _ in
            // optional: Logging / Debug
            // print("Saved mindful session \(start) - \(end)")
        }
    }

    // MARK: - WatchConnectivity

    private func activateWCSession() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
    }

    // Empfängt Live‑Nachrichten (Watch im Vordergrund & erreichbar)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let s = message["start"] as? Double,
              let e = message["end"]   as? Double
        else { return }
        saveMindful(start: Date(timeIntervalSince1970: s),
                    end:   Date(timeIntervalSince1970: e))
    }

    // Fallback: kommt an, wenn die Watch nicht direkt erreichbar war
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        guard let s = userInfo["start"] as? Double,
              let e = userInfo["end"]   as? Double
        else { return }
        saveMindful(start: Date(timeIntervalSince1970: s),
                    end:   Date(timeIntervalSince1970: e))
    }

    // Pflicht-Stubs

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        // optional: print("WC activation: \(activationState) \(String(describing: error))")
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Nach Deaktivierung erneut aktivieren (z. B. nach Gerätewechsel)
        WCSession.default.activate()
    }
}
