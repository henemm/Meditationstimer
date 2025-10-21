//
//  CalendarView.swift
//  Meditationstimer iOS
//
//  Created by AI Assistant on 20.10.2025.
//

import SwiftUI
import HealthKit

extension Color {
    /// Light blue color used for mindfulness activities in calendar
    static let mindfulnessBlue = Color(red: 0.67, green: 0.86, blue: 0.98)
    
    /// Violet color used for workout activities and buttons
    static let workoutViolet = Color(red: 0.58, green: 0.31, blue: 0.73)
    
    /// Red color used for today's indicator in calendar
    static let todayRed = Color.red
}

struct CalendarView: View {
    enum ActivityType {
        case mindfulness
        case workout
        case both
    }
    
    @State private var activityDays: [Date: ActivityType] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

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
                            MonthView(month: monthDate, activityDays: activityDays)
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
            for monthOffset in -6...6 {
                let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: Date())!
                do {
                    let days = try await hk.fetchActivityDaysDetailed(forMonth: monthDate)
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
                } catch {
                    errorMessage = error.localizedDescription
                    break
                }
            }
            activityDays = allActivityDays
            isLoading = false
        }
    }
}

struct MonthView: View {
    let month: Date
    let activityDays: [Date: CalendarView.ActivityType]
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

        return ZStack {
            // Basis: filled circle for mindfulness (or when any activity exists and includes mindfulness)
            if let type = activityType {
                if type == .mindfulness || type == .both {
                    Circle()
                        .fill(Color.mindfulnessBlue)
                        .frame(width: 35, height: 35)
                } else {
                    // If only workout, draw an empty background so the number remains readable
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 35, height: 35)
                }
            }

            // Violet ring for workout
            if let type = activityType {
                if type == .workout || type == .both {
                    Circle()
                        .stroke(Color.workoutViolet, lineWidth: 2)
                        .frame(width: 37, height: 37)
                }
            }

            Text("\(dayNumber)")
                .font(.system(size: 16, weight: activityType != nil ? .semibold : .regular))
                .foregroundColor(activityType != nil ? .white : .primary)
        }
        .frame(height: 40)
        // Red tiny dot in the bottom-right to indicate TODAY
        .overlay(alignment: .bottomTrailing) {
            if isToday {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                    .offset(x: -4, y: -4)
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