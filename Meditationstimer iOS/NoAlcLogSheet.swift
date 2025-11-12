//
//  NoAlcLogSheet.swift
//  Lean Health Timer
//
//  Created by Claude on 30.10.2025.
//

import SwiftUI

struct NoAlcLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isExpanded = false
    @State private var selectedDate = Date()
    @State private var isLogging = false
    @State private var errorMessage: String?

    private let noAlc = NoAlcManager.shared

    var body: some View {
        VStack(spacing: 0) {
            if !isExpanded {
                // Compact Tooltip Mode
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 8) {
                        Text("NoAlc-Tagebuch")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text(titleText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(subtitleText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 52)

                    // Quick Log Buttons
                    HStack(spacing: 12) {
                        ConsumptionButton(
                            level: .steady,
                            isLogging: isLogging,
                            action: { await logConsumption(.steady, dismissImmediately: true) }
                        )

                        ConsumptionButton(
                            level: .easy,
                            isLogging: isLogging,
                            action: { await logConsumption(.easy, dismissImmediately: true) }
                        )

                        ConsumptionButton(
                            level: .wild,
                            isLogging: isLogging,
                            action: { await logConsumption(.wild, dismissImmediately: true) }
                        )
                    }
                    .padding(.horizontal, 16)

                    // Erweitert Button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded = true
                        }
                    } label: {
                        Text("Erweitert")
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
                            Text("Datum wählen")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .padding(.top, 20)

                        // Date Picker
                        DatePicker(
                            "Datum",
                            selection: $selectedDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .padding(.horizontal)

                        // Consumption Buttons
                        VStack(spacing: 12) {
                            Text("Wie war es?")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                ConsumptionButton(
                                    level: .steady,
                                    isLogging: isLogging,
                                    action: { await logConsumption(.steady, dismissImmediately: false) }
                                )

                                ConsumptionButton(
                                    level: .easy,
                                    isLogging: isLogging,
                                    action: { await logConsumption(.easy, dismissImmediately: false) }
                                )

                                ConsumptionButton(
                                    level: .wild,
                                    isLogging: isLogging,
                                    action: { await logConsumption(.wild, dismissImmediately: false) }
                                )
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
        .presentationDetents(isExpanded ? [.large] : [.height(200)])
        .presentationDragIndicator(.visible)
    }

    private var titleText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 18 {
            return "Yesterday Evening"
        } else {
            return "Today"
        }
    }

    private var subtitleText: String {
        let targetDay = noAlc.targetDay()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: targetDay)
    }

    @MainActor
    private func logConsumption(_ level: NoAlcManager.ConsumptionLevel, dismissImmediately: Bool) async {
        isLogging = true
        errorMessage = nil

        do {
            // Request authorization if needed
            try await noAlc.requestAuthorization()

            // Use selected date if expanded, otherwise use target day
            let dateToLog = isExpanded ? selectedDate : noAlc.targetDay()

            // Log consumption
            try await noAlc.logConsumption(level, for: dateToLog)

            // Dismiss immediately (quick mode) or after delay (extended mode)
            if dismissImmediately {
                dismiss()
            } else {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                dismiss()
            }
        } catch {
            errorMessage = "Fehler: \(error.localizedDescription)"
            isLogging = false
        }
    }
}

// MARK: - Consumption Button

struct ConsumptionButton: View {
    let level: NoAlcManager.ConsumptionLevel
    let isLogging: Bool
    let action: () async -> Void

    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            VStack(spacing: 8) {
                Text(level.emoji)
                    .font(.system(size: 40))
                Text(level.label)
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
