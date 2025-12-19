//
//  GratitudeLogView.swift
//  Meditationstimer iOS
//
//  Created by Claude on 19.12.2025.
//
//  Free text gratitude logging view.
//  The act of writing what you're grateful for IS the mindfulness exercise.
//

import SwiftUI
import SwiftData

#if os(iOS)

struct GratitudeLogView: View {
    let tracker: Tracker
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var gratitudeText = ""
    @FocusState private var isTextFieldFocused: Bool

    private let manager = TrackerManager.shared

    private var canSave: Bool {
        !gratitudeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Question
                Text(NSLocalizedString("What are you grateful for?", comment: "Gratitude prompt"))
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(.top)

                // Text Editor
                TextEditor(text: $gratitudeText)
                    .focused($isTextFieldFocused)
                    .frame(minHeight: 150)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        // Placeholder
                        Group {
                            if gratitudeText.isEmpty {
                                Text(NSLocalizedString("I'm grateful for...", comment: "Gratitude placeholder"))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 20)
                                    .allowsHitTesting(false)
                            }
                        },
                        alignment: .topLeading
                    )
                    .padding(.horizontal)

                Spacer()
            }
            .navigationTitle(NSLocalizedString("Gratitude", comment: "Gratitude sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "Cancel button")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Save", comment: "Save button")) {
                        saveGratitude()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                // Auto-focus the text field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTextFieldFocused = true
                }
            }
        }
    }

    private func saveGratitude() {
        let trimmedText = gratitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        // Save log with gratitude text as note
        _ = manager.logEntry(
            for: tracker,
            value: 1,
            note: trimmedText,
            in: modelContext
        )

        onSave()
        dismiss()
    }
}

#if DEBUG
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Tracker.self, TrackerLog.self, configurations: config)

    let tracker = Tracker(
        name: "Dankbarkeit",
        icon: "🙏",
        type: .good,
        trackingMode: .awareness
    )
    container.mainContext.insert(tracker)

    return GratitudeLogView(tracker: tracker, onSave: {})
        .modelContainer(container)
}
#endif

#endif // os(iOS)
