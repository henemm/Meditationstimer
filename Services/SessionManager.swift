//
//  SessionManager.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 28.09.25.
//

// MARK: - AI ORIENTATION (Read me first)
// Purpose:
//   SessionManager handles Live Activity (Dynamic Island) integration for ongoing meditations.
//   Provides centralized management of ActivityKit operations with proper lifecycle handling.
//   Used primarily by OffenView for two-phase meditation progress display.
//
// Live Activity Strategy:
//   • Creates activity with MeditationAttributes on session start
//   • Updates activity content when transitioning between phases
//   • Ends activity immediately on completion or cancellation
//   • Respects user's Live Activity authorization settings
//
// Integration Points:
//   • OffenView: Primary consumer for two-phase meditation display
//   • MeditationAttributes: Defines the data structure for Dynamic Island
//   • TwoPhaseTimerEngine: Provides timing data for activity updates
//
// Data Flow:
//   1. requestLiveActivity() → creates initial activity with Phase 1 end time
//   2. updateLiveActivity() → switches to Phase 2 with new end time
//   3. endLiveActivityImmediate() → cleanup on completion/cancellation
//
// Error Handling:
//   • Checks ActivityAuthorizationInfo().areActivitiesEnabled before operations
//   • Silent failure for Live Activity errors (doesn't interrupt meditation)
//   • Automatic cleanup prevents orphaned activities
//
// Technical Notes:
//   • Uses async/await for activity updates (required by ActivityKit)
//   • Maintains reference to current activity for updates/cleanup
//   • Preview detection prevents Live Activities in SwiftUI canvas

import SwiftUI
import AVFoundation
import UIKit
import ActivityKit

class SessionManager: ObservableObject {
    // MARK: - Live Activity (Dynamic Island)

    @Published var currentActivity: Activity<MeditationAttributes>?

    /// Create a Live Activity for Phase 1 (or any phase) with an expected end date.
    func requestLiveActivity(phase: Int, endDate: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = MeditationAttributes(title: "Meditation")
        let state = MeditationAttributes.ContentState(endDate: endDate, phase: phase)
        do {
            currentActivity = try Activity<MeditationAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("Live Activity request failed: \(error)")
        }
    }

    /// Update the currently running Live Activity (e.g. when moving to phase 2).
    func updateLiveActivity(phase: Int, endDate: Date) async {
        let state = MeditationAttributes.ContentState(endDate: endDate, phase: phase)
        await currentActivity?.update(ActivityContent(state: state, staleDate: nil))
    }

    /// End the Live Activity immediately (e.g. at natural end or cancel).
    func endLiveActivityImmediate() async {
        await currentActivity?.end(dismissalPolicy: .immediate)
        currentActivity = nil
    }

    // MARK: - Preview / Environment helpers

    /// Returns true when running in SwiftUI canvas previews.
    var isPreview: Bool {
    #if DEBUG
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    #else
        return false
    #endif
    }
}
