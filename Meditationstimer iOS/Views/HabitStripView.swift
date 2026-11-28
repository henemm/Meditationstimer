//
//  HabitStripView.swift
//  Meditationstimer iOS
//
//  Gewohnheiten-Leiste über dem Kalender (#50): eine Karte je dauerhafter Gewohnheit,
//  Antippen wählt die Karte aus (höchstens eine).
//

import SwiftUI

extension Color {
    /// Kartenfarbe der Gewohnheiten-Leiste: #d6457a hell, #f06d9c dunkel
    static let habitStrip = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0xF0 / 255, green: 0x6D / 255, blue: 0x9C / 255, alpha: 1)
            : UIColor(red: 0xD6 / 255, green: 0x45 / 255, blue: 0x7A / 255, alpha: 1)
    })
}

struct HabitStripView: View {
    let trackers: [Tracker]
    @Binding var selectedID: UUID?

    /// Ungefähre Kartenhöhe für die Begrenzung auf drei Karten
    private let cardHeight: CGFloat = 62
    private let spacing: CGFloat = 8

    var body: some View {
        Group {
            if trackers.count > 3 {
                ScrollView { cards }
                    .frame(height: cardHeight * 3 + spacing * 2)
            } else {
                cards
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("calendar.habitStrip")
    }

    private var cards: some View {
        VStack(spacing: spacing) {
            ForEach(trackers) { tracker in
                HabitCard(tracker: tracker, isSelected: selectedID == tracker.id)
                    .onTapGesture {
                        selectedID = (selectedID == tracker.id) ? nil : tracker.id
                    }
            }
        }
    }
}

private struct HabitCard: View {
    let tracker: Tracker
    let isSelected: Bool

    var body: some View {
        // Einmal je Aufbau der Karte berechnen
        let streak = TrackerManager.shared.calculateStreakResult(for: tracker).currentStreak
        let dots = HabitStrip.dots(entryDays: HabitStrip.entryDays(for: tracker, calendar: .current), calendar: .current)

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(tracker.icon)
                Text(tracker.name).bold()
                Text("dauerhaft")
                    .font(.caption2)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(HabitStrip.streakText(streak))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(dots.indices, id: \.self) { index in
                    dot(dots[index])
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.habitStrip : Color(.separator), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("calendar.habit.card")
        .accessibilityLabel(tracker.name)
        .accessibilityValue(isSelected ? Text("ausgewählt") : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private func dot(_ state: HabitStrip.DotState) -> some View {
        switch state {
        case .filled:
            Circle().fill(Color.habitStrip).frame(width: 10, height: 10)
        case .open:
            Circle().stroke(Color.gray, lineWidth: 1).frame(width: 10, height: 10)
        case .todayOpen:
            Circle().stroke(Color.habitStrip, lineWidth: 2).frame(width: 10, height: 10)
        }
    }
}
