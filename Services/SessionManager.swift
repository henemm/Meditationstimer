//
//  SessionManager.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 28.09.25.
//

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
