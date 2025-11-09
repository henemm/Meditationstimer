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
    @State private var alcoholDays: [Date: NoAlcManager.ConsumptionLevel] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    @AppStorage("meditationGoalMinutes") private var meditationGoalMinutes: Double = 10.0
    @AppStorage("workoutGoalMinutes") private var workoutGoalMinutes: Double = 30.0
    @AppStorage("calendarFilterEnabled") private var calendarFilterEnabled: Bool = false

    private let hk = HealthKitManager.shared
    private let calendar = Calendar.current

    @State private var showMeditationInfo = false
    @State private var showWorkoutInfo = false
    @State private var showNoAlcInfo = false
    @State private var scrollProxy: ScrollViewProxy?

    // Helper function that calculates BOTH streak and rewards in one pass
    // Simple Rule: Go FORWARD chronologically, track earned/consumed rewards, find current streak
    private func calculateNoAlcStreakAndRewards() -> (streak: Int, rewards: Int) {
        let today = calendar.startOfDay(for: Date())

        // Sort all dates chronologically (earliest to latest)
        let sortedDates = alcoholDays.keys.sorted()

        guard !sortedDates.isEmpty else { return (0, 0) }

        var consecutiveDays = 0
        var earnedRewards = 0
        var consumedRewards = 0
        var currentStreakStart: Date? = nil

        // Iterate FORWARD through ALL data
        for date in sortedDates {
            guard let level = alcoholDays[date] else { continue }

            if level == .steady {
                // Steady day: count it
                consecutiveDays += 1
                if currentStreakStart == nil {
                    currentStreakStart = date
                }

                // Earn reward every 7 days (max 3 total)
                if consecutiveDays % 7 == 0 && earnedRewards < 3 {
                    earnedRewards += 1
                }
            } else {
                // Easy or Wild day: needs forgiveness
                let availableRewards = earnedRewards - consumedRewards

                if availableRewards > 0 {
                    // Use 1 reward to heal this day
                    consumedRewards += 1
                    consecutiveDays += 1  // Healed day counts!

                    // Check if we earn a new reward for reaching a 7-day milestone
                    if consecutiveDays % 7 == 0 && earnedRewards < 3 {
                        earnedRewards += 1
                    }
                } else {
                    // No rewards available → streak resets
                    consecutiveDays = 0
                    currentStreakStart = nil
                }
            }
        }

        // Calculate final streak: from last streak start to today (or yesterday if no entry today)
        let endDate = alcoholDays[today] != nil ? today : calendar.date(byAdding: .day, value: -1, to: today)!

        var finalStreak = 0
        if currentStreakStart != nil, let _ = endDate as Date? {
            // Count days from streakStart to endDate
            finalStreak = consecutiveDays
        }

        let availableRewards = max(0, earnedRewards - consumedRewards)
        return (finalStreak, availableRewards)
    }

    private var noAlcStreak: Int {
        return calculateNoAlcStreakAndRewards().streak
    }

    private var noAlcStreakPoints: Int {
        return calculateNoAlcStreakAndRewards().rewards
    }

    private var meditationStreak: Int {
        let today = calendar.startOfDay(for: Date())
        let todayMinutes = dailyMinutes[today]?.mindfulnessMinutes ?? 0
        let hasDataToday = round(todayMinutes) >= 2.0

        var currentStreak = 0
        var checkDate = hasDataToday ? today : calendar.date(byAdding: .day, value: -1, to: today)!

        while true {
            let minutes = dailyMinutes[checkDate]?.mindfulnessMinutes ?? 0
            if round(minutes) >= 2.0 {
                currentStreak += 1
                guard let previousDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = previousDate
            } else {
                break
            }
        }

        return currentStreak
    }

    private var workoutStreak: Int {
        let today = calendar.startOfDay(for: Date())
        let todayMinutes = dailyMinutes[today]?.workoutMinutes ?? 0
        let hasDataToday = round(todayMinutes) >= 2.0

        var currentStreak = 0
        var checkDate = hasDataToday ? today : calendar.date(byAdding: .day, value: -1, to: today)!

        while true {
            let minutes = dailyMinutes[checkDate]?.workoutMinutes ?? 0
            if round(minutes) >= 2.0 {
                currentStreak += 1
                guard let previousDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = previousDate
            } else {
                break
            }
        }

        return currentStreak
    }

    var body: some View {
        NavigationView {
            VStack {
                // Scrollbare Monatsliste
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(-6...6, id: \.self) { monthOffset in
                            let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: Date())!
                            MonthView(month: monthDate, activityDays: activityDays, dailyMinutes: dailyMinutes, alcoholDays: alcoholDays, meditationGoalMinutes: meditationGoalMinutes, workoutGoalMinutes: workoutGoalMinutes)
                                .id(monthOffset) // Für ScrollViewReader
                        }
                    }
                    .padding(.horizontal)
                }
                .onAppear {
                    scrollProxy = proxy
                }
            }

            // Streaks Footer
            VStack(spacing: 12) {
                // Meditation Streaks
                HStack {
                    Button(action: { showMeditationInfo = true }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18, weight: .regular))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Meditation Streak Info")

                    Text("Meditation: Streak \(meditationStreak) Day\(meditationStreak == 1 ? "" : "s")")
                        .font(.subheadline)
                    Spacer()
                    rewardsView(for: min(3, meditationStreak / 7), icon: "leaf.fill", color: .blue)
                }
                .sheet(isPresented: $showMeditationInfo) {
                    NavigationStack {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Get a reward every 7 days in a row of meditation (at least 2 minutes per day).")
                                    .font(.body)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Example:")
                                        .font(.headline)
                                    Text("• Days 1-7: Earn 1 reward")
                                    Text("• Days 8-14: Earn 2 rewards")
                                    Text("• Days 15-21: Earn 3 rewards")
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("If you miss a day:")
                                        .font(.headline)
                                    Text("• Lose 1 reward, but keep your streak")
                                    Text("• If you have no rewards left and miss again, streak resets to 0")
                                }
                            }
                            .padding()
                        }
                        .navigationTitle("Meditation Streak")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Fertig") {
                                    showMeditationInfo = false
                                }
                            }
                        }
                    }
                }
                
                // Workout Streaks
                HStack {
                    Button(action: { showWorkoutInfo = true }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18, weight: .regular))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Workout Streak Info")

                    Text("Workouts: Streak \(workoutStreak) Day\(workoutStreak == 1 ? "" : "s")")
                        .font(.subheadline)
                    Spacer()
                    rewardsView(for: min(3, workoutStreak / 7), icon: "flame.fill", color: .purple)
                }
                .sheet(isPresented: $showWorkoutInfo) {
                    NavigationStack {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Get a reward every 7 days in a row of workouts (at least 2 minutes per day).")
                                    .font(.body)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Example:")
                                        .font(.headline)
                                    Text("• Days 1-7: Earn 1 reward")
                                    Text("• Days 8-14: Earn 2 rewards")
                                    Text("• Days 15-21: Earn 3 rewards")
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("If you miss a day:")
                                        .font(.headline)
                                    Text("• Lose 1 reward, but keep your streak")
                                    Text("• If you have no rewards left and miss again, streak resets to 0")
                                }
                            }
                            .padding()
                        }
                        .navigationTitle("Workout Streak")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Fertig") {
                                    showWorkoutInfo = false
                                }
                            }
                        }
                    }
                }

                // NoAlc Streak
                HStack {
                    Button(action: { showNoAlcInfo = true }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18, weight: .regular))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("NoAlc Streak Info")

                    Text("NoAlc: Streak \(noAlcStreak) Day\(noAlcStreak == 1 ? "" : "s")")
                        .font(.subheadline)
                    Spacer()
                    rewardsView(for: noAlcStreakPoints, icon: "drop.fill", color: .green)
                }
                .sheet(isPresented: $showNoAlcInfo) {
                    NavigationStack {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Track your alcohol consumption daily.")
                                    .font(.body)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Levels:")
                                        .font(.headline)
                                    Text("• Steady (💧): 0-1 drinks")
                                    Text("• Easy (✨): 2-5 drinks")
                                    Text("• Wild (💥): 6+ drinks")
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Rewards:")
                                        .font(.headline)
                                    Text("Get a reward every 7 days of logging:")
                                    Text("• Days 1-7: Earn 1 reward")
                                    Text("• Days 8-14: Earn 2 rewards")
                                    Text("• Days 15-21: Earn 3 rewards")
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("If you miss a day:")
                                        .font(.headline)
                                    Text("• Lose 1 reward, but keep your streak")
                                    Text("• If you have no rewards left and miss again, streak resets to 0")
                                }
                            }
                            .padding()
                        }
                        .navigationTitle("NoAlc Streak")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Fertig") {
                                    showNoAlcInfo = false
                                }
                            }
                        }
                    }
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
        .navigationTitle("Kalender")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fertig") {
                    dismiss()
                }
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
            var allAlcoholDays = [Date: NoAlcManager.ConsumptionLevel]()
            for monthOffset in -6...6 {
                let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: Date())!
                do {
                    let days = try await hk.fetchActivityDaysDetailedFiltered(forMonth: monthDate)
                    let minutes = try await hk.fetchDailyMinutesFiltered(forMonth: monthDate)
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

                    // Fetch NoAlc data for each day in the month
                    let monthDays = generateDays(for: monthDate).compactMap { $0 }
                    for day in monthDays {
                        if let level = try? await NoAlcManager.shared.fetchConsumption(for: day) {
                            allAlcoholDays[calendar.startOfDay(for: day)] = level
                        }
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    break
                }
            }
            activityDays = allActivityDays
            dailyMinutes = allDailyMinutes
            alcoholDays = allAlcoholDays
            isLoading = false
            
            // Filter if enabled
            if calendarFilterEnabled {
                var filteredActivityDays = [Date: ActivityType]()
                var filteredDailyMinutes = [Date: (mindfulnessMinutes: Double, workoutMinutes: Double)]()
                for (date, type) in allActivityDays {
                    let mins = allDailyMinutes[date] ?? (0, 0)
                    var hasValid = false
                    if mins.mindfulnessMinutes >= 2.0 { hasValid = true }
                    if mins.workoutMinutes >= 2.0 { hasValid = true }
                    if hasValid {
                        filteredActivityDays[date] = type
                        filteredDailyMinutes[date] = mins
                    }
                }
                activityDays = filteredActivityDays
                dailyMinutes = filteredDailyMinutes
            }
            
            // Scrolle zum aktuellen Monat nach dem Laden der Daten
            DispatchQueue.main.async {
                withAnimation {
                    scrollProxy?.scrollTo(0, anchor: .center)
                }
            }
        }
    }
}

