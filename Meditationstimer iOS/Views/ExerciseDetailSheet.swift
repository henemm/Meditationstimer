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
    @Environment(\.dismiss) private var dismiss

    private var exerciseInfo: ExerciseInfo? {
        ExerciseDatabase.info(for: exerciseName)
    }

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
            .navigationTitle(exerciseName)
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

#Preview {
    ExerciseDetailSheet(exerciseName: "Burpees")
}

#Preview("Not Found") {
    ExerciseDetailSheet(exerciseName: "Unbekannte Übung")
}
