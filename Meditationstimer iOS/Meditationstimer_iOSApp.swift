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

    // Static access for notification action handler (AppDelegate needs SwiftData access)
    static var sharedModelContainer: ModelContainer!

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

        Self.sharedModelContainer = modelContainer
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sharedLiveActivity)
                .environmentObject(streakManager)
                .modelContainer(modelContainer)
                .task {
                    // Generic Tracker System: Create default trackers on first launch
                    await runTrackerMigration()
                }
        }
        // Live Activity background cleanup removed
    }

    /// Runs the Generic Tracker System migration on app launch
    @MainActor
    private func runTrackerMigration() async {
        let context = modelContainer.mainContext
        do {
            try TrackerMigration.shared.createDefaultTrackersIfNeeded(context: context)
        } catch {
            print("[TrackerMigration] Failed: \(error)")
        }
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
        // Handle NoAlc direct logging via TrackerManager (unified logging)
        Task { @MainActor in
            let userInfo = response.notification.request.content.userInfo

            // Check if notification includes specific trackerID (Generic Tracker SmartReminder)
            if let trackerIDString = userInfo["trackerID"] as? String,
               let trackerID = UUID(uuidString: trackerIDString) {
                // Log to specific tracker (includes HealthKit via TrackerManager.logEntry)
                await logTrackerFromNotification(trackerID: trackerID, actionIdentifier: response.actionIdentifier)
            } else if let levelId = TrackerManager.levelIdForNotificationAction(response.actionIdentifier) {
                // Fallback: Legacy NoAlc notification without trackerID
                // Find NoAlc tracker by HealthKit type
                await logNoAlc(levelId: levelId)
            }

            completionHandler()
        }
    }

    /// Log to Generic Tracker (SwiftData) from notification action
    @MainActor
    private func logTrackerFromNotification(trackerID: UUID, actionIdentifier: String) async {
        // Map notification action → level ID (centralized in TrackerManager)
        guard let levelId = TrackerManager.levelIdForNotificationAction(actionIdentifier) else { return }

        guard let container = Meditationstimer_iOSApp.sharedModelContainer else { return }
        let context = container.mainContext

        let descriptor = FetchDescriptor<Tracker>(predicate: #Predicate { $0.id == trackerID })
        guard let tracker = try? context.fetch(descriptor).first else { return }

        let _ = TrackerManager.shared.logEntry(for: tracker, value: levelId, in: context)
        try? context.save()

        print("✅ Dual-logged Generic Tracker: level \(levelId) for tracker \(tracker.name)")
    }

    /// Log NoAlc consumption from notification action via TrackerManager
    @MainActor
    private func logNoAlc(levelId: Int) async {
        guard let container = Meditationstimer_iOSApp.sharedModelContainer else {
            print("❌ Failed to log NoAlc: No ModelContainer available")
            return
        }

        let context = container.mainContext

        // Find NoAlc tracker by healthKitType
        let descriptor = FetchDescriptor<Tracker>(predicate: #Predicate {
            $0.healthKitType == "HKQuantityTypeIdentifierNumberOfAlcoholicBeverages"
        })

        guard let noAlcTracker = try? context.fetch(descriptor).first else {
            print("❌ Failed to log NoAlc: No NoAlc tracker found")
            return
        }

        // Log entry via TrackerManager (handles HealthKit + SwiftData)
        let _ = TrackerManager.shared.logEntry(for: noAlcTracker, value: levelId, in: context)
        try? context.save()

        let levelLabel = TrackerLevel.noAlcLevels.first { $0.id == levelId }?.localizedLabel ?? "Unknown"
        print("✅ Logged NoAlc: \(levelLabel) via TrackerManager")
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
