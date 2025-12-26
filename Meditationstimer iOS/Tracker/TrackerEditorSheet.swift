//
//  TrackerEditorSheet.swift
//  Meditationstimer iOS
//
//  Created by Claude on 19.12.2025.
//
//  Sheet for editing tracker properties and deleting trackers.
//

import SwiftUI
import SwiftData

#if os(iOS)

struct TrackerEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var tracker: Tracker

    @State private var showDeleteConfirmation = false

    // Emoji choices for icon selection
    private let emojiChoices = [
        "😊", "💭", "🙏", "💧", "📱", "🍫", "🛋️", "🌀", "📵",
        "✨", "🔥", "💪", "🌿", "🧘", "☕", "🍎", "📚", "🎯",
        "💤", "🚶", "🏃", "🧠", "❤️", "🌟"
    ]

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
                        NSLocalizedString("Name", comment: "Tracker name field"),
                        text: $tracker.name
                    )
                } header: {
                    Text(NSLocalizedString("Name", comment: "Name section header"))
                }

                // Daily Goal Section (only for counter mode)
                if tracker.trackingMode == .counter {
                    Section {
                        Stepper(value: Binding(
                            get: { tracker.dailyGoal ?? 0 },
                            set: { tracker.dailyGoal = $0 > 0 ? $0 : nil }
                        ), in: 0...100) {
                            HStack {
                                Text(NSLocalizedString("Daily Goal", comment: "Daily goal label"))
                                Spacer()
                                Text("\(tracker.dailyGoal ?? 0)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("Goal", comment: "Goal section header"))
                    } footer: {
                        Text(NSLocalizedString("Set to 0 to disable goal tracking.", comment: "Goal footer"))
                    }
                }

                // Info Section (read-only)
                Section {
                    HStack {
                        Text(NSLocalizedString("Type", comment: "Tracker type label"))
                        Spacer()
                        Text(typeLabel)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(NSLocalizedString("Mode", comment: "Tracking mode label"))
                        Spacer()
                        Text(modeLabel)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(NSLocalizedString("Created", comment: "Creation date label"))
                        Spacer()
                        Text(tracker.createdAt, style: .date)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(NSLocalizedString("Total Logs", comment: "Total logs label"))
                        Spacer()
                        Text("\(tracker.logs.count)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(NSLocalizedString("Info", comment: "Info section header"))
                }

                // Delete Section
                Section {
                    Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                        HStack {
                            Image(systemName: "trash")
                            Text(NSLocalizedString("Delete Tracker", comment: "Delete button"))
                        }
                    }
                } footer: {
                    Text(NSLocalizedString("This will permanently delete the tracker and all its logs.", comment: "Delete warning"))
                }
            }
            .navigationTitle(NSLocalizedString("Edit Tracker", comment: "Edit sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Done", comment: "Done button")) {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                NSLocalizedString("Delete Tracker?", comment: "Delete confirmation title"),
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("Delete", comment: "Delete action"), role: .destructive) {
                    deleteTracker()
                }
                Button(NSLocalizedString("Cancel", comment: "Cancel action"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("This action cannot be undone. All logs will be deleted.", comment: "Delete confirmation message"))
            }
        }
    }

    // MARK: - Icon Selection Grid

    private var iconSelectionGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
            ForEach(emojiChoices, id: \.self) { emoji in
                Button {
                    tracker.icon = emoji
                } label: {
                    Text(emoji)
                        .font(.system(size: 28))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(tracker.icon == emoji ? Color.blue.opacity(0.2) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(tracker.icon == emoji ? Color.blue : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helper Labels

    private var typeLabel: String {
        switch tracker.type {
        case .good:
            return NSLocalizedString("Good Habit", comment: "Good tracker type")
        case .saboteur:
            return NSLocalizedString("Saboteur", comment: "Saboteur tracker type")
        }
    }

    private var modeLabel: String {
        switch tracker.trackingMode {
        case .counter:
            return NSLocalizedString("Counter", comment: "Counter mode")
        case .yesNo:
            return NSLocalizedString("Daily Check", comment: "YesNo mode")
        case .awareness:
            return NSLocalizedString("Awareness", comment: "Awareness mode")
        case .avoidance:
            return NSLocalizedString("Avoidance", comment: "Avoidance mode")
        case .levels:
            return NSLocalizedString("Levels", comment: "Levels mode")
        }
    }

    // MARK: - Actions

    private func deleteTracker() {
        TrackerManager.shared.deleteTracker(tracker, from: modelContext)
        dismiss()
    }
}

#if DEBUG
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Tracker.self, TrackerLog.self, configurations: config)

    let tracker = Tracker(
        name: "Water",
        icon: "💧",
        type: .good,
        trackingMode: .counter,
        dailyGoal: 8
    )
    container.mainContext.insert(tracker)

    return TrackerEditorSheet(tracker: tracker)
        .modelContainer(container)
}
#endif

#endif // os(iOS)
