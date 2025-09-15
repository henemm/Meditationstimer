import Foundation
import HealthKit
import UIKit

/// Kapselt HealthKit für das Schreiben von Achtsamkeits‑Sitzungen (Mindful Minutes).
final class HealthKitManager {

    enum HealthKitError: Error {
        case healthDataUnavailable
        case mindfulTypeUnavailable
        case authorizationDenied
        case saveFailed
    }

    private let healthStore = HKHealthStore()

    /// Hinweis zu Info.plist:
    /// - NSHealthShareUsageDescription  → Begründung für das LESEN von Health‑Daten (z. B. Herzfrequenz)
    /// - NSHealthUpdateUsageDescription → Begründung für das SCHREIBEN von Health‑Daten (z. B. Achtsamkeit)
    ///
    /// Fragt die Berechtigung an (schreiben: mindfulSession, lesen: heartRate).
    /// Robust: nur wenn App aktiv, und nur wenn noch nötig.
    @MainActor
    @discardableResult
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataUnavailable
        }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            throw HealthKitError.mindfulTypeUnavailable
        }
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)

        let toShare: Set<HKSampleType> = [mindfulType]
        let toRead: Set<HKObjectType> = heartRateType.map { Set([$0]) } ?? []

        // Prüfen, ob eine Anfrage überhaupt nötig ist
        let status: HKAuthorizationRequestStatus = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<HKAuthorizationRequestStatus, Error>) in
            self.healthStore.getRequestStatusForAuthorization(toShare: toShare, read: toRead) { status, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: status)
                }
            }
        }
        if status == .unnecessary { return } // bereits autorisiert

        // Warten, bis die App im Vordergrund ist (sonst kann das Sheet timeouten)
        guard await waitUntilAppActive(timeout: 5.0) else {
            throw HealthKitError.authorizationDenied
        }

        // Anfrage stellen (auf dem MainActor)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.healthStore.requestAuthorization(toShare: toShare, read: toRead) { success, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else if success {
                    cont.resume()
                } else {
                    cont.resume(throwing: HealthKitError.authorizationDenied)
                }
            }
        }
    }

    /// Schreibt EINE Mindfulness‑Session von `start` bis `end` in Apple Health.
    func logMindfulness(start: Date, end: Date) async throws {
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            throw HealthKitError.mindfulTypeUnavailable
        }

        // Für mindfulSession ist der Category‑Wert "notApplicable" korrekt.
        let value = HKCategoryValue.notApplicable.rawValue
        let sample = HKCategorySample(type: mindfulType, value: value, start: start, end: end)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.healthStore.save(sample) { success, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else if success {
                    cont.resume()
                } else {
                    cont.resume(throwing: HealthKitError.saveFailed)
                }
            }
        }
    }
    /// Wartet kurz, bis die App „active“ ist (verhindert Timeout beim System‑Sheet).
    private func waitUntilAppActive(timeout: TimeInterval) async -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if UIApplication.shared.applicationState == .active { return true }
            try? await Task.sleep(nanoseconds: 150_000_000) // 150 ms
        }
        return UIApplication.shared.applicationState == .active
    }
}
