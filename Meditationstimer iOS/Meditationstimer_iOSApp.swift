//
//  Meditationstimer_iOSApp.swift
//  Meditationstimer iOS
//
//  Created by Henning Emmrich on 01.09.25.
//

import SwiftUI
import HealthKit
import BackgroundTasks
// Dynamic Island / Live Activity removed

@main
struct Meditationstimer_iOSApp: App {
    let receiver = PhoneMindfulnessReceiver()
    @Environment(\.scenePhase) private var scenePhase
    
    // Shared Live Activity Controller for all tabs
    @StateObject private var sharedLiveActivity = LiveActivityController()
    @StateObject private var streakManager = StreakManager()
    
    init() {
        #if os(iOS)
        registerBackgroundTasks()
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sharedLiveActivity)
        }
        // Live Activity background cleanup removed
    }
    
    #if os(iOS)
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.henemm.smartreminders.check",
            using: nil
        ) { task in
            SmartReminderEngine.shared.handleReminderCheck(task: task as! BGAppRefreshTask)
        }
    }
    #endif
}

// MARK: - Live Activity cleanup
// Live Activity cleanup removed
