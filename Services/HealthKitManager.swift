import Foundation
import HealthKit

/// Kapselt HealthKit für das Schreiben von Achtsamkeits-Sitzungen (Mindful Minutes).
final class HealthKitManager {

    enum HealthKitError: Error {
        case healthDataUnavailable
        case mindfulTypeUnavailable
        case authorizationDenied
        case saveFailed
    }

    private let healthStore = HKHealthStore()

    /// Fragt die Berechtigung an, Mindfulness-Sitzungen zu SCHREIBEN.
    /// Aufruf einmalig beim ersten Start sinnvoll.
    @discardableResult
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataUnavailable
        }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            throw HealthKitError.mindfulTypeUnavailable
        }

        // HealthKit hat (stand heute) keine native async-API auf allen watchOS-Versionen → wir bridgen auf async.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [mindfulType], read: []) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.authorizationDenied)
                }
            }
        }
    }

    /// Schreibt EINE Mindfulness-Session von `start` bis `end` in Apple Health.
    func logMindfulness(start: Date, end: Date) async throws {
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            throw HealthKitError.mindfulTypeUnavailable
        }

        // Für mindfulSession ist der Category-Wert "notApplicable" korrekt.
        let value = HKCategoryValue.notApplicable.rawValue
        let sample = HKCategorySample(type: mindfulType, value: value, start: start, end: end)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(sample) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.saveFailed)
                }
            }
        }
    }
}
