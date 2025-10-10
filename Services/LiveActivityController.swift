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

    /// Whether there is currently an active Live Activity managed by this controller.
    var isActive: Bool {
        return activity != nil
    }

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
            // Small retry loop for transient visibility/entitlement errors when requesting an Activity.
            var lastError: Error?
            for attempt in 1...2 {
                do {
                    #if DEBUG
                    print("[LiveActivity] start attempt=\(attempt) → title=\(title), phase=\(phase), ends=\(endDate) enabled=\(ActivityAuthorizationInfo().areActivitiesEnabled)")
                    if let stateInfo = UIApplication.shared.value(forKeyPath: "applicationState") {
                        print("[LiveActivity] UIApplication.applicationState=\(stateInfo)")
                    }
                    #endif
                    activity = try Activity.request(
                        attributes: attributes,
                        content: ActivityContent(state: state, staleDate: nil)
                    )
                    lastError = nil
                    break
                } catch {
                    lastError = error
                    #if DEBUG
                    print("[LiveActivity] start attempt=\(attempt) failed: \(error)")
                    #endif
                    // short backoff before retry
                    if attempt < 2 {
                        Thread.sleep(forTimeInterval: 0.12)
                    }
                }
            }
            if let err = lastError {
                #if DEBUG
                print("[LiveActivity] start ultimately failed: \(err)")
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
            // Avoid double-ending
            guard let currentActivity = activity else {
                #if DEBUG
                print("[LiveActivity] end called but no active activity (ignored)")
                #endif
                return
            }

            #if DEBUG
            print("[LiveActivity] end(immediate=\(immediate)) called")
            Thread.callStackSymbols.prefix(8).forEach { print("[LiveActivity] stack: \($0)") }
            #endif

            // Use non-deprecated API
            if immediate {
                await currentActivity.end(dismissalPolicy: .immediate)
            } else {
                await currentActivity.end()
            }

            activity = nil
        }
    }
    
    // Watchdog removed — automatic auto-stop disabled
}

#else
// Fallback no-op controller for non-iOS platforms
final class LiveActivityController: ObservableObject {
    func start(title: String, phase: Int, endDate: Date) {}
    func update(phase: Int, endDate: Date) async {}
    func end(immediate: Bool = true) async {}
}
#endif
