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
        // Handle NoAlc direct logging (dual-log: Legacy + Generic Tracker)
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

            // Dual-log: Also log to Generic Tracker (SwiftData) if trackerID present
            let userInfo = response.notification.request.content.userInfo
            if let trackerIDString = userInfo["trackerID"] as? String,
               let trackerID = UUID(uuidString: trackerIDString) {
                await logTrackerFromNotification(trackerID: trackerID, actionIdentifier: response.actionIdentifier)
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
