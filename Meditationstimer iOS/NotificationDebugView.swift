//
//  NotificationDebugView.swift
//  Lean Health Timer
//
//  Debug view to test UNCalendarNotificationTrigger
//

import SwiftUI
import UserNotifications

struct NotificationDebugView: View {
    @State private var pendingNotifications: [UNNotificationRequest] = []
    @State private var statusMessage: String = ""
    @State private var testTime: Date = Date()

    var body: some View {
        List {
            Section(header: Text("Quick Test")) {
                Button("Schedule notification in 10 seconds") {
                    scheduleTestNotification(seconds: 10)
                }

                DatePicker("Test Time", selection: $testTime, displayedComponents: [.hourAndMinute])

                Button("Schedule at selected time") {
                    scheduleAtTime(testTime)
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            Section(header: Text("Pending Notifications (\(pendingNotifications.count))")) {
                if pendingNotifications.isEmpty {
                    Text("No pending notifications")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(pendingNotifications, id: \.identifier) { request in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(request.content.title)
                                .font(.headline)
                            Text(request.identifier)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                               let nextTrigger = trigger.nextTriggerDate() {
                                Text("Next fire: \(nextTrigger.formatted())")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                                Text("In \(Int(trigger.timeInterval)) seconds")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                Button("Refresh List") {
                    loadPendingNotifications()
                }

                Button("Clear All Notifications", role: .destructive) {
                    clearAllNotifications()
                }
            }
        }
        .navigationTitle("Notification Debug")
        .onAppear {
            loadPendingNotifications()
        }
    }

    // MARK: - Test Functions

    private func scheduleTestNotification(seconds: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test after \(seconds) seconds"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: "test-\(UUID().uuidString)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    statusMessage = "❌ Error: \(error.localizedDescription)"
                } else {
                    statusMessage = "✅ Scheduled test in \(seconds)s"
                    loadPendingNotifications()
                }
            }
        }
    }

    private func scheduleAtTime(_ date: Date) {
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.hour = calendar.component(.hour, from: date)
        dateComponents.minute = calendar.component(.minute, from: date)

        let content = UNMutableNotificationContent()
        content.title = "Time-Based Test"
        content.body = "Scheduled for \(String(format: "%02d:%02d", dateComponents.hour!, dateComponents.minute!))"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "time-test-\(UUID().uuidString)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    statusMessage = "❌ Error: \(error.localizedDescription)"
                } else {
                    statusMessage = "✅ Scheduled at \(String(format: "%02d:%02d", dateComponents.hour!, dateComponents.minute!))"
                    loadPendingNotifications()
                }
            }
        }
    }

    private func loadPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                pendingNotifications = requests
                print("📋 Found \(requests.count) pending notifications:")
                for request in requests {
                    if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                        print("  - \(request.content.title): \(trigger.nextTriggerDate()?.formatted() ?? "unknown")")
                    } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                        print("  - \(request.content.title): in \(trigger.timeInterval)s")
                    }
                }
            }
        }
    }

    private func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        statusMessage = "🗑️ Cleared all notifications"
        loadPendingNotifications()
    }
}

#Preview {
    NavigationView {
        NotificationDebugView()
    }
}
