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

    /// Gets the HKSource for this app to filter queries to app-specific data.
    private var appSource: HKSource? {
        return HKSource.default()
    }

    /// Hinweis zu Info.plist:
    /// - NSHealthShareUsageDescription  → Begründung für das LESEN von Health‑Daten (z. B. Herzfrequenz)
    /// - NSHealthUpdateUsageDescription → Begründung für das SCHREIBEN von Health‑Daten (z. B. Achtsamkeit)
    ///
    /// Fragt die Berechtigung an (schreiben: mindfulSession, Workout, alcohol; lesen: heartRate, mindfulSession, Workout, alcohol).
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
        let alcoholType = HKObjectType.quantityType(forIdentifier: .numberOfAlcoholicBeverages)
        let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)

        var toShare = Set<HKSampleType>()
        toShare.insert(mindfulType)
        toShare.insert(workoutType)
        if let alcoholType = alcoholType {
            toShare.insert(alcoholType)
        }
        if let energyType = energyType {
            toShare.insert(energyType)  // Required for logging workout calories
        }

        var toRead = Set<HKObjectType>()
        toRead.insert(mindfulType)
        toRead.insert(workoutType)
        if let heartRateType = heartRateType {
            toRead.insert(heartRateType)
        }
        if let alcoholType = alcoholType {
            toRead.insert(alcoholType)
        }
        if let energyType = energyType {
            toRead.insert(energyType)  // Optional: for reading calorie data later
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
    /// Verwendet HKWorkoutBuilder (moderne API seit iOS 17.0).
    /// WICHTIG: Fügt activeEnergyBurned hinzu für MOVE Ring und Fitness App Integration.
    func logWorkout(start: Date, end: Date, activity: HKWorkoutActivityType = .highIntensityIntervalTraining) async throws {
        #if os(iOS)
        // Calculate workout duration in minutes
        let durationMinutes = end.timeIntervalSince(start) / 60.0

        // Estimate calories based on activity type (MET-based approximation)
        // HIIT: ~12 kcal/min, Yoga: ~4 kcal/min (conservative estimates)
        let caloriesPerMinute: Double
        switch activity {
        case .highIntensityIntervalTraining:
            caloriesPerMinute = 12.0
        case .yoga:
            caloriesPerMinute = 4.0
        default:
            caloriesPerMinute = 8.0  // Generic moderate activity
        }

        let estimatedCalories = durationMinutes * caloriesPerMinute

        // Create workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activity

        // Create workout builder with local device
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())

        // Begin collection at start time (retrospective workout)
        try await builder.beginCollection(at: start)

        // End collection at end time
        try await builder.endCollection(at: end)

        // Add metadata before finishing
        let metadata: [String: Any] = ["appSource": "Meditationstimer"]
        try await builder.addMetadata(metadata)

        // CRITICAL: Add activeEnergyBurned sample for MOVE ring / Fitness app integration
        // This is required for calories to show up in iOS Fitness app and affect MOVE ring
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthKitError.saveFailed
        }

        let energyQuantity = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: estimatedCalories)
        let energySample = HKQuantitySample(
            type: energyType,
            quantity: energyQuantity,
            start: start,
            end: end,
            device: .local(),
            metadata: ["appSource": "Meditationstimer"]
        )

        // Add the energy sample to the workout
        try await builder.addSamples([energySample])

        // Finalize workout (saves to HealthKit automatically)
        _ = try await builder.finishWorkout()
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
    @MainActor
    private func waitUntilAppActive(timeout: TimeInterval) async -> Bool {
        #if os(iOS)
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
    
    /// Prüft, ob HealthKit bereits autorisiert ist (für schreiben: mindfulSession, Workout, Energy, Alcohol).
    func isAuthorized() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return false }
        let workoutType = HKObjectType.workoutType()
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)
        let alcoholType = HKObjectType.quantityType(forIdentifier: .numberOfAlcoholicBeverages)
        let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)

        var toShare = Set<HKSampleType>()
        toShare.insert(mindfulType)
        toShare.insert(workoutType)
        if let alcoholType = alcoholType {
            toShare.insert(alcoholType)
        }
        if let energyType = energyType {
            toShare.insert(energyType)
        }

        var toRead = Set<HKObjectType>()
        toRead.insert(mindfulType)
        toRead.insert(workoutType)
        if let heartRateType = heartRateType {
            toRead.insert(heartRateType)
        }
        if let alcoholType = alcoholType {
            toRead.insert(alcoholType)
        }
        if let energyType = energyType {
            toRead.insert(energyType)
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

    /// Holt Aktivitätstage (gefiltert nach App-Quelle) für Mindfulness und Workouts in einem Monat.
    func fetchActivityDaysDetailedFiltered(forMonth date: Date) async throws -> [Date: ActivityType] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataUnavailable
        }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            throw HealthKitError.mindfulTypeUnavailable
        }
        let workoutType = HKObjectType.workoutType()

        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        // Use start of NEXT month as endDate to include ALL samples from current month
        // With .strictStartDate, samples must start BEFORE endDate (exclusive)
        let startOfNextMonth = calendar.date(byAdding: DateComponents(month: 1), to: startOfMonth)!

        let timePredicate = HKQuery.predicateForSamples(withStart: startOfMonth, end: startOfNextMonth, options: .strictStartDate)
        let sourcePredicate = HKQuery.predicateForObjects(from: Set([appSource].compactMap { $0 }))

        var activityDays = [Date: ActivityType]()

        // Mindfulness-Sessions abfragen (app-spezifisch gefiltert)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let mindfulPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [timePredicate, sourcePredicate])
            let query = HKSampleQuery(sampleType: mindfulType, predicate: mindfulPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                if let samples = samples {
                    for sample in samples {
                        let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60.0 // in Minuten
                        if duration >= 2.0 { // Nur zählen wenn >= 2 Minuten (konsistent mit Streak)
                            let day = calendar.startOfDay(for: sample.startDate)
                            activityDays[day] = .mindfulness
                        }
                    }
                }
                cont.resume()
            }
            self.healthStore.execute(query)
        }

        // Workouts abfragen (app-spezifisch gefiltert)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let workoutPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [timePredicate, sourcePredicate])
            let query = HKSampleQuery(sampleType: workoutType, predicate: workoutPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                if let workouts = samples as? [HKWorkout] {
                    for workout in workouts {
                        let duration = workout.duration / 60.0 // in Minuten
                        if duration >= 2.0 { // Nur zählen wenn >= 2 Minuten (konsistent mit Streak)
                            let day = calendar.startOfDay(for: workout.startDate)
                            // Wenn bereits Mindfulness an diesem Tag, dann beide
                            if activityDays[day] == .mindfulness {
                                activityDays[day] = .both
                            } else {
                                activityDays[day] = .workout
                            }
                        }
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
                        if duration >= 2.0 { // Nur zählen wenn >= 2 Minuten (konsistent mit Streak)
                            let day = Calendar.current.startOfDay(for: workout.startDate)
                            var current = dailyMinutes[day] ?? (0, 0)
                            current.workoutMinutes += duration
                            dailyMinutes[day] = current
                        }
                    }
                }
                cont.resume()
            }
            self.healthStore.execute(query)
        }

        return dailyMinutes
    }
    
    /// Holt tägliche Minuten für Mindfulness und Workouts in einem Zeitraum (nur app-spezifische Sessions).
    func fetchDailyMinutesFiltered(from startDate: Date, to endDate: Date) async throws -> [Date: (mindfulnessMinutes: Double, workoutMinutes: Double)] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataUnavailable
        }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            throw HealthKitError.mindfulTypeUnavailable
        }
        let workoutType = HKObjectType.workoutType()

        let timePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sourcePredicate = HKQuery.predicateForObjects(from: Set([appSource].compactMap { $0 }))

        var dailyMinutes = [Date: (mindfulnessMinutes: Double, workoutMinutes: Double)]()

        // Mindfulness-Sessions abfragen und Minuten summieren
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let mindfulPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [timePredicate, sourcePredicate])
            let query = HKSampleQuery(sampleType: mindfulType, predicate: mindfulPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
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

        // Workouts abfragen und Minuten summieren (app-spezifisch gefiltert)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let workoutPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [timePredicate, sourcePredicate])
            let query = HKSampleQuery(sampleType: workoutType, predicate: workoutPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
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

    /// Holt tägliche Minuten für Mindfulness und Workouts in einem Monat (nur app-spezifische Sessions).
    func fetchDailyMinutesFiltered(forMonth date: Date) async throws -> [Date: (mindfulnessMinutes: Double, workoutMinutes: Double)] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        // Use start of NEXT month as endDate to include ALL samples from current month
        // With .strictStartDate, samples must start BEFORE endDate (exclusive)
        let startOfNextMonth = calendar.date(byAdding: DateComponents(month: 1), to: startOfMonth)!
        return try await fetchDailyMinutesFiltered(from: startOfMonth, to: startOfNextMonth)
    }
    
    /// Legacy-Methode für Abwärtskompatibilität
    func fetchActivityDays(forMonth date: Date) async throws -> Set<Date> {
        let detailed = try await fetchActivityDaysDetailed(forMonth: date)
        return Set(detailed.keys)
    }
    
    /// Prüft, ob Aktivitäten eines bestimmten Typs im gegebenen Zeitraum vorhanden sind.
    func hasActivity(ofType type: String, inRange start: Date, end: Date) async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataUnavailable
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        switch type {
        case "meditation":
            guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
                throw HealthKitError.mindfulTypeUnavailable
            }
            return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Bool, Error>) in
                let query = HKSampleQuery(sampleType: mindfulType, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                    if let error = error {
                        cont.resume(throwing: error)
                        return
                    }
                    cont.resume(returning: !(samples?.isEmpty ?? true))
                }
                self.healthStore.execute(query)
            }
        case "workout":
            let workoutType = HKObjectType.workoutType()
            return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Bool, Error>) in
                let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                    if let error = error {
                        cont.resume(throwing: error)
                        return
                    }
                    cont.resume(returning: !(samples?.isEmpty ?? true))
                }
                self.healthStore.execute(query)
            }
        case "noalc":
            guard let alcoholType = HKObjectType.quantityType(forIdentifier: .numberOfAlcoholicBeverages) else {
                throw HealthKitError.healthDataUnavailable
            }
            return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Bool, Error>) in
                let query = HKSampleQuery(sampleType: alcoholType, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                    if let error = error {
                        cont.resume(throwing: error)
                        return
                    }
                    // Return true if alcohol entry exists (activity logged)
                    cont.resume(returning: !(samples?.isEmpty ?? true))
                }
                self.healthStore.execute(query)
            }
        default:
            return false
        }
    }

    // MARK: - Alcohol Tracking

    /// Schreibt EINEN Alkoholkonsum-Eintrag (Anzahl Drinks) für ein bestimmtes Datum in Apple Health.
    /// - Parameters:
    ///   - drinks: Anzahl der Standard-Drinks (1 Drink = 14g reiner Alkohol)
    ///   - date: Datum des Konsums (wird auf startOfDay normalisiert)
    func logAlcohol(drinks: Int, date: Date) async throws {
        guard let alcoholType = HKObjectType.quantityType(forIdentifier: .numberOfAlcoholicBeverages) else {
            throw HealthKitError.healthDataUnavailable
        }

        // Normalisiere auf Start of Day
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)

        // Erstelle Quantity (Anzahl Drinks)
        let quantity = HKQuantity(unit: HKUnit.count(), doubleValue: Double(drinks))

        // Erstelle Sample (1-Sekunden-Zeitraum am Start of Day)
        let endDate = calendar.date(byAdding: .second, value: 1, to: normalizedDate) ?? normalizedDate
        let sample = HKQuantitySample(type: alcoholType, quantity: quantity, start: normalizedDate, end: endDate)

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

    /// Holt Alkoholkonsum-Einträge für einen Monat aus Apple Health.
    /// - Parameter date: Beliebiges Datum im gewünschten Monat
    /// - Returns: Dictionary [Date: Int] mit startOfDay als Key und Anzahl Drinks als Value
    func fetchAlcoholEntries(forMonth date: Date) async throws -> [Date: Int] {
        guard let alcoholType = HKObjectType.quantityType(forIdentifier: .numberOfAlcoholicBeverages) else {
            throw HealthKitError.healthDataUnavailable
        }

        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfMonth, end: endOfMonth, options: .strictStartDate)

        var alcoholDays = [Date: Int]()

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let query = HKSampleQuery(sampleType: alcoholType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                if let samples = samples as? [HKQuantitySample] {
                    for sample in samples {
                        let drinks = Int(sample.quantity.doubleValue(for: HKUnit.count()))
                        let day = calendar.startOfDay(for: sample.startDate)

                        // Summiere Drinks pro Tag (falls mehrere Einträge)
                        alcoholDays[day, default: 0] += drinks
                    }
                }
                cont.resume()
            }
            self.healthStore.execute(query)
        }

        return alcoholDays
    }

    /// Holt Alkoholkonsum-Einträge für einen Zeitraum aus Apple Health (app-spezifisch gefiltert).
    /// - Parameters:
    ///   - startDate: Beginn des Zeitraums
    ///   - endDate: Ende des Zeitraums
    /// - Returns: Dictionary [Date: Int] mit startOfDay als Key und Anzahl Drinks als Value
    func fetchAlcoholEntriesFiltered(from startDate: Date, to endDate: Date) async throws -> [Date: Int] {
        guard let alcoholType = HKObjectType.quantityType(forIdentifier: .numberOfAlcoholicBeverages) else {
            throw HealthKitError.healthDataUnavailable
        }

        let timePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sourcePredicate = HKQuery.predicateForObjects(from: Set([appSource].compactMap { $0 }))
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [timePredicate, sourcePredicate])

        var alcoholDays = [Date: Int]()

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let query = HKSampleQuery(sampleType: alcoholType, predicate: compoundPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                if let samples = samples as? [HKQuantitySample] {
                    for sample in samples {
                        let drinks = Int(sample.quantity.doubleValue(for: HKUnit.count()))
                        let day = Calendar.current.startOfDay(for: sample.startDate)
                        alcoholDays[day, default: 0] += drinks
                    }
                }
                cont.resume()
            }
            self.healthStore.execute(query)
        }

        return alcoholDays
    }
}
