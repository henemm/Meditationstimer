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
    @State private var showSuccess = false
    @State private var errorMessage: String?

    private let noAlc = NoAlcManager.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                    Text(titleText)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // Quick Log Buttons (Always visible)
                VStack(spacing: 16) {
                    Text("How was it?")
                        .font(.headline)

                    HStack(spacing: 12) {
                        ConsumptionButton(
                            level: .steady,
                            isLogging: isLogging,
                            action: { await logConsumption(.steady) }
                        )

                        ConsumptionButton(
                            level: .easy,
                            isLogging: isLogging,
                            action: { await logConsumption(.easy) }
                        )

                        ConsumptionButton(
                            level: .wild,
                            isLogging: isLogging,
                            action: { await logConsumption(.wild) }
                        )
                    }
                }
                .padding(.horizontal)

                // Expandable Date Picker
                VStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                            Text(isExpanded ? "Hide Date Picker" : "📅 Other Date")
                            Spacer()
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                    .foregroundColor(.primary)

                    if isExpanded {
                        DatePicker(
                            "Select Date",
                            selection: $selectedDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Success/Error Messages
                if showSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Logged successfully!")
                    }
                    .padding()
                    .background(.green.opacity(0.1))
                    .cornerRadius(8)
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding()
                }
            }
            .navigationTitle("Log Drinks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
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
    private func logConsumption(_ level: NoAlcManager.ConsumptionLevel) async {
        isLogging = true
        errorMessage = nil
        showSuccess = false

        do {
            // Request authorization if needed
            try await noAlc.requestAuthorization()

            // Use selected date if expanded, otherwise use target day
            let dateToLog = isExpanded ? selectedDate : noAlc.targetDay()

            // Log consumption
            try await noAlc.logConsumption(level, for: dateToLog)

            // Show success
            showSuccess = true

            // Dismiss after short delay
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            dismiss()
        } catch {
            errorMessage = "Failed to log: \(error.localizedDescription)"
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
            .background(backgroundColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 2)
            )
        }
        .disabled(isLogging)
        .scaleEffect(isLogging ? 0.95 : 1.0)
        .animation(.spring(response: 0.3), value: isLogging)
    }

    private var backgroundColor: Color {
        switch level {
        case .steady:
            return Color(hex: "#00C853").opacity(0.1)
        case .easy:
            return Color(hex: "#A5D6A7").opacity(0.1)
        case .wild:
            return Color(hex: "#E8F5E9").opacity(0.1)
        }
    }

    private var borderColor: Color {
        switch level {
        case .steady:
            return Color(hex: "#00C853")
        case .easy:
            return Color(hex: "#A5D6A7")
        case .wild:
            return Color(hex: "#E8F5E9")
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    NoAlcLogSheet()
}
