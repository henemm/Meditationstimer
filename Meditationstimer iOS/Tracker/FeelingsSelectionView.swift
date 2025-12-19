//
//  FeelingsSelectionView.swift
//  Meditationstimer iOS
//
//  Created by Claude on 19.12.2025.
//
//  Multi-select feelings logging view with 8 emotion options.
//  The act of identifying and naming feelings IS the mindfulness exercise.
//

import SwiftUI
import SwiftData

#if os(iOS)

struct FeelingsSelectionView: View {
    let tracker: Tracker
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedFeelings: Set<UUID> = []

    private let manager = TrackerManager.shared

    // 8 Feeling options
    private let feelings: [Feeling] = [
        Feeling(emoji: "❤️", labelDE: "Liebe", labelEN: "Love"),
        Feeling(emoji: "😊", labelDE: "Freude", labelEN: "Joy"),
        Feeling(emoji: "🙏", labelDE: "Dankbarkeit", labelEN: "Gratitude"),
        Feeling(emoji: "😰", labelDE: "Angst", labelEN: "Fear"),
        Feeling(emoji: "😤", labelDE: "Ärger", labelEN: "Anger"),
        Feeling(emoji: "😢", labelDE: "Trauer", labelEN: "Sadness"),
        Feeling(emoji: "😔", labelDE: "Enttäuschung", labelEN: "Disappointment"),
        Feeling(emoji: "🤗", labelDE: "Verbundenheit", labelEN: "Connection")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Question
                Text(NSLocalizedString("What feelings do you notice?", comment: "Feelings selection prompt"))
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(.top)

                // Selection count hint
                if !selectedFeelings.isEmpty {
                    Text(String(format: NSLocalizedString("%d selected", comment: "Selection count"), selectedFeelings.count))
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }

                // Feelings Grid (2x4)
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(feelings) { feeling in
                        FeelingButton(
                            feeling: feeling,
                            isSelected: selectedFeelings.contains(feeling.id),
                            action: { toggleFeeling(feeling) }
                        )
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle(NSLocalizedString("Feelings", comment: "Feelings sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "Cancel button")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Save", comment: "Save button")) {
                        saveFeelings()
                    }
                    .disabled(selectedFeelings.isEmpty)
                }
            }
        }
    }

    private func toggleFeeling(_ feeling: Feeling) {
        if selectedFeelings.contains(feeling.id) {
            selectedFeelings.remove(feeling.id)
        } else {
            selectedFeelings.insert(feeling.id)
        }
    }

    private func saveFeelings() {
        guard !selectedFeelings.isEmpty else { return }

        // Build note from selected feelings
        let selectedLabels = feelings
            .filter { selectedFeelings.contains($0.id) }
            .map { "\($0.emoji) \($0.localizedLabel)" }
            .joined(separator: ", ")

        // Save log with feelings as note
        _ = manager.logEntry(
            for: tracker,
            value: selectedFeelings.count,
            note: selectedLabels,
            in: modelContext
        )

        onSave()
        dismiss()
    }
}

// MARK: - Feeling Model

struct Feeling: Identifiable {
    let id = UUID()
    let emoji: String
    let labelDE: String
    let labelEN: String

    var localizedLabel: String {
        NSLocalizedString(labelDE, comment: "Feeling label")
    }
}

// MARK: - Feeling Button

struct FeelingButton: View {
    let feeling: Feeling
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(feeling.emoji)
                    .font(.system(size: 28))

                Text(feeling.localizedLabel)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color(.systemGray6))
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
        name: "Gefühle",
        icon: "💭",
        type: .good,
        trackingMode: .awareness
    )
    container.mainContext.insert(tracker)

    return FeelingsSelectionView(tracker: tracker, onSave: {})
        .modelContainer(container)
}
#endif

#endif // os(iOS)
