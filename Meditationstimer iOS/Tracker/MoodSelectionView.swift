//
//  MoodSelectionView.swift
//  Meditationstimer iOS
//
//  Created by Claude on 19.12.2025.
//
//  Single-select mood logging view with 9 mood options.
//  The act of selecting a mood IS the mindfulness exercise.
//

import SwiftUI
import SwiftData

#if os(iOS)

struct MoodSelectionView: View {
    let tracker: Tracker
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedMood: Mood?

    private let manager = TrackerManager.shared

    // 9 Mood options in a 3x3 grid
    private let moods: [Mood] = [
        Mood(emoji: "😊", labelDE: "Freudig", labelEN: "Joyful"),
        Mood(emoji: "😌", labelDE: "Entspannt", labelEN: "Relaxed"),
        Mood(emoji: "🤔", labelDE: "Nachdenklich", labelEN: "Thoughtful"),
        Mood(emoji: "😟", labelDE: "Ängstlich", labelEN: "Anxious"),
        Mood(emoji: "😤", labelDE: "Ärgerlich", labelEN: "Irritated"),
        Mood(emoji: "😢", labelDE: "Traurig", labelEN: "Sad"),
        Mood(emoji: "😐", labelDE: "Neutral", labelEN: "Neutral"),
        Mood(emoji: "🥱", labelDE: "Müde", labelEN: "Tired"),
        Mood(emoji: "⚡", labelDE: "Energiegeladen", labelEN: "Energized")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Question
                Text(NSLocalizedString("How are you feeling?", comment: "Mood selection prompt"))
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(.top)

                // 3x3 Mood Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(moods) { mood in
                        MoodButton(
                            mood: mood,
                            isSelected: selectedMood?.id == mood.id,
                            action: { selectedMood = mood }
                        )
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle(NSLocalizedString("Mood", comment: "Mood sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "Cancel button")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Save", comment: "Save button")) {
                        saveMood()
                    }
                    .disabled(selectedMood == nil)
                }
            }
        }
    }

    private func saveMood() {
        guard let mood = selectedMood else { return }

        // Save log with mood as note
        _ = manager.logEntry(
            for: tracker,
            value: 1,
            note: "\(mood.emoji) \(mood.localizedLabel)",
            in: modelContext
        )

        onSave()
        dismiss()
    }
}

// MARK: - Mood Model

struct Mood: Identifiable {
    let id = UUID()
    let emoji: String
    let labelDE: String
    let labelEN: String

    var localizedLabel: String {
        // Use the German label as key for NSLocalizedString
        NSLocalizedString(labelDE, comment: "Mood label")
    }
}

// MARK: - Mood Button

struct MoodButton: View {
    let mood: Mood
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(mood.emoji)
                    .font(.system(size: 44))

                Text(mood.localizedLabel)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Tracker.self, TrackerLog.self, configurations: config)

    let tracker = Tracker(
        name: "Stimmung",
        icon: "😊",
        type: .good,
        trackingMode: .awareness
    )
    container.mainContext.insert(tracker)

    return MoodSelectionView(tracker: tracker, onSave: {})
        .modelContainer(container)
}
#endif

#endif // os(iOS)
