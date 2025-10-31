//
//  NoAlcNotificationManager.swift
//  Lean Health Timer
//
//  Created by Claude on 31.10.2025.
//

import Foundation
import UserNotifications

/// Manages daily reminders for alcohol consumption logging
@MainActor
final class NoAlcNotificationManager {
    static let shared = NoAlcNotificationManager()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let noAlc = NoAlcManager.shared

    // Notification identifiers
    private let categoryIdentifier = "NOALC_REMINDER"
    private let notificationIdentifier = "noalc.daily.reminder"

    // Action identifiers
    private let steadyActionId = "STEADY_ACTION"
    private let easyActionId = "EASY_ACTION"
    private let wildActionId = "WILD_ACTION"

    private init() {}

    // MARK: - Setup

    /// Registers notification categories and actions
    func registerNotificationCategories() {
        let steadyAction = UNNotificationAction(
            identifier: steadyActionId,
            title: "💧 Steady",
            options: [.foreground]  // Opens app to write HealthKit
        )

        let easyAction = UNNotificationAction(
            identifier: easyActionId,
            title: "✨ Easy",
            options: [.foreground]
        )

        let wildAction = UNNotificationAction(
            identifier: wildActionId,
            title: "💥 Wild",
            options: [.foreground]
        )

        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [steadyAction, easyAction, wildAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([category])
    }

    /// Requests notification permissions
    func requestAuthorization() async throws {
        try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Scheduling

    /// Schedules daily reminder at specified hour (default 09:00)
    func scheduleDailyReminder(hour: Int = 9, minute: Int = 0) async throws {
        // Cancel existing notification
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])

        // Create notification content
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = categoryIdentifier
        content.sound = .default

        // Dynamic title based on time
        let currentHour = Calendar.current.component(.hour, from: Date())
        if currentHour < 18 {
            content.title = "How was your evening yesterday?"
        } else {
            content.title = "How's your evening going?"
        }

        content.body = "Log your drinks to keep your streak going 💧"

        // Create trigger for specified time
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        // Create request
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
    }

    /// Checks if notification should be sent (only if no entry exists for target day)
    func shouldSendNotification() async -> Bool {
        let targetDay = noAlc.targetDay()

        do {
            let existingLevel = try await noAlc.fetchConsumption(for: targetDay)
            return existingLevel == nil  // Send only if no entry exists
        } catch {
            // On error, don't send notification to avoid spam
            return false
        }
    }

    // MARK: - Response Handling

    /// Handles notification action response
    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        guard response.notification.request.content.categoryIdentifier == categoryIdentifier else {
            return
        }

        let actionId = response.actionIdentifier
        let level: NoAlcManager.ConsumptionLevel?

        switch actionId {
        case steadyActionId:
            level = .steady
        case easyActionId:
            level = .easy
        case wildActionId:
            level = .wild
        default:
            return
        }

        guard let level = level else { return }

        // Determine target day based on current time
        let targetDay = noAlc.targetDay()

        do {
            // Request HealthKit authorization if needed
            try await noAlc.requestAuthorization()

            // Log consumption
            try await noAlc.logConsumption(level, for: targetDay)

            // Optional: Show success feedback via local notification
            await showSuccessFeedback(level: level)

        } catch {
            print("❌ Failed to log NoAlc from notification: \(error)")
            // Optional: Show error feedback
        }
    }

    // MARK: - Feedback

    /// Shows success feedback after logging
    private func showSuccessFeedback(level: NoAlcManager.ConsumptionLevel) async {
        let content = UNMutableNotificationContent()
        content.title = "Logged!"
        content.body = "\(level.emoji) \(level.label) - Keep it up!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "noalc.feedback.\(UUID().uuidString)",
            content: content,
            trigger: nil  // Immediate delivery
        )

        try? await notificationCenter.add(request)
    }

    // MARK: - Utilities

    /// Cancels all pending NoAlc notifications
    func cancelAllNotifications() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    }

    /// Gets current notification authorization status
    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }
}
