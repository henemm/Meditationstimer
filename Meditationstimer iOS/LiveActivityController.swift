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
    private(set) var ownerId: String?
    /// Optional human-readable title for the current activity (e.g. "Meditation").
    private(set) var ownerTitle: String?

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

    /// Serial queue to ensure Live Activity updates are processed sequentially
    private let updateQueue = DispatchQueue(label: "com.meditationstimer.liveactivity.updates")

    /// Start a Live Activity. Pass an optional `ownerId` to identify the caller.
    /// When another owner already holds the activity, this will end the previous activity and start a new one.
    func start(title: String, phase: Int, endDate: Date, ownerId: String? = nil) {
        guard !isPreview else { 
            print("🔍 [LiveActivity] PREVIEW MODE - start skipped")
            return 
        }
        // Ownership guard: if an activity exists and the owner differs, end it deterministically.
        if let existing = activity, let existingOwner = self.ownerId, existingOwner != ownerId {
            print("🔄 [LiveActivity] CONFLICT: \(ownerId ?? "nil") wants to start, but \(existingOwner) owns current activity. Ending previous...")
            Task { @MainActor in
                await existing.end(dismissalPolicy: .immediate)
            }
            // reset local state — we'll set it again when new request succeeds
            activity = nil
            self.ownerId = nil
        }
        if #available(iOS 16.1, *), ActivityAuthorizationInfo().areActivitiesEnabled {
            let attributes = MeditationAttributes(title: title)
            let state = MeditationAttributes.ContentState(endDate: endDate, phase: phase, ownerId: ownerId, isPaused: false)
            // Small retry loop for transient visibility/entitlement errors when requesting an Activity.
            var lastError: Error?
            for attempt in 1...2 {
                do {
                    print("🚀 [LiveActivity] START attempt \(attempt): owner=\(ownerId ?? "nil"), title='\(title)', phase=\(phase), ends=\(endDate)")
                    activity = try Activity.request(
                        attributes: attributes,
                        content: ActivityContent(state: state, staleDate: nil)
                    )
                    // record successful owner and title
                    self.ownerId = ownerId
                    self.ownerTitle = title
                    lastError = nil
                    print("✅ [LiveActivity] START SUCCESS: owner=\(ownerId ?? "nil") now owns activity")
                    break
                } catch {
                    lastError = error
                    print("❌ [LiveActivity] START attempt \(attempt) FAILED: \(error)")
                    // short backoff before retry
                    if attempt < 2 {
                        Thread.sleep(forTimeInterval: 0.12)
                    }
                }
            }
            if let err = lastError {
                print("💥 [LiveActivity] START ULTIMATE FAILURE: \(err)")
            }
        } else {
            print("🚫 [LiveActivity] CANNOT START: iOS version or activities not enabled")
        }
    }

    /// Request to start a Live Activity. If another owner holds the activity, returns `.conflict`.
    /// The caller (UI) should prompt the user and call `forceStart` if the user confirms.
    func requestStart(title: String, phase: Int, endDate: Date, ownerId: String?) -> StartResult {
        print("📋 [LiveActivity] REQUEST START: owner=\(ownerId ?? "nil"), currentOwner=\(self.ownerId ?? "nil"), hasActivity=\(activity != nil)")
        // If there's an existing active activity owned by someone else, report conflict
        if let existingOwner = self.ownerId, existingOwner != ownerId, activity != nil {
            print("⚠️ [LiveActivity] CONFLICT DETECTED: \(existingOwner) owns activity, \(ownerId ?? "nil") wants to start")
            return .conflict(existingOwnerId: existingOwner, existingTitle: self.ownerTitle ?? "")
        }
        // No conflict — invoke the existing start path asynchronously
        print("✅ [LiveActivity] NO CONFLICT: starting activity for owner=\(ownerId ?? "nil")")
        Task { @MainActor in
            self.start(title: title, phase: phase, endDate: endDate, ownerId: ownerId)
        }
        return .started
    }

    /// Forcefully end any existing activity and start a new one for `ownerId`.
    func forceStart(title: String, phase: Int, endDate: Date, ownerId: String?) {
        Task { @MainActor in
            #if DEBUG
            print("[LiveActivity] forceStart requested by owner=\(ownerId ?? "nil") title=\(title) phase=\(phase)")
            #endif
            if let current = self.activity {
                #if DEBUG
                print("[LiveActivity] forceStart: ending existing activity owner=\(self.ownerId ?? "nil") title=\(self.ownerTitle ?? "")")
                #endif
                await current.end(dismissalPolicy: .immediate)
                self.activity = nil
                self.ownerId = nil
                self.ownerTitle = nil
            }
            self.start(title: title, phase: phase, endDate: endDate, ownerId: ownerId)
        }
    }

    func update(phase: Int, endDate: Date, isPaused: Bool = false) async {
        guard !isPreview else { 
            print("🔍 [LiveActivity] PREVIEW MODE - update skipped")
            return 
        }
        if #available(iOS 16.1, *) {
            // Defensive: only update if we have an active activity
            guard activity != nil else {
                print("⚠️ [LiveActivity] UPDATE called but NO ACTIVE ACTIVITY (ignored)")
                return
            }
            
            // Use serial queue to ensure updates are processed sequentially
            await withCheckedContinuation { continuation in
                updateQueue.async {
                    Task { @MainActor in
                        let state = MeditationAttributes.ContentState(endDate: endDate, phase: phase, ownerId: self.ownerId, isPaused: isPaused)
                        // For background updates, set staleDate to ensure the update is processed
                        // staleDate tells the system when this content becomes stale and needs updating
                        // Use shorter staleDate for Atem phase updates to prevent conflicts
                        let staleDate = Date().addingTimeInterval(5) // 5 seconds from now for Atem phase updates
                        let timestamp = Date().timeIntervalSince1970
                        print("🔄 [LiveActivity] UPDATE: phase=\(phase), ends=\(endDate), paused=\(isPaused), owner=\(self.ownerId ?? "nil"), staleDate=\(staleDate), timestamp=\(String(format: "%.3f", timestamp))")
                        await self.activity?.update(ActivityContent(state: state, staleDate: staleDate))
                        print("✅ [LiveActivity] UPDATE completed for phase=\(phase)")
                        continuation.resume()
                    }
                }
            }
        }
    }

    func end(immediate: Bool = true) async {
        guard !isPreview else { 
            activity = nil
            print("🔍 [LiveActivity] PREVIEW MODE - end skipped, reset local state")
            return 
        }
        if #available(iOS 16.1, *) {
            // Avoid double-ending
            guard let currentActivity = activity else {
                print("⚠️ [LiveActivity] END called but NO ACTIVE ACTIVITY (ignored), owner=\(self.ownerId ?? "nil")")
                return
            }

            print("🛑 [LiveActivity] END(immediate=\(immediate)) called, owner=\(self.ownerId ?? "nil"), title='\(self.ownerTitle ?? "nil")'")
            Thread.callStackSymbols.prefix(8).forEach { print("📍 [LiveActivity] stack: \($0)") }

            // Use non-deprecated API
            if immediate {
                await currentActivity.end(dismissalPolicy: .immediate)
            } else {
                await currentActivity.end()
            }

            // Ensure complete removal by ending all activities for this app
            if #available(iOS 16.1, *) {
                for activity in Activity<MeditationAttributes>.activities {
                    await activity.end(dismissalPolicy: .immediate)
                }
            }

            activity = nil
            ownerId = nil
            ownerTitle = nil
            print("✅ [LiveActivity] END COMPLETE: activity cleaned up")
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
