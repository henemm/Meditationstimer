//
//  Meditationstimer_iOSApp.swift
//  Meditationstimer iOS
//
//  Created by Henning Emmrich on 01.09.25.
//

import SwiftUI
import HealthKit
// Dynamic Island / Live Activity removed

@main
struct Meditationstimer_iOSApp: App {
    let receiver = PhoneMindfulnessReceiver()
    @Environment(\.scenePhase) private var scenePhase
    
    // Shared Live Activity Controller for all tabs
    @StateObject private var sharedLiveActivity = LiveActivityController()
    @StateObject private var streakManager = StreakManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sharedLiveActivity)
        }
        // Live Activity background cleanup removed
    }
}

// MARK: - Live Activity cleanup
// Live Activity cleanup removed
