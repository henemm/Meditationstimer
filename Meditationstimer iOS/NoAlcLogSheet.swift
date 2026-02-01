//
//  NoAlcLogSheet.swift
//  Lean Health Timer
//
//  Created by Claude on 30.10.2025.
//

import SwiftUI
import SwiftData

struct NoAlcLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isExpanded = false
    @State private var selectedDate = Date()
    @State private var isLogging = false
    @State private var errorMessage: String?
    @State private var showNoAlcInfo = false

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            if !isExpanded {
                // Compact Tooltip Mode
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Text("NoAlc Diary")
                                .font(.title3)
                                .fontWeight(.semibold)
                            InfoButton { showNoAlcInfo = true }
                        }

                        Text(titleText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(subtitleText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 32)

                    // Quick Log Buttons
                    HStack(spacing: 12) {
                        ForEach(TrackerLevel.noAlcLevels) { level in
                            ConsumptionButton(
                                level: level,
                                isLogging: isLogging,
                                action: { await logConsumption(level, dismissImmediately: true) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)

                    // Erweitert Button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded = true
                        }
                    } label: {
                        Text("Advanced")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 16)

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }
                }
            } else {
                // Extended Mode with DatePicker
                NavigationView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.blue)
                            Text("Choose Date")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .padding(.top, 20)

                        // Date Picker
                        DatePicker(
                            "Date",
                            selection: $selectedDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .padding(.horizontal)

                        // Consumption Buttons
                        VStack(spacing: 12) {
                            Text("How was it?")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                ForEach(TrackerLevel.noAlcLevels) { level in
                                    ConsumptionButton(
                                        level: level,
                                        isLogging: isLogging,
                                        action: { await logConsumption(level, dismissImmediately: false) }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)

                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.horizontal)
                        }

                        Spacer()
                    }
                    .navigationTitle("Log Drinks")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                withAnimation {
                                    isExpanded = false
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, 20)
        .presentationDetents(isExpanded ? [.large] : [.height(240)])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showNoAlcInfo) {
            InfoSheet(
                title: "NoAlc Diary",
                description: "The NoAlc Diary helps you track your alcohol consumption and develop a mindful approach to it. The system uses three categories for self-reflection.",
                usageTips: [
                    "🟢 Steady: No or moderate consumption – you're on a good path",
                    "🟡 Easy: Increased consumption – watch your balance",
                    "🔴 Wild: Intensive consumption – be especially mindful",
                    "Daily logging helps recognize patterns",
                    "Smart Reminders remind you automatically"
                ]
            )
        }
    }

    private var titleText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 18 {
            return NSLocalizedString("Yesterday Evening", comment: "NoAlc sheet title before 6pm")
        } else {
            return NSLocalizedString("Today", comment: "NoAlc sheet title after 6pm")
        }
    }

    private var subtitleText: String {
        let targetDay = targetDayForLogging()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: targetDay)
    }

    /// Determines target day based on current time (matches NoAlc cutoff logic)
    /// - Rule: < 18:00 = yesterday, >= 18:00 = today
    private func targetDayForLogging() -> Date {
        let hour = calendar.component(.hour, from: Date())
        let today = calendar.startOfDay(for: Date())

        if hour < 18 {
            return calendar.date(byAdding: .day, value: -1, to: today)!
        } else {
            return today
        }
    }

    @MainActor
    private func logConsumption(_ level: TrackerLevel, dismissImmediately: Bool) async {
        isLogging = true
        errorMessage = nil

        // Find NoAlc tracker by healthKitType
        let descriptor = FetchDescriptor<Tracker>(predicate: #Predicate {
            $0.healthKitType == "HKQuantityTypeIdentifierNumberOfAlcoholicBeverages"
        })

        guard let noAlcTracker = try? modelContext.fetch(descriptor).first else {
            errorMessage = NSLocalizedString("NoAlc tracker not found", comment: "")
            isLogging = false
            return
        }

        // Use selected date if expanded, otherwise use target day
        let dateToLog = isExpanded ? selectedDate : targetDayForLogging()

        // Log consumption via TrackerManager (handles HealthKit + SwiftData)
        let _ = TrackerManager.shared.logEntry(
            for: noAlcTracker,
            value: level.id,
            timestamp: dateToLog,
            in: modelContext
        )

        // Save context
        do {
            try modelContext.save()
        } catch {
            errorMessage = String(format: NSLocalizedString("Error: %@", comment: ""), error.localizedDescription)
            isLogging = false
            return
        }

        // Dismiss immediately (quick mode) or after delay (extended mode)
        if dismissImmediately {
            dismiss()
        } else {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            dismiss()
        }
    }
}

// MARK: - Consumption Button

struct ConsumptionButton: View {
    let level: TrackerLevel
    let isLogging: Bool
    let action: () async -> Void

    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            VStack(spacing: 8) {
                Text(level.icon)
                    .font(.system(size: 40))
                Text(level.localizedLabel)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
        .disabled(isLogging)
        .scaleEffect(isLogging ? 0.95 : 1.0)
        .animation(.spring(response: 0.3), value: isLogging)
    }
}

#Preview {
    NoAlcLogSheet()
}