struct MonthView: View {
    let month: Date
    let activityDays: [Date: CalendarView.ActivityType]
    let dailyMinutes: [Date: (mindfulnessMinutes: Double, workoutMinutes: Double)]
    let alcoholDays: [Date: NoAlcManager.ConsumptionLevel]
    let meditationGoalMinutes: Double
    let workoutGoalMinutes: Double
    private let calendar = Calendar.current

    @State private var selectedDate: Date? = nil

    // Custom shape for filled sectors (quarters)
    struct Sector: Shape {
        let startAngle: Angle
        let endAngle: Angle
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            path.move(to: center)
            path.addArc(center: center, radius: rect.width / 2, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            return path
        }
    }

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
                ForEach(days.indices, id: \.self) { index in
                    if let date = days[index] {
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
        let dayNumber = calendar.component(.day, from: date)
        let dayKey = calendar.startOfDay(for: date)
        let mins = dailyMinutes[dayKey] ?? (0, 0)
        let roundedMindfulness = round(mins.mindfulnessMinutes)
        let mindfulnessProgress = min(roundedMindfulness / meditationGoalMinutes, 1.0)
        let roundedWorkout = round(mins.workoutMinutes)
        let workoutProgress = min(roundedWorkout / workoutGoalMinutes, 1.0)
        let alcoholLevel = alcoholDays[dayKey]

        // Determine if day has any activity (for bold number)
        let hasActivity = mins.mindfulnessMinutes >= 2.0 || mins.workoutMinutes >= 2.0 || alcoholLevel != nil

        return ZStack {
            // NoAlc background fill
            if let level = alcoholLevel {
                Circle()
                    .fill(alcoholColor(for: level))
                    .frame(width: 28, height: 28)
            }

            // Workout circle (inner ring)
            if mins.workoutMinutes >= 2.0 {
                Circle()
                    .trim(from: 0, to: workoutProgress)
                    .stroke(Color.purple.opacity(0.8), lineWidth: 5)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 32, height: 32)
            }

            // Mindfulness circle (outer ring)
            if mins.mindfulnessMinutes >= 2.0 {
                Circle()
                    .trim(from: 0, to: mindfulnessProgress)
                    .stroke(Color.blue.opacity(0.8), lineWidth: 5)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 42, height: 42)
            }

            Text("\(dayNumber)")
                .font(.system(size: 16, weight: hasActivity ? .semibold : .regular))
                .foregroundColor(alcoholLevel != nil ? .alcoholText : .primary)
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
            // Only show sheet if day has activity
            if hasActivity {
                selectedDate = dayKey
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedDate == dayKey },
            set: { if !$0 { selectedDate = nil } }
        )) {
            DayDetailSheet(
                date: dayKey,
                mindfulnessMinutes: mins.mindfulnessMinutes,
                workoutMinutes: mins.workoutMinutes
            )
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

    private func alcoholColor(for level: NoAlcManager.ConsumptionLevel) -> Color {
        switch level {
        case .steady:
            return .alcoholSteady
        case .easy:
            return .alcoholEasy
        case .wild:
            return .alcoholWild
        }
    }

    private func tooltipView(for mins: (mindfulnessMinutes: Double, workoutMinutes: Double), date: Date) -> AnyView? {
        var texts: [Text] = []
        if mins.mindfulnessMinutes > 0 {
            let rounded = Int(round(mins.mindfulnessMinutes))
            texts.append(Text("Meditation: \(rounded)/\(Int(meditationGoalMinutes)) Min").foregroundColor(Color.blue.opacity(0.8)))
        }
        if mins.workoutMinutes > 0 {
            let rounded = Int(round(mins.workoutMinutes))
            texts.append(Text("Workouts: \(rounded)/\(Int(workoutGoalMinutes)) Min").foregroundColor(Color.purple))
        }
        if let alcoholLevel = alcoholDays[date] {
            let label = "\(alcoholLevel.emoji) \(alcoholLevel.label)"
            texts.append(Text("NoAlc: \(label)").foregroundColor(.green))
        }
        if texts.isEmpty { return nil }
        return AnyView(VStack(alignment: .leading, spacing: 2) {
            ForEach(0..<texts.count, id: \.self) { index in
                texts[index]
            }
        }
        .padding(6)
        .background(Color.white.opacity(0.95))
        .cornerRadius(6)
        .shadow(radius: 3))
    }
}