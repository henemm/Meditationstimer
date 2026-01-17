//
//  Meditationstimer_iOSApp.swift
//  Meditationstimer iOS
//
//  Created by Henning Emmrich on 01.09.25.
//

import SwiftUI
import SwiftData
import HealthKit
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

    // SwiftData ModelContainer for Custom Trackers
    let modelContainer: ModelContainer

    init() {
        // Detect UI test mode - use in-memory storage to avoid disk conflicts
        var inMemory = false
        #if DEBUG
        if CommandLine.arguments.contains("enable-testing") {
            inMemory = true
        }
        #endif

        do {
            let schema = Schema([Tracker.self, TrackerLog.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sharedLiveActivity)
                .modelContainer(modelContainer)
        }
        // Live Activity background cleanup removed
    }
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

        // Register notification categories for NoAlc direct logging
        registerNotificationCategories()

        return true
    }

    /// Register notification actions for NoAlc reminders
    private func registerNotificationCategories() {
        // NoAlc actions: Steady, Easy, Wild
        let steadyAction = UNNotificationAction(
            identifier: "NOALC_STEADY",
            title: "💧 Steady",
            options: []
        )

        let easyAction = UNNotificationAction(
            identifier: "NOALC_EASY",
            title: "✨ Easy",
            options: []
        )

        let wildAction = UNNotificationAction(
            identifier: "NOALC_WILD",
            title: "💥 Wild",
            options: []
        )

        let noAlcCategory = UNNotificationCategory(
            identifier: "NOALC_LOG_CATEGORY",
            actions: [steadyAction, easyAction, wildAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([noAlcCategory])
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when user taps notification action button
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle NoAlc direct logging
        Task { @MainActor in
            switch response.actionIdentifier {
            case "NOALC_STEADY":
                await logNoAlc(.steady)
            case "NOALC_EASY":
                await logNoAlc(.easy)
            case "NOALC_WILD":
                await logNoAlc(.wild)
            default:
                break
            }
            completionHandler()
        }
    }

    /// Log NoAlc consumption from notification action
    @MainActor
    private func logNoAlc(_ level: NoAlcManager.ConsumptionLevel) async {
        do {
            let noAlc = NoAlcManager.shared
            try await noAlc.requestAuthorization()

            // Use target day (yesterday evening if before 18:00)
            let dateToLog = noAlc.targetDay()
            try await noAlc.logConsumption(level, for: dateToLog)

            print("✅ Logged NoAlc: \(level.label) for \(dateToLog)")
        } catch {
            print("❌ Failed to log NoAlc: \(error.localizedDescription)")
        }
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
