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
    /// Optional owner identifier for the current activity (e.g. "OffenTab", "AtemTab").
    /// If set, the controller will prefer to keep ownership and will log/handle attempts
    /// from a different owner deterministically (end+start).
    private var ownerId: String?
    private var ownerTitle: String?

    // Read-only accessors for debug/logging from other files.
    // Kept separate from the internal storage so we can preserve encapsulation.
    var publicOwnerId: String? { ownerId }
    var publicOwnerTitle: String? { ownerTitle }

    /// Whether there is currently an active Live Activity managed by this controller.
    var isActive: Bool {
        return activity != nil
    }

    enum StartResult {
        case started
        case conflict(existingOwnerId: String, existingTitle: String)
        case failed(Error)
    }

    private var isPreview: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        #else
        return false
        #endif
    }

    func requestStart(title: String, phase: Int, endDate: Date, ownerId: String?) -> StartResult {
        #if DEBUG
        print("[LiveActivity iOS] requestStart owner=\(ownerId ?? "nil") currentOwner=\(self.ownerId ?? "nil") isActive=\(activity != nil)")
        #endif
        if let existingOwner = self.ownerId, existingOwner != ownerId, activity != nil {
            return .conflict(existingOwnerId: existingOwner, existingTitle: self.ownerTitle ?? "")
        }
        Task { @MainActor in
            self.start(title: title, phase: phase, endDate: endDate, ownerId: ownerId)
        }
        return .started
    }

    func forceStart(title: String, phase: Int, endDate: Date, ownerId: String?) {
        Task { @MainActor in
            #if DEBUG
            print("[LiveActivity iOS] forceStart owner=\(ownerId ?? "nil") title=\(title) phase=\(phase)")
            #endif
            if let current = self.activity {
                #if DEBUG
                print("[LiveActivity iOS] forceStart: ending existing owner=\(self.ownerId ?? "nil") title=\(self.ownerTitle ?? "")")
                #endif
                await current.end(dismissalPolicy: .immediate)
                self.activity = nil
                self.ownerId = nil
                self.ownerTitle = nil
            }
            self.start(title: title, phase: phase, endDate: endDate, ownerId: ownerId)
        }
    }

    /// Start a Live Activity. Pass an optional `ownerId` to identify the caller.
    /// When another owner already holds the activity, this will end the previous activity and start a new one.
    func start(title: String, phase: Int, endDate: Date, ownerId: String? = nil) {
        guard !isPreview else { return }
        // Ownership guard: if an activity exists and the owner differs, end it deterministically.
        if let existing = activity, let existingOwner = self.ownerId, existingOwner != ownerId {
            #if DEBUG
            print("[LiveActivity] start requested by owner=\(ownerId ?? "nil") but existing owner=\(existingOwner). Ending previous activity and continuing.")
            #endif
            Task { @MainActor in
                await existing.end(dismissalPolicy: .immediate)
            }
            // reset local state — we'll set it again when new request succeeds
            activity = nil
            self.ownerId = nil
        }
        if #available(iOS 16.1, *), ActivityAuthorizationInfo().areActivitiesEnabled {
            let attributes = MeditationAttributes(title: title)
            let state = MeditationAttributes.ContentState(endDate: endDate, phase: phase, ownerId: ownerId)
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
                    // record successful owner
                    self.ownerId = ownerId
                    self.ownerTitle = title
                    lastError = nil
                    break
                } catch {
                    lastError = error
                    #if DEBUG
                    print("[LiveActivity] start attempt=\(attempt) failed: \(error)")
                    #endif
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
            // Defensive: only update if we have an active activity
            guard activity != nil else {
                #if DEBUG
                print("[LiveActivity] update called but no active activity (ignored)")
                #endif
                return
            }
            let state = MeditationAttributes.ContentState(endDate: endDate, phase: phase, ownerId: self.ownerId)
            #if DEBUG
            print("[LiveActivity] update → phase=\(phase), ends=\(endDate)")
            #endif
            await activity?.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end(immediate: Bool = true) async {
        guard !isPreview else { activity = nil; return }
        if #available(iOS 16.1, *) {
            guard let currentActivity = activity else {
                #if DEBUG
                print("[LiveActivity iOS] end called but no active activity (ignored) ownerId=\(self.ownerId ?? "nil") ownerTitle=\(self.ownerTitle ?? "")")
                #endif
                return
            }

            #if DEBUG
            print("[LiveActivity iOS] end(immediate=\(immediate)) called owner=\(self.ownerId ?? "nil") title=\(self.ownerTitle ?? "")")
            Thread.callStackSymbols.prefix(8).forEach { print("[LiveActivity iOS] stack: \($0)") }
            #endif

            if immediate {
                await currentActivity.end(dismissalPolicy: .immediate)
            } else {
                await currentActivity.end()
            }

            activity = nil
            ownerId = nil
            ownerTitle = nil
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