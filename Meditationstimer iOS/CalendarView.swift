//
//  CalendarView.swift
//  Meditationstimer iOS
//
//  Created by AI Assistant on 20.10.2025.
//

import SwiftUI
import HealthKit

struct CalendarView: View {
    enum ActivityType {
        case mindfulness
        case workout
        case both
    }
    
    @State private var activityDays: [Date: ActivityType] = [:]
    @State private var dailyMinutes: [Date: (mindfulnessMinutes: Double, workoutMinutes: Double)] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    @AppStorage("meditationGoalMinutes") private var meditationGoalMinutes: Double = 10.0
    @AppStorage("workoutGoalMinutes") private var workoutGoalMinutes: Double = 30.0

    private let hk = HealthKitManager.shared
    private let calendar = Calendar.current

    var body: some View {
        VStack {
            // Header mit Close-Button
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
                .padding(.trailing)
                .padding(.top, 20) // Mehr Abstand oben
            }

            // Scrollbare Monatsliste
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(-6...6, id: \.self) { monthOffset in
                            let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: Date())!
                            MonthView(month: monthDate, activityDays: activityDays, dailyMinutes: dailyMinutes, meditationGoalMinutes: meditationGoalMinutes, workoutGoalMinutes: workoutGoalMinutes)
                                .id(monthOffset) // Für ScrollViewReader
                        }
                    }
                    .padding(.horizontal)
                }
                .onAppear {
                    // Scrolle zum aktuellen Monat (offset 0)
                    proxy.scrollTo(0, anchor: .center)
                }
            }

            if isLoading {
                ProgressView("Lade Daten...")
            }

            if let error = errorMessage {
                Text("Fehler: \(error)")
                    .foregroundColor(.red)
                    .padding()
            }

            // Debug-Info
            Text("Aktive Tage: \(activityDays.count)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top)
        }
        .onAppear {
            Task {
                let authorized = await hk.isAuthorized()
                if !authorized {
                    do {
                        try await hk.requestAuthorization()
                        loadActivityDays()
                    } catch {
                        errorMessage = "HealthKit-Berechtigung erforderlich: \(error.localizedDescription)"
                    }
                } else {
                    loadActivityDays()
                }
            }
        }
    }

    private func dayView(for date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let hasActivity = activityDays[calendar.startOfDay(for: date)] != nil
        let dayNumber = calendar.component(.day, from: date)

        return ZStack {
            Circle()
                .fill(hasActivity ? Color.green.opacity(0.3) : Color.clear)
                .frame(width: 35, height: 35)

            Text("\(dayNumber)")
                .font(.system(size: 16))
                .foregroundColor(isToday ? .blue : .primary)
        }
        .frame(height: 40)
    }

    private func generateDays(for month: Date) -> [Date?] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        let startWeekday = calendar.component(.weekday, from: startOfMonth) - 1 // 0 = Sonntag, aber wir starten mit Montag
        let adjustedStartWeekday = (startWeekday + 6) % 7 // Montag = 0

        var days: [Date?] = Array(repeating: nil, count: adjustedStartWeekday)

        var currentDate = startOfMonth
        while currentDate <= endOfMonth {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return days
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func loadActivityDays() {
        isLoading = true
        errorMessage = nil
        Task {
            var allActivityDays = [Date: ActivityType]()
            var allDailyMinutes = [Date: (mindfulnessMinutes: Double, workoutMinutes: Double)]()
            for monthOffset in -6...6 {
                let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: Date())!
                do {
                    let days = try await hk.fetchActivityDaysDetailed(forMonth: monthDate)
                    let minutes = try await hk.fetchDailyMinutes(forMonth: monthDate)
                    // Merge dictionaries, preferring .both if both types exist
                    for (date, type) in days {
                        let calendarType: ActivityType
                        switch type {
                        case .mindfulness:
                            calendarType = .mindfulness
                        case .workout:
                            calendarType = .workout
                        case .both:
                            calendarType = .both
                        }
                        if let existing = allActivityDays[date] {
                            if existing != calendarType {
                                allActivityDays[date] = .both
                            }
                        } else {
                            allActivityDays[date] = calendarType
                        }
                    }
                    // Merge minutes
                    for (date, mins) in minutes {
                        var current = allDailyMinutes[date] ?? (0, 0)
                        current.mindfulnessMinutes += mins.mindfulnessMinutes
                        current.workoutMinutes += mins.workoutMinutes
                        allDailyMinutes[date] = current
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    break
                }
            }
            activityDays = allActivityDays
            dailyMinutes = allDailyMinutes
            isLoading = false
        }
    }
}

struct MonthView: View {
    let month: Date
    let activityDays: [Date: CalendarView.ActivityType]
    let dailyMinutes: [Date: (mindfulnessMinutes: Double, workoutMinutes: Double)]
    let meditationGoalMinutes: Double
    let workoutGoalMinutes: Double
    private let calendar = Calendar.current

    var body: some View {
        VStack {
            Text(monthYearString(from: month))
                .font(.title2)
                .bold()
                .padding(.bottom, 10)

            // Wochentage
            HStack {
                ForEach(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"], id: \.self) { day in
                    Text(day)
                        .frame(maxWidth: .infinity)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Kalender-Grid
            let days = generateDays(for: month)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                ForEach(days, id: \.self) { date in
                    if let date = date {
                        dayView(for: date)
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
        }
        .padding(.vertical)
    }

    private func dayView(for date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let activityType = activityDays[calendar.startOfDay(for: date)]
        let dayNumber = calendar.component(.day, from: date)
        let dayKey = calendar.startOfDay(for: date)
        let mins = dailyMinutes[dayKey] ?? (0, 0)
        let mindfulnessProgress = min(mins.mindfulnessMinutes / meditationGoalMinutes, 1.0)
        let workoutProgress = min(mins.workoutMinutes / workoutGoalMinutes, 1.0)

        return ZStack {
            // Mindfulness circle (blue, partial fill)
            if mins.mindfulnessMinutes > 0 {
                Circle()
                    .trim(from: 0, to: mindfulnessProgress)
                    .stroke(Color.mindfulnessBlue, lineWidth: 3)
                    .rotationEffect(.degrees(-90)) // Start from top
                    .frame(width: 35, height: 35)
            }

            // Workout circle (violet, partial fill, offset slightly)
            if mins.workoutMinutes > 0 {
                Circle()
                    .trim(from: 0, to: workoutProgress)
                    .stroke(Color.workoutViolet, lineWidth: 3)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 37, height: 37)
            }

            // If both, maybe a combined indicator, but for now separate

            Text("\(dayNumber)")
                .font(.system(size: 16, weight: activityType != nil ? .semibold : .regular))
                .foregroundColor(.primary)
        }
        .frame(height: 40)
        // Red tiny dot in the bottom-right to indicate TODAY
        .overlay(alignment: .bottomTrailing) {
            if isToday {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                    .offset(x: 4, y: 4)
            }
        }
    }
    
    private func generateDays(for month: Date) -> [Date?] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        let startWeekday = calendar.component(.weekday, from: startOfMonth) - 1 // 0 = Sonntag, aber wir starten mit Montag
        let adjustedStartWeekday = (startWeekday + 6) % 7 // Montag = 0

        var days: [Date?] = Array(repeating: nil, count: adjustedStartWeekday)

        var currentDate = startOfMonth
        while currentDate <= endOfMonth {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return days
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}