//
//  InfoSheet.swift
//  Lean Health Timer
//
//  Created by Claude on 13.11.2025.
//

import SwiftUI

/// Generic info sheet component that displays explanatory content
/// Reusable across all info buttons in the app
struct InfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let usageTips: [LocalizedStringKey]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title only (no icon)
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    // Description
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    // Usage Tips
                    if !usageTips.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How it works:")
                                .font(.headline)

                            ForEach(usageTips.indices, id: \.self) { index in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "\(index + 1).circle.fill")
                                        .foregroundStyle(.blue)
                                    Text(usageTips[index])
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    InfoSheet(
        title: "Offene Meditation",
        description: "Die offene Meditation bietet dir einen flexiblen Timer mit zwei Phasen: Meditation und Besinnung. Du bestimmst die Dauer und kannst dich voll auf deine Praxis konzentrieren.",
        usageTips: [
            "Wähle die Dauer für beide Phasen",
            "Phase 1: Meditation (mit Gong-Start)",
            "Phase 2: Besinnung/Reflexion (mit Gong-Übergang)",
            "Gong-Ende signalisiert das Sitzungsende",
            "Aktivität wird automatisch in Apple Health geloggt"
        ]
    )
}
