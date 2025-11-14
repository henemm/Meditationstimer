//
//  NoAlcManager.swift
//  Lean Health Timer
//
//  Created by Claude on 30.10.2025.
//

import Foundation
import HealthKit

/// Manages alcohol consumption tracking via HealthKit
final class NoAlcManager {
    static let shared = NoAlcManager()

    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current

    enum ConsumptionLevel: Int, CaseIterable {
        case steady = 0  // 0-1 drinks
        case easy = 4    // 2-5 drinks
        case wild = 6    // 6+ drinks

        var healthKitValue: Int {
            return self.rawValue
        }

        var label: String {
            switch self {
            case .steady: return NSLocalizedString("Steady", comment: "NoAlc consumption level: minimal/no drinking")
            case .easy: return NSLocalizedString("Easy", comment: "NoAlc consumption level: moderate drinking")
            case .wild: return NSLocalizedString("Wild", comment: "NoAlc consumption level: heavy drinking")
            }
        }

        var emoji: String {
            switch self {
            case .steady: return "💧"
            case .easy: return "✨"
            case .wild: return "💥"
            }
        }

        static func fromHealthKitValue(_ value: Int) -> ConsumptionLevel? {
            return ConsumptionLevel(rawValue: value)
        }

        static func fromDrinkCount(_ count: Int) -> ConsumptionLevel {
            switch count {
            case 0...1:
                return .steady
            case 2...5:
                return .easy
            default:  // 6+
                return .wild
            }
        }
    }

    private init() {}

    // MARK: - Day Assignment Logic

    /// Determines target day based on current time
    /// - Rule: < 18:00 = yesterday, >= 18:00 = today
    func targetDay(for date: Date = Date()) -> Date {
        let hour = calendar.component(.hour, from: date)
        let today = calendar.startOfDay(for: date)

        if hour < 18 {
            // Before 18:00 → reference yesterday
            return calendar.date(byAdding: .day, value: -1, to: today)!
        } else {
            // At/after 18:00 → reference today
            return today
        }
    }

    // MARK: - HealthKit Integration

    /// Requests authorization for alcohol tracking
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw NSError(domain: "NoAlcManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit not available"])
        }

        guard let alcoholType = HKObjectType.quantityType(forIdentifier: .numberOfAlcoholicBeverages) else {
            throw NSError(domain: "NoAlcManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Alcohol type unavailable"])
        }

        try await healthStore.requestAuthorization(toShare: [alcoholType], read: [alcoholType])
    }

    /// Logs alcohol consumption for a specific day
    func logConsumption(_ level: ConsumptionLevel, for date: Date) async throws {
        guard let alcoholType = HKObjectType.quantityType(forIdentifier: .numberOfAlcoholicBeverages) else {
            throw NSError(domain: "NoAlcManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Alcohol type unavailable"])
        }

        let targetDay = calendar.startOfDay(for: date)
        let quantity = HKQuantity(unit: .count(), doubleValue: Double(level.healthKitValue))
        let sample = HKQuantitySample(type: alcoholType, quantity: quantity, start: targetDay, end: targetDay)

        try await healthStore.save(sample)

        // Reverse Smart Reminders: Cancel NoAlc reminders after logging
        #if os(iOS)
        SmartReminderEngine.shared.cancelMatchingReminders(for: .noalc, completedAt: Date())
        #endif
    }

    /// Fetches alcohol data for a specific day
    func fetchConsumption(for date: Date) async throws -> ConsumptionLevel? {
        guard let alcoholType = HKObjectType.quantityType(forIdentifier: .numberOfAlcoholicBeverages) else {
            return nil
        }

        let targetDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: targetDay)!

        let predicate = HKQuery.predicateForSamples(withStart: targetDay, end: endOfDay, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: alcoholType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let value = Int(sample.quantity.doubleValue(for: .count()))
                // Try our encoded values first (0, 4, 6), fallback to drink count mapping
                let level = ConsumptionLevel.fromHealthKitValue(value) ?? ConsumptionLevel.fromDrinkCount(value)
                continuation.resume(returning: level)
            }

            healthStore.execute(query)
        }
    }
}
