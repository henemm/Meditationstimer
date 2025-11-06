//
//  DayDetailSheet.swift
//  Meditationstimer
//
//  Created by Claude Code on 06.11.25.
//

import SwiftUI
import HealthKit

/// Detailed activity sheet for a specific day showing summary and individual sessions
struct DayDetailSheet: View {
    let date: Date
    let mindfulnessMinutes: Double
    let workoutMinutes: Double
    @Environment(\.dismiss) private var dismiss

    @State private var sessions: [ActivitySession] = []
    @State private var noAlcLevel: NoAlcManager.ConsumptionLevel? = nil
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let healthStore = HKHealthStore()
    private let noAlcManager = NoAlcManager.shared
    private let calendar = Calendar.current

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Zusammenfassung")
                            .font(.headline)
                            .foregroundColor(.workoutViolet)

                        HStack(spacing: 20) {
                            // Meditation Summary
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "leaf.fill")
                                        .foregroundColor(.blue)
                                    Text("Meditation")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Text("\(Int(round(mindfulnessMinutes))) Min")
                                    .font(.title3.bold())
                                    .foregroundColor(.blue)
                            }

                            Divider()
                                .frame(height: 40)

                            // Workout Summary
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.purple)
                                    Text("Workouts")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Text("\(Int(round(workoutMinutes))) Min")
                                    .font(.title3.bold())
                                    .foregroundColor(.purple)
                            }

                            Divider()
                                .frame(height: 40)

                            // NoAlc Summary
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "drop.fill")
                                        .foregroundColor(noAlcColor)
                                    Text("NoAlc")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Text(noAlcLabel)
                                    .font(.title3.bold())
                                    .foregroundColor(noAlcColor)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    Divider()

                    // Detail Section - Individual Sessions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Einzelne Sessions")
                            .font(.headline)
                            .foregroundColor(.workoutViolet)

                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding()
                        } else if let error = errorMessage {
                            Text("Fehler: \(error)")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                        } else if sessions.isEmpty {
                            Text("Keine Sessions an diesem Tag")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(sessions) { session in
                                SessionRow(session: session)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(dateString(from: date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadSessions()
        }
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    private var noAlcLabel: String {
        guard let level = noAlcLevel else {
            return "Keine Daten"
        }
        return "\(level.emoji) \(level.label)"
    }

    private var noAlcColor: Color {
        guard let level = noAlcLevel else {
            return .gray
        }
        // Use spec colors: Steady: #0EBF6E, Easy: #89D6B2, Wild: #B6B6B6
        switch level {
        case .steady:
            return Color(red: 0x0E/255, green: 0xBF/255, blue: 0x6E/255)
        case .easy:
            return Color(red: 0x89/255, green: 0xD6/255, blue: 0xB2/255)
        case .wild:
            return Color(red: 0xB6/255, green: 0xB6/255, blue: 0xB6/255)
        }
    }

    private func loadSessions() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

                // Fetch mindfulness and workout sessions
                let rawSessions = try await fetchSessions(from: startOfDay, to: endOfDay)

                // Fetch NoAlc data
                let fetchedNoAlcLevel = try? await noAlcManager.fetchConsumption(for: date)
                noAlcLevel = fetchedNoAlcLevel

                // Add NoAlc as a "session" if it exists (for display in sessions list)
                var allSessions = rawSessions
                if let level = fetchedNoAlcLevel {
                    allSessions.append(ActivitySession(
                        id: "noalc-\(startOfDay.timeIntervalSince1970)",
                        type: .noalc(level),
                        startDate: startOfDay,
                        endDate: startOfDay,
                        duration: 0,
                        calories: nil,
                        workoutName: nil
                    ))
                }

                sessions = allSessions.sorted { $0.startDate < $1.startDate }
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func fetchSessions(from startDate: Date, to endDate: Date) async throws -> [ActivitySession] {
        var result: [ActivitySession] = []

        // Fetch Mindfulness sessions
        let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        let mindfulQuery = HKSampleQuery(
            sampleType: mindfulType,
            predicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate),
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, error in
            if let error = error {
                print("[DayDetailSheet] Error fetching mindfulness: \(error)")
                return
            }
            guard let samples = samples as? [HKCategorySample] else { return }

            for sample in samples {
                // Filter by source (only this app)
                let bundleId = Bundle.main.bundleIdentifier ?? ""
                if sample.sourceRevision.source.bundleIdentifier != bundleId { continue }

                let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60.0
                if duration < 2.0 { continue }

                result.append(ActivitySession(
                    id: sample.uuid.uuidString,
                    type: .mindfulness,
                    startDate: sample.startDate,
                    endDate: sample.endDate,
                    duration: duration,
                    calories: nil,
                    workoutName: nil
                ))
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.execute(mindfulQuery)
            // Simple wait - in production you'd want proper async handling
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                continuation.resume()
            }
        }

        // Fetch Workout sessions
        let workoutType = HKObjectType.workoutType()
        let workoutQuery = HKSampleQuery(
            sampleType: workoutType,
            predicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate),
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, error in
            if let error = error {
                print("[DayDetailSheet] Error fetching workouts: \(error)")
                return
            }
            guard let samples = samples as? [HKWorkout] else { return }

            for sample in samples {
                // Filter by source
                let bundleId = Bundle.main.bundleIdentifier ?? ""
                if sample.sourceRevision.source.bundleIdentifier != bundleId { continue }

                let duration = sample.duration / 60.0
                if duration < 2.0 { continue }

                let calories: Double?
                if #available(iOS 18.0, *) {
                    // Use new API for iOS 18+
                    if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                        calories = sample.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
                    } else {
                        calories = nil
                    }
                } else {
                    // Fallback for iOS 17 and earlier
                    calories = sample.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                }
                let workoutName = sample.workoutActivityType.name

                result.append(ActivitySession(
                    id: sample.uuid.uuidString,
                    type: .workout,
                    startDate: sample.startDate,
                    endDate: sample.endDate,
                    duration: duration,
                    calories: calories,
                    workoutName: workoutName
                ))
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.execute(workoutQuery)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                continuation.resume()
            }
        }

        return result
    }
}

