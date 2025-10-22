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
    
    @EnvironmentObject var streakManager: StreakManager
    
    @State private var showMeditationInfo = false
    @State private var showWorkoutInfo = false

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
                .background(.ultraThinMaterial)
                .padding(8)
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

            // Streaks Footer
            VStack(spacing: 12) {
                // Meditation Streaks
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .onTapGesture {
                            showMeditationInfo = true
                        }
                    Text("Meditation: Streak \(streakManager.meditationStreak.currentStreakDays) Days")
                        .font(.subheadline)
                    Spacer()
                    rewardsView(for: streakManager.meditationStreak.rewardsEarned, icon: "leaf.fill", color: .blue)
                }
                .popover(isPresented: $showMeditationInfo) {
                    Text("Get a reward every 7 days in a row of meditation (at least 2 minutes per day).\n\nExample:\n• Days 1-7: Earn 1 reward\n• Days 8-14: Earn 2 rewards\n• Days 15-21: Earn 3 rewards\n\nIf you miss a day:\n• Lose 1 reward, but keep your streak\n• If you have no rewards left and miss again, streak resets to 0")
                        .padding()
                        .frame(maxWidth: 280)
                        .font(.footnote)
                }
                
                // Workout Streaks
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .onTapGesture {
                            showWorkoutInfo = true
                        }
                    Text("Workouts: Streak \(streakManager.workoutStreak.currentStreakDays) Days")
                        .font(.subheadline)
                    Spacer()
                    rewardsView(for: streakManager.workoutStreak.rewardsEarned, icon: "flame.fill", color: .purple)
                }
                .popover(isPresented: $showWorkoutInfo) {
                    Text("Get a reward every 7 days in a row of workouts (at least 2 minutes per day).\n\nExample:\n• Days 1-7: Earn 1 reward\n• Days 8-14: Earn 2 rewards\n• Days 15-21: Earn 3 rewards\n\nIf you miss a day:\n• Lose 1 reward, but keep your streak\n• If you have no rewards left and miss again, streak resets to 0")
                        .padding()
                        .frame(maxWidth: 280)
                        .font(.footnote)
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .padding(.top)

            if isLoading {
                ProgressView("Lade Daten...")
            }

            if let error = errorMessage {
                Text("Fehler: \(error)")
                    .foregroundColor(.red)
                    .padding()
            }
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

    private func rewardsView(for count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 2) {
            if count == 0 {
                Text("0")
                    .font(.subheadline)
                    .foregroundColor(color)
                Image(systemName: icon)
                    .foregroundColor(color)
            } else {
                ForEach(0..<count, id: \.self) { _ in
                    Image(systemName: icon)
                        .foregroundColor(color)
                }
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
            
            // Update streaks after loading data
            Task {
                await streakManager.updateStreaks()
            }
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

    @State private var showTooltipFor: Date? = nil

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
        let _ = min(mins.mindfulnessMinutes / meditationGoalMinutes, 1.0)
        let workoutProgress = min(mins.workoutMinutes / workoutGoalMinutes, 1.0)

        return ZStack {
            // Mindfulness circle (light blue, filled)
            if mins.mindfulnessMinutes > 0 {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 35, height: 35)
            }

            // Workout circle (purple, ring based on progress)
            if mins.workoutMinutes > 0 {
                Circle()
                    .trim(from: 0, to: workoutProgress)
                    .stroke(Color.purple.opacity(0.8), lineWidth: 3)
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
        .onTapGesture {
            showTooltipFor = dayKey
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showTooltipFor = nil
            }
        }
        .popover(isPresented: Binding(get: { showTooltipFor == dayKey }, set: { if !$0 { showTooltipFor = nil } })) {
            if let tooltip = tooltipView(for: mins) {
                tooltip
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

    private func tooltipView(for mins: (mindfulnessMinutes: Double, workoutMinutes: Double)) -> AnyView? {
        var texts: [Text] = []
        if mins.mindfulnessMinutes > 0 {
            texts.append(Text("Meditation: \(Int(mins.mindfulnessMinutes))/\(Int(meditationGoalMinutes)) Min").foregroundColor(Color.blue.opacity(0.8)))
        }
        if mins.workoutMinutes > 0 {
            texts.append(Text("Workouts: \(Int(mins.workoutMinutes))/\(Int(workoutGoalMinutes)) Min").foregroundColor(Color.purple))
        }
        if texts.isEmpty { return nil }
        if texts.count == 1 {
            return AnyView(texts[0]
                .padding(6)
                .background(Color.white.opacity(0.95))
                .cornerRadius(6)
                .shadow(radius: 3))
        } else {
            return AnyView(VStack(alignment: .leading, spacing: 2) {
                texts[0]
                texts[1]
            }
            .padding(6)
            .background(Color.white.opacity(0.95))
            .cornerRadius(6)
            .shadow(radius: 3))
        }
    }
}