//
//  Meditationstimer_iOSApp.swift
//  Meditationstimer iOS
//
//  Created by Henning Emmrich on 01.09.25.
//

import SwiftUI
import HealthKit
import BackgroundTasks
import UserNotifications
// Dynamic Island / Live Activity removed

@main
struct Meditationstimer_iOSApp: App {
    let receiver = PhoneMindfulnessReceiver()
    @Environment(\.scenePhase) private var scenePhase

    // Shared Live Activity Controller for all tabs
    @StateObject private var sharedLiveActivity = LiveActivityController()
    @StateObject private var streakManager = StreakManager()

    // Notification delegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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

// MARK: - AppDelegate for Notification Handling

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when user taps notification action button
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification responses here if needed
        completionHandler()
    }

    /// Called when notification arrives while app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }
}
