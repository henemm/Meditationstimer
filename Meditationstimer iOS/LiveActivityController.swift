//
//  LiveActivityController.swift
//  Meditationstimer
//
//  Centralized wrapper for ActivityKit used by all tabs (Offen, Atem, Workouts).
//  Provides start/update/end with robust guards for availability and previews.
//

import Foundation

#if os(iOS)
import ActivityKit
import SwiftUI

@MainActor
final class LiveActivityController: ObservableObject {
    private var activity: Activity<MeditationAttributes>?

    private var isPreview: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        #else
        return false
        #endif
    }

    func start(title: String, phase: Int, endDate: Date) {
        guard !isPreview else { return }
        if #available(iOS 16.1, *), ActivityAuthorizationInfo().areActivitiesEnabled {
            let attributes = MeditationAttributes(title: title)
            let state = MeditationAttributes.ContentState(endDate: endDate, phase: phase)
            do {
                #if DEBUG
                print("[LiveActivity] start → title=\(title), phase=\(phase), ends=\(endDate) enabled=\(ActivityAuthorizationInfo().areActivitiesEnabled)")
                #endif
                activity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: nil)
                )
                #if DEBUG
                print("[LiveActivity] Activity created successfully: \(activity?.id ?? "nil")")
                #endif
            } catch {
                #if DEBUG
                print("[LiveActivity] start failed: \(error)")
                #endif
            }
        } else {
            #if DEBUG
            if #available(iOS 16.1, *) {
                print("[LiveActivity] cannot start: activitiesEnabled=\(ActivityAuthorizationInfo().areActivitiesEnabled)")
            } else {
                print("[LiveActivity] cannot start: iOS < 16.1")
            }
            #endif
        }
    }

    func update(phase: Int, endDate: Date) async {
        guard !isPreview else { return }
        if #available(iOS 16.1, *) {
            let state = MeditationAttributes.ContentState(endDate: endDate, phase: phase)
            #if DEBUG
            print("[LiveActivity] update → phase=\(phase), ends=\(endDate)")
            #endif
            await activity?.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end(immediate: Bool = true) async {
        guard !isPreview else { activity = nil; return }
        if #available(iOS 16.1, *) {
            #if DEBUG
            print("[LiveActivity] end(immediate=\(immediate))")
            #endif
            if immediate {
                await activity?.end(dismissalPolicy: .immediate)
            } else {
                await activity?.end()
            }
            activity = nil
        }
    }
}

#else
// Fallback no-op controller for non-iOS platforms
final class LiveActivityController: ObservableObject {
    func start(title: String, phase: Int, endDate: Date) {}
    func update(phase: Int, endDate: Date) async {}
    func end(immediate: Bool = true) async {}
}
#endif