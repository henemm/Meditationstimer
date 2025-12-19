//
//  CustomTrackerSheet.swift
//  Meditationstimer iOS
//
//  Created by Claude on 19.12.2025.
//
//  Sheet for creating a custom tracker with user-defined settings.
//

import SwiftUI
import SwiftData

#if os(iOS)

struct CustomTrackerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Form state
    @State private var icon = "✨"
    @State private var name = ""
    @State private var trackerType: TrackerType = .good
    @State private var trackingMode: TrackingMode = .counter
    @State private var dailyGoal: Int = 0

    // Emoji choices for icon selection
    private let emojiChoices = [
        "😊", "💭", "🙏", "💧", "📱", "🍫", "🛋️", "🌀", "📵",
        "✨", "🔥", "💪", "🌿", "🧘", "☕", "🍎", "📚", "🎯",
        "💤", "🚶", "🏃", "🧠", "❤️", "🌟"
    ]

    // Available modes depend on tracker type
    private var availableModes: [TrackingMode] {
        switch trackerType {
        case .good:
            return [.counter, .yesNo]
        case .saboteur:
            return [.awareness, .avoidance]
        }
    }

    // Validation
    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Icon Section
                Section {
                    iconSelectionGrid
                } header: {
                    Text(NSLocalizedString("Icon", comment: "Icon section header"))
                }

                // Name Section
                Section {
                    TextField(
                        NSLocalizedString("Tracker name", comment: "Tracker name placeholder"),
                        text: $name
                    )
                } header: {
                    Text(NSLocalizedString("Name", comment: "Name section header"))
                }

                // Type Section
                Section {
                    Picker(NSLocalizedString("Type", comment: "Tracker type picker"), selection: $trackerType) {
                        Text(NSLocalizedString("Good Habit", comment: "Good tracker type"))
                            .tag(TrackerType.good)
                        Text(NSLocalizedString("Saboteur", comment: "Saboteur tracker type"))
                            .tag(TrackerType.saboteur)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text(NSLocalizedString("Type", comment: "Type section header"))
                } footer: {
                    Text(typeFooter)
                }

                // Mode Section
                Section {
                    Picker(NSLocalizedString("Mode", comment: "Tracking mode picker"), selection: $trackingMode) {
                        ForEach(availableModes, id: \.self) { mode in
                            Text(modeLabel(for: mode))
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text(NSLocalizedString("Mode", comment: "Mode section header"))
                } footer: {
                    Text(modeFooter)
                }

                // Daily Goal Section (only for counter mode)
                if trackingMode == .counter {
                    Section {
                        Stepper(value: $dailyGoal, in: 0...100) {
                            HStack {
                                Text(NSLocalizedString("Daily Goal", comment: "Daily goal label"))
                                Spacer()
                                Text("\(dailyGoal)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("Goal", comment: "Goal section header"))
                    } footer: {
                        Text(NSLocalizedString("Set to 0 to disable goal tracking.", comment: "Goal footer"))
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Custom Tracker", comment: "Custom tracker sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "Cancel button")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Create", comment: "Create button")) {
                        createTracker()
                    }
                    .disabled(!canCreate)
                }
            }
            .onChange(of: trackerType) { _, newType in
                // Reset mode to first available when type changes
                trackingMode = availableModes.first ?? .counter
            }
        }
    }

    // MARK: - Icon Selection Grid

    private var iconSelectionGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
            ForEach(emojiChoices, id: \.self) { emoji in
                Button {
                    icon = emoji
                } label: {
                    Text(emoji)
                        .font(.system(size: 28))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(icon == emoji ? Color.blue.opacity(0.2) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(icon == emoji ? Color.blue : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helper Labels

    private var typeFooter: String {
        switch trackerType {
        case .good:
            return NSLocalizedString("Track positive habits you want to build.", comment: "Good type explanation")
        case .saboteur:
            return NSLocalizedString("Track behaviors you want to become aware of or avoid.", comment: "Saboteur type explanation")
        }
    }

    private func modeLabel(for mode: TrackingMode) -> String {
        switch mode {
        case .counter:
            return NSLocalizedString("Counter", comment: "Counter mode")
        case .yesNo:
            return NSLocalizedString("Daily Check", comment: "YesNo mode")
        case .awareness:
            return NSLocalizedString("Awareness", comment: "Awareness mode")
        case .avoidance:
            return NSLocalizedString("Avoidance", comment: "Avoidance mode")
        }
    }

    private var modeFooter: String {
        switch trackingMode {
        case .counter:
            return NSLocalizedString("Count how many times per day (e.g., glasses of water).", comment: "Counter mode explanation")
        case .yesNo:
            return NSLocalizedString("Simple daily yes/no check.", comment: "YesNo mode explanation")
        case .awareness:
            return NSLocalizedString("Log each occurrence to build awareness.", comment: "Awareness mode explanation")
        case .avoidance:
            return NSLocalizedString("Track days without the behavior (streak).", comment: "Avoidance mode explanation")
        }
    }

    // MARK: - Actions

    private func createTracker() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        let tracker = Tracker(
            name: trimmedName,
            icon: icon,
            type: trackerType,
            trackingMode: trackingMode,
            dailyGoal: trackingMode == .counter && dailyGoal > 0 ? dailyGoal : nil
        )

        TrackerManager.shared.createTracker(tracker, in: modelContext)
        dismiss()
    }
}

#if DEBUG
#Preview {
    CustomTrackerSheet()
        .modelContainer(for: [Tracker.self, TrackerLog.self], inMemory: true)
}
#endif

#endif // os(iOS)