// MARK: - SessionRow
struct SessionRow: View {
    let session: ActivitySession

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconName)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 32)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(sessionTitle)
                    .font(.body.weight(.medium))

                HStack(spacing: 8) {
                    // Only show time for mindfulness and workout
                    if case .noalc = session.type {
                        // NoAlc: just show the emoji and label
                        Text(noAlcInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(timeString(from: session.startDate))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text("\(Int(round(session.duration))) Min")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let calories = session.calories {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("\(Int(calories)) kcal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private var iconName: String {
        switch session.type {
        case .mindfulness:
            return "leaf.fill"
        case .workout:
            return "flame.fill"
        case .noalc:
            return "drop.fill"
        }
    }

    private var iconColor: Color {
        switch session.type {
        case .mindfulness:
            return .blue
        case .workout:
            return .purple
        case .noalc(let level):
            // Use spec colors
            switch level {
            case .steady:
                return Color(red: 0x0E/255, green: 0xBF/255, blue: 0x6E/255)
            case .easy:
                return Color(red: 0x89/255, green: 0xD6/255, blue: 0xB2/255)
            case .wild:
                return Color(red: 0xB6/255, green: 0xB6/255, blue: 0xB6/255)
            }
        }
    }

    private var sessionTitle: String {
        switch session.type {
        case .mindfulness:
            return "Meditation"
        case .workout:
            return session.workoutName ?? "Workout"
        case .noalc:
            return "Alcohol Tracking"
        }
    }

    private var noAlcInfo: String {
        if case .noalc(let level) = session.type {
            return "\(level.emoji) \(level.label)"
        }
        return ""
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - ActivitySession Model
struct ActivitySession: Identifiable {
    let id: String
    let type: ActivityType
    let startDate: Date
    let endDate: Date
    let duration: Double  // in minutes
    let calories: Double?
    let workoutName: String?

    enum ActivityType {
        case mindfulness
        case workout
        case noalc(NoAlcManager.ConsumptionLevel)
    }
}

// MARK: - HKWorkoutActivityType Extension
extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .highIntensityIntervalTraining: return "HIIT"
        case .functionalStrengthTraining: return "Kraft"
        case .yoga: return "Yoga"
        case .running: return "Laufen"
        case .walking: return "Gehen"
        case .cycling: return "Radfahren"
        case .swimming: return "Schwimmen"
        default: return "Workout"
        }
    }
}
