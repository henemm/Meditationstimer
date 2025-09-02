import Foundation
import HealthKit

/// Kapselt HealthKit für das Schreiben von Achtsamkeits‑Sitzungen (Mindful Minutes).
final class HealthKitManager {

    enum HealthKitError: Error {
        case healthDataUnavailable
        case mindfulTypeUnavailable
        case authorizationDenied
        case saveFailed
    }

    private let healthStore = HKHealthStore()

    /// Fragt die Berechtigung an, Mindfulness‑Sitzungen zu SCHREIBEN.
    /// Zusätzlich wird Lesezugriff für Herzfrequenz angefragt (optional).
    @discardableResult
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataUnavailable
        }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            throw HealthKitError.mindfulTypeUnavailable
        }
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.healthStore.requestAuthorization(toShare: [mindfulType],
                                                  read: heartRateType != nil ? [heartRateType!] : []) { success, error in
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
}
