//
//  Meditationstimer_iOSApp.swift
//  Meditationstimer iOS
//
//  Created by Henning Emmrich on 01.09.25.
//

import SwiftUI
// Dynamic Island / Live Activity removed

@main
struct Meditationstimer_iOSApp: App {
    let receiver = PhoneMindfulnessReceiver()
    @Environment(\.scenePhase) private var scenePhase
    // Live Activity removed: endActivityOnBackground flag unused
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Live Activity background cleanup removed
    }
}

// MARK: - Live Activity cleanup
// Live Activity cleanup removed
