// MARK: - AI ORIENTATION (Read me first)
// Purpose:
//   HealthKitManager is the centralized service for logging meditation and workout sessions
//   to Apple Health as "Mindfulness" entries. Handles permissions, authorization, and robust
//   error handling across the entire app.
//
// Integration Points:
//   • OffenView: Logs Phase 1 duration (meditation portion only)
//   • AtemView: Logs breathing exercise sessions (full duration)
//   • WorkoutsView: Logs HIIT workout sessions as mindfulness (full duration)
//   • Watch App: Receives logged sessions via WatchConnectivity
//
// Permission Strategy:
//   • Requests authorization only when app is active (prevents timeout)
//   • Uses HKAuthorizationRequestStatus to avoid unnecessary prompts
//   • Graceful degradation: continues without HealthKit if denied
//   • No UI blocking: async/await with proper error propagation
//
// Data Model:
//   • HKCategoryType.mindfulSession with HKCategoryValue.notApplicable
//   • Precise start/end timestamps from actual session duration
//   • No artificial padding or manipulation of logged times
//
// Error Handling:
//   • Custom HealthKitError enum for specific failure modes
//   • All methods use modern Swift Concurrency (async/await)
//   • Legacy wrapper methods for compatibility with existing code
//   • Logging failures don't crash app or interrupt user experience
//
// Technical Notes:
//   • Singleton pattern via HealthKitManager.shared for consistent state
//   • Info.plist requires NSHealthUpdateUsageDescription for write access
//   • Waits for app active state before presenting authorization sheet

import Foundation
import HealthKit
#if !os(watchOS)
import UIKit
#endif

/// Kapselt HealthKit für das Schreiben von Achtsamkeits‑Sitzungen (Mindful Minutes).
final class HealthKitManager {
    static let shared = HealthKitManager()

    enum HealthKitError: Error {
        case healthDataUnavailable
        case mindfulTypeUnavailable
        case authorizationDenied
        case saveFailed
    }

    private let healthStore = HKHealthStore()

    /// Hinweis zu Info.plist:
    /// - NSHealthShareUsageDescription  → Begründung für das LESEN von Health‑Daten (z. B. Herzfrequenz)
    /// - NSHealthUpdateUsageDescription → Begründung für das SCHREIBEN von Health‑Daten (z. B. Achtsamkeit)
    ///
    /// Fragt die Berechtigung an (schreiben: mindfulSession & Workout, lesen: heartRate).
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
        let workoutType = HKObjectType.workoutType()
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)

    let toShare: Set<HKSampleType> = [mindfulType, workoutType]
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
    
    /// Schreibt EIN Workout von `start` bis `end` in Apple Health (Trainings‑App).
    /// Standardaktivität: HIIT (High Intensity Interval Training).
    func logWorkout(start: Date, end: Date, activity: HKWorkoutActivityType = .highIntensityIntervalTraining) async throws {
        let workout = HKWorkout(activityType: activity, start: start, end: end)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.healthStore.save(workout) { success, error in
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
    
    /// Legacy wrapper method for compatibility
    func saveMindfulnessSession(start: Date, end: Date) {
        Task {
            try? await logMindfulness(start: start, end: end)
        }
    }
    
    /// Wartet kurz, bis die App „active" ist (verhindert Timeout beim System‑Sheet).
    private func waitUntilAppActive(timeout: TimeInterval) async -> Bool {
        #if os(watchOS)
        // Auf watchOS gibt es kein UIApplication, daher immer true zurückgeben
        return true
        #else
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if UIApplication.shared.applicationState == .active { return true }
            try? await Task.sleep(nanoseconds: 150_000_000) // 150 ms
        }
        return UIApplication.shared.applicationState == .active
        #endif
    }
}
