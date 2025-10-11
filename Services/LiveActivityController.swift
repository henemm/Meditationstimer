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
    /// Optional human-readable title for the current activity (e.g. "Meditation").
    private var ownerTitle: String?

    /// Whether there is currently an active Live Activity managed by this controller.
    var isActive: Bool {
        return activity != nil
    }

    /// Result of a start request which can indicate a conflict with an existing activity.
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

    // Flags to serialize start/end and avoid races where end() is followed immediately by a new start()
    private var isStarting: Bool = false
    private var isEnding: Bool = false

    /// Start a Live Activity. Pass an optional `ownerId` to identify the caller.
    /// When another owner already holds the activity, this will end the previous activity and start a new one.
    func start(title: String, phase: Int, endDate: Date, ownerId: String? = nil) async {
        guard !isPreview else { return }
        if isEnding {
            #if DEBUG
            print("[LiveActivity] start() ignored because isEnding=true (services)")
            #endif
            return
        }
        isStarting = true
        defer { isStarting = false }
        // Ownership guard: if an activity exists and the owner differs, end it deterministically.
        if let existing = activity, let existingOwner = self.ownerId, existingOwner != ownerId {
            #if DEBUG
            print("[LiveActivity] start requested by owner=\(ownerId ?? "nil") but existing owner=\(existingOwner). Ending previous activity and continuing.")
            #endif
            await existing.end(dismissalPolicy: .immediate)
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
                    // record successful owner and title
                    self.ownerId = ownerId
                    self.ownerTitle = title
                    lastError = nil
                    break
                } catch {
                    lastError = error
                    #if DEBUG
                    print("[LiveActivity] start attempt=\(attempt) failed: \(error)")
                    #endif
                    // short backoff before retry
                    if attempt < 2 {
                        try? await Task.sleep(nanoseconds: 120_000_000) // 120ms
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

    /// Request to start a Live Activity. If another owner holds the activity, returns `.conflict`.
    /// The caller (UI) should prompt the user and call `forceStart` if the user confirms.
    func requestStart(title: String, phase: Int, endDate: Date, ownerId: String?) -> StartResult {
        // If there's an existing active activity owned by someone else, report conflict
        #if DEBUG
        print("[LiveActivity] requestStart called by owner=\(ownerId ?? "nil") currentOwner=\(self.ownerId ?? "nil") isActive=\(activity != nil)")
        #endif
        if let existingOwner = self.ownerId, existingOwner != ownerId, activity != nil {
            return .conflict(existingOwnerId: existingOwner, existingTitle: self.ownerTitle ?? "")
        }
        // No conflict — invoke the existing start path asynchronously
        if isEnding {
            #if DEBUG
            print("[LiveActivity] requestStart rejected (services): isEnding=true")
            #endif
            return .failed(NSError(domain: "LiveActivityController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Activity is ending"]))
        }
        Task { @MainActor in
            await self.start(title: title, phase: phase, endDate: endDate, ownerId: ownerId)
        }
        return .started
    }

    /// Forcefully end any existing activity and start a new one for `ownerId`.
    func forceStart(title: String, phase: Int, endDate: Date, ownerId: String?) {
        Task { @MainActor in
            #if DEBUG
            print("[LiveActivity] forceStart requested by owner=\(ownerId ?? "nil") title=\(title) phase=\(phase)")
            #endif
            if isEnding {
                #if DEBUG
                print("[LiveActivity] forceStart deferred (services): isEnding=true")
                #endif
                return
            }
            isStarting = true
            defer { isStarting = false }

            if let current = self.activity {
                #if DEBUG
                print("[LiveActivity] forceStart: ending existing activity owner=\(self.ownerId ?? "nil") title=\(self.ownerTitle ?? "")")
                #endif
                await current.end(dismissalPolicy: .immediate)
                self.activity = nil
                self.ownerId = nil
                self.ownerTitle = nil
            }
            await self.start(title: title, phase: phase, endDate: endDate, ownerId: ownerId)
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
            if isEnding {
                #if DEBUG
                print("[LiveActivity] end called but isEnding already true (services)")
                #endif
                return
            }
            isEnding = true
            defer { isEnding = false }

            while isStarting {
                #if DEBUG
                print("[LiveActivity] end waiting for in-flight start to finish (services)")
                #endif
                try? await Task.sleep(nanoseconds: 50_000_000)
            }

            guard let currentActivity = activity else {
                #if DEBUG
                print("[LiveActivity] end called but no active activity (ignored) ownerId=\(self.ownerId ?? "nil") ownerTitle=\(self.ownerTitle ?? "")")
                #endif
                return
            }

            #if DEBUG
            print("[LiveActivity] end(immediate=\(immediate)) called owner=\(self.ownerId ?? "nil") title=\(self.ownerTitle ?? "")")
            Thread.callStackSymbols.prefix(8).forEach { print("[LiveActivity] stack: \($0)") }
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
