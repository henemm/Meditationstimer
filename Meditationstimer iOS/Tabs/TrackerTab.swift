//
//  TrackerTab.swift
//  Meditationstimer iOS
//
//  Created by Claude Code on 15.12.2025.
//
//  Placeholder tab for custom trackers (Phase 2).
//  Will include NoAlc tracking and custom habit trackers.
//  This is part of Phase 1.1 Tab Navigation Refactoring.
//

import SwiftUI

#if os(iOS)

struct TrackerTab: View {
    @EnvironmentObject var streakManager: StreakManager
    @State private var showingNoAlcLog = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // NoAlc Quick Log Section
                    GlassCard {
                        VStack(spacing: 16) {
                            HStack {
                                Text("NoAlc")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                Spacer()
                            }
                            .padding(.horizontal, 4)

                            Button(action: { showingNoAlcLog = true }) {
                                HStack {
                                    Image(systemName: "drop.fill")
                                        .font(.system(size: 24))
                                    Text(NSLocalizedString("Log Today", comment: "NoAlc log button"))
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)

                    // Coming Soon Placeholder
                    ContentUnavailableView(
                        NSLocalizedString("More Trackers", comment: "Tracker tab placeholder title"),
                        systemImage: "chart.bar.fill",
                        description: Text(NSLocalizedString("Custom trackers coming in Phase 2", comment: "Tracker tab placeholder"))
                    )
                    .padding(.top, 40)
                }
                .padding(.bottom, 100)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingNoAlcLog) {
                NoAlcLogSheet()
            }
        }
    }
}

#if DEBUG
#Preview {
    TrackerTab()
        .environmentObject(StreakManager())
}
#endif

#endif // os(iOS)
