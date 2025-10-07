//
//  Meditationstimer_iOSApp.swift
//  Meditationstimer iOS
//
//  Created by Henning Emmrich on 01.09.25.
//

import SwiftUI
import ActivityKit

@main
struct Meditationstimer_iOSApp: App {
    let receiver = PhoneMindfulnessReceiver()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("endActivityOnBackground") private var endActivityOnBackground: Bool = false
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { newPhase in
            guard endActivityOnBackground else { return }
            if newPhase == .background || newPhase == .inactive {
                Task { await endAllLiveActivities() }
            }
        }
    }
}

// MARK: - Live Activity cleanup
extension Meditationstimer_iOSApp {
    private func endAllLiveActivities() async {
        guard #available(iOS 16.1, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        for activity in Activity<MeditationAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }
    }
}
