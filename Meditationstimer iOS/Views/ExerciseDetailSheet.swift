//
//  ExerciseDetailSheet.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 06.11.25.
//

import SwiftUI

/// Sheet displaying detailed exercise information including instructions and effects
struct ExerciseDetailSheet: View {
    let exerciseName: String
    var exerciseId: String? = nil  // nil → derived from the name (Spec #48, Entscheidung 4)
    @Environment(\.dismiss) private var dismiss

    private var exerciseInfo: ExerciseInfo? {
        let id = resolvedId
        print("[ExerciseDetailSheet] Looking up: '\(exerciseName)' as \(id)")
        let result = id.hasPrefix("claude.") ? ClaudeStore.storedExercise(id: id) : ExerciseDatabase.info(forId: id)
        print("[ExerciseDetailSheet] Found: \(result != nil)")
        return result
    }

    private var resolvedId: String { exerciseId ?? ExerciseDatabase.exerciseId(forName: exerciseName) }
    private var claudeOrigin: ClaudeOrigin? { ClaudeStore.storedExerciseOrigin(id: resolvedId) }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let info = exerciseInfo {
                        // Category Badge
                        HStack {
                            Text(info.category.emoji)
                                .font(.title2)
                            Text(info.category.rawValue)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        Divider()

                        // Effect Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Wirkung", systemImage: "heart.circle.fill")
                                .font(.headline)
                                .foregroundColor(.workoutViolet)

                            Text(info.effect)
                                .accessibilityIdentifier("exerciseDetail.effect")
                                .font(.body)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal)

                        Divider()

                        // Instructions Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Anleitung", systemImage: "list.number")
                                .font(.headline)
                                .foregroundColor(.workoutViolet)

                            Text(info.instructions)
                                .accessibilityIdentifier("exerciseDetail.instructions")
                                .font(.body)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal)

                        // Notes Section (if available)
                        if let notes = info.notes, !notes.isEmpty {
                            Divider()

                            VStack(alignment: .leading, spacing: 12) {
                                Label("Hinweise", systemImage: "info.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.workoutViolet)

                                Text(notes)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal)
                        }

                        if let origin = claudeOrigin {
                            Text(String(format: NSLocalizedString("Von Claude geliefert am %@", comment: ""),
                                        origin.deliveredAt.formatted(date: .numeric, time: .omitted)))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                                .accessibilityIdentifier("exerciseDetail.claudeOrigin")
                        }

                        Spacer(minLength: 40)

                    } else {
                        // Fallback if exercise not found in database
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)

                            Text("Übungsinformationen nicht verfügbar")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            Text("Für diese Übung sind noch keine Details hinterlegt.")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(ExerciseDatabase.displayName(exerciseId: exerciseId ?? ExerciseDatabase.exerciseId(forName: exerciseName),
                                                          storedName: exerciseName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

/// #51 S3: Kapsel "von Claude" unter dem Namen in der Listenzeile.
struct ClaudeOriginBadge: View {
    let modifiedAt: Date?
    let identifier: String

    var body: some View {
        Text(ClaudeStore.badgeText(modifiedAt: modifiedAt))
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial, in: Capsule())
            .accessibilityIdentifier(identifier)
    }
}

/// #51 S3: Abschnitt "Von Claude" am Ende der Info-Ansicht (Datum, Paket, Warum).
struct ClaudeOriginSection: View {
    let origin: ClaudeOrigin

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Von Claude").font(.headline).foregroundStyle(.secondary)
            Text(String(format: NSLocalizedString("Geliefert am %@", comment: ""),
                        origin.deliveredAt.formatted(date: .numeric, time: .omitted)))
                .accessibilityIdentifier("claudeOrigin.deliveredAt")
            if let name = origin.packageName {
                Text(String(format: NSLocalizedString("Paket „%@“", comment: ""), name))
                    .accessibilityIdentifier("claudeOrigin.package")
            }
            Text("Warum").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            Text(origin.why).font(.body).accessibilityIdentifier("claudeOrigin.why")
        }
    }
}

#Preview {
    ExerciseDetailSheet(exerciseName: "Burpees")
}

#Preview("Not Found") {
    ExerciseDetailSheet(exerciseName: "Unbekannte Übung")
}
