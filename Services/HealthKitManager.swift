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
#if canImport(UIKit)
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

    enum ActivityType {
        case mindfulness
        case workout
        case both
    }

    private let healthStore = HKHealthStore()

    /// Hinweis zu Info.plist:
    /// - NSHealthShareUsageDescription  → Begründung für das LESEN von Health‑Daten (z. B. Herzfrequenz)
    /// - NSHealthUpdateUsageDescription → Begründung für das SCHREIBEN von Health‑Daten (z. B. Achtsamkeit)
    ///
    /// Fragt die Berechtigung an (schreiben: mindfulSession & Workout, lesen: heartRate, mindfulSession, Workout).
    /// Robust: nur wenn App aktiv, und nur wenn noch nötig.
    @MainActor
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
        var toRead = Set<HKObjectType>()
        toRead.insert(mindfulType)
        toRead.insert(workoutType)
        if let heartRateType = heartRateType {
            toRead.insert(heartRateType)
        }

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
        #if os(iOS)
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
        #else
        throw HealthKitError.healthDataUnavailable
        #endif
    }
    
    /// Legacy wrapper method for compatibility
    func saveMindfulnessSession(start: Date, end: Date) {
        Task {
            try? await logMindfulness(start: start, end: end)
        }
    }
    
    /// Wartet kurz, bis die App „active" ist (verhindert Timeout beim System‑Sheet).
    private func waitUntilAppActive(timeout: TimeInterval) async -> Bool {
        #if canImport(UIKit)
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if UIApplication.shared.applicationState == .active { return true }
            try? await Task.sleep(nanoseconds: 150_000_000) // 150 ms
        }
        return UIApplication.shared.applicationState == .active
        #else
        // Ohne UIApplication (z. B. auf watchOS oder macOS) nicht blockieren
        return true
        #endif
    }
    
    /// Prüft, ob HealthKit bereits autorisiert ist (für schreiben: mindfulSession & Workout).
    func isAuthorized() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return false }
        let workoutType = HKObjectType.workoutType()
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)

        let toShare: Set<HKSampleType> = [mindfulType, workoutType]
        var toRead = Set<HKObjectType>()
        toRead.insert(mindfulType)
        toRead.insert(workoutType)
        if let heartRateType = heartRateType {
            toRead.insert(heartRateType)
        }

        do {
            let status: HKAuthorizationRequestStatus = try await withCheckedThrowingContinuation { cont in
                self.healthStore.getRequestStatusForAuthorization(toShare: toShare, read: toRead) { status, error in
                    if let error = error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume(returning: status)
                    }
                }
            }
            return status == .unnecessary
        } catch {
            return false
        }
    }

    /// Holt die Tage eines Monats mit verschiedenen Aktivitätstypen.
    func fetchActivityDaysDetailed(forMonth date: Date) async throws -> [Date: ActivityType] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataUnavailable
        }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            throw HealthKitError.mindfulTypeUnavailable
        }
        let workoutType = HKObjectType.workoutType()

        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfMonth, end: endOfMonth, options: .strictStartDate)

        var activityDays = [Date: ActivityType]()

        // Mindfulness-Sessions abfragen
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let query = HKSampleQuery(sampleType: mindfulType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                if let samples = samples {
                    for sample in samples {
                        // let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60.0 // in Minuten
                        // if duration >= 2.0 { // Nur zählen wenn >= 2 Minuten (konsistent mit Streak)
                            let day = calendar.startOfDay(for: sample.startDate)
                            activityDays[day] = .mindfulness
                        // }
                    }
                }
                cont.resume()
            }
            self.healthStore.execute(query)
        }

        // Workouts abfragen
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                if let workouts = samples as? [HKWorkout] {
                    for workout in workouts {
                        // let duration = workout.duration / 60.0 // in Minuten
                        // if duration >= 2.0 { // Nur zählen wenn >= 2 Minuten (konsistent mit Streak)
                            let day = calendar.startOfDay(for: workout.startDate)
                            // Wenn bereits Mindfulness an diesem Tag, dann beide
                            if activityDays[day] == .mindfulness {
                                activityDays[day] = .both
                            } else {
                                activityDays[day] = .workout
                            }
                        // }
                    }
                }
                cont.resume()
            }
            self.healthStore.execute(query)
        }

        return activityDays
    }

    /// Holt tägliche Minuten für Mindfulness und Workouts in einem Monat.
    func fetchDailyMinutes(forMonth date: Date) async throws -> [Date: (mindfulnessMinutes: Double, workoutMinutes: Double)] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataUnavailable
        }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            throw HealthKitError.mindfulTypeUnavailable
        }
        let workoutType = HKObjectType.workoutType()

        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfMonth, end: endOfMonth, options: .strictStartDate)

        var dailyMinutes = [Date: (mindfulnessMinutes: Double, workoutMinutes: Double)]()

        // Mindfulness-Sessions abfragen und Minuten summieren
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let query = HKSampleQuery(sampleType: mindfulType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                if let samples = samples {
                    for sample in samples {
                        let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60.0 // in Minuten
                        // if duration >= 2.0 { // Nur zählen wenn >= 2 Minuten (konsistent mit Streak)
                            let day = calendar.startOfDay(for: sample.startDate)
                            var current = dailyMinutes[day] ?? (0, 0)
                            current.mindfulnessMinutes += duration
                            dailyMinutes[day] = current
                        // }
                    }
                }
                cont.resume()
            }
            self.healthStore.execute(query)
        }

        // Workouts abfragen und Minuten summieren
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                if let workouts = samples as? [HKWorkout] {
                    for workout in workouts {
                        let duration = workout.duration / 60.0 // in Minuten
                        // if duration >= 2.0 { // Nur zählen wenn >= 2 Minuten (konsistent mit Streak)
                            let day = calendar.startOfDay(for: workout.startDate)
                            var current = dailyMinutes[day] ?? (0, 0)
                            current.workoutMinutes += duration
                            dailyMinutes[day] = current
                        // }
                    }
                }
                cont.resume()
            }
            self.healthStore.execute(query)
        }

        return dailyMinutes
    }
    
    /// Holt tägliche Minuten für Mindfulness und Workouts in einem Zeitraum.
    func fetchDailyMinutes(from startDate: Date, to endDate: Date) async throws -> [Date: (mindfulnessMinutes: Double, workoutMinutes: Double)] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataUnavailable
        }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            throw HealthKitError.mindfulTypeUnavailable
        }
        let workoutType = HKObjectType.workoutType()

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        var dailyMinutes = [Date: (mindfulnessMinutes: Double, workoutMinutes: Double)]()

        // Mindfulness-Sessions abfragen und Minuten summieren
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let query = HKSampleQuery(sampleType: mindfulType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                if let samples = samples {
                    for sample in samples {
                        let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60.0 // in Minuten
                        // if duration >= 2.0 { // Nur zählen wenn >= 2 Minuten (konsistent mit Streak)
                            let day = Calendar.current.startOfDay(for: sample.startDate)
                            var current = dailyMinutes[day] ?? (0, 0)
                            current.mindfulnessMinutes += duration
                            dailyMinutes[day] = current
                        // }
                    }
                }
                cont.resume()
            }
            self.healthStore.execute(query)
        }

        // Workouts abfragen und Minuten summieren
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                if let workouts = samples as? [HKWorkout] {
                    for workout in workouts {
                        let duration = workout.duration / 60.0 // in Minuten
                        // if duration >= 2.0 { // Nur zählen wenn >= 2 Minuten (konsistent mit Streak)
                            let day = Calendar.current.startOfDay(for: workout.startDate)
                            var current = dailyMinutes[day] ?? (0, 0)
                            current.workoutMinutes += duration
                            dailyMinutes[day] = current
                        // }
                    }
                }
                cont.resume()
            }
            self.healthStore.execute(query)
        }

        return dailyMinutes
    }

    /// Legacy-Methode für Abwärtskompatibilität
    func fetchActivityDays(forMonth date: Date) async throws -> Set<Date> {
        let detailed = try await fetchActivityDaysDetailed(forMonth: date)
        return Set(detailed.keys)
    }
}
