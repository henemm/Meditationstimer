//
//  Meditationstimer_iOSApp.swift
//  Meditationstimer iOS
//
//  Created by Henning Emmrich on 01.09.25.
//

import SwiftUI
import ActivityKit

extension NSNotification.Name {
    static let appWillTerminate = NSNotification.Name("app.will.terminate")
}

@main
struct Meditationstimer_iOSApp: App {
    let receiver = PhoneMindfulnessReceiver()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) {
            // Wenn App wirklich beendet wird: Alle aktiven Sessions stoppen
            if scenePhase == .inactive {
                // Notification senden an alle aktiven Engines
                NotificationCenter.default.post(name: .appWillTerminate, object: nil)
                
                Task {
                    await endAllLiveActivities()
                }
            }
        }
    }
}

// MARK: - Live Activity cleanup
@MainActor
private func endAllLiveActivities() async {
    #if canImport(ActivityKit)
    // Alle aktiven Meditation Live Activities beenden
    for activity in Activity<MeditationAttributes>.activities {
        await activity.end(dismissalPolicy: ActivityUIDismissalPolicy.immediate)
    }
    #endif
}
