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
    private var watchdogTimer: Timer?
    private let watchdogInterval: TimeInterval = 30.0 // 30 Sekunden ohne Update = Auto-Stop
    private var lastUpdateTime: Date = Date()

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
                startWatchdog()
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
            print("[LiveActivity] update → phase=\(phase), ends=\(endDate), onMain=\(Thread.isMainThread)")
            #endif
            await activity?.update(ActivityContent(state: state, staleDate: nil))
            // Update Watchdog
            lastUpdateTime = Date()
        }
    }

    func end(immediate: Bool = true) async {
        guard !isPreview else { activity = nil; return }
        if #available(iOS 16.1, *) {
            #if DEBUG
            print("[LiveActivity] end(immediate=\(immediate)) called onMain=\(Thread.isMainThread)")
            // Print simple stack for debugging who called end()
            Thread.callStackSymbols.prefix(8).forEach { print("[LiveActivity] stack: \($0)") }
            #endif
            if immediate {
                await activity?.end(dismissalPolicy: .immediate)
            } else {
                await activity?.end()
            }
            activity = nil
            stopWatchdog()
        }
    }
    
    // MARK: - Watchdog für App Termination Detection
    
    private func startWatchdog() {
        stopWatchdog() // Alten Timer stoppen falls vorhanden
        lastUpdateTime = Date()
        
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkWatchdog()
            }
        }
        
        #if DEBUG
        print("[LiveActivity] Watchdog started - Auto-Stop nach \(watchdogInterval)s ohne Update")
        #endif
    }
    
    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
        
        #if DEBUG
        print("[LiveActivity] Watchdog stopped")
        #endif
    }
    
    private func checkWatchdog() async {
        let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdateTime)
        
        #if DEBUG
        print("[LiveActivity] Watchdog check: \(timeSinceLastUpdate)s seit letztem Update")
        #endif
        
        if timeSinceLastUpdate > watchdogInterval {
            #if DEBUG
            print("[LiveActivity] Watchdog ausgelöst! Auto-Stop nach \(timeSinceLastUpdate)s")
            #endif
            await end(immediate: true)
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
