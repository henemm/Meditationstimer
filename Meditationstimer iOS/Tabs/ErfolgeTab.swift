//
//  ErfolgeTab.swift
//  Meditationstimer iOS
//
//  Created by Claude Code on 15.12.2025.
//
//  Achievements tab showing embedded calendar view with streak info.
//  This is part of Phase 1.1 Tab Navigation Refactoring.
//
//  Layout:
//  - Embedded CalendarView (contains streak info section)
//

import SwiftUI

#if os(iOS)

struct ErfolgeTab: View {
    @EnvironmentObject var streakManager: StreakManager

    var body: some View {
        NavigationStack {
            CalendarView(isEmbedded: true)
                .environmentObject(streakManager)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#if DEBUG
#Preview {
    ErfolgeTab()
        .environmentObject(StreakManager())
}
#endif

#endif // os(iOS)
