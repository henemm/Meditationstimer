//
//  ShortcutHandler.swift
//  Lean Health Timer
//
//  Handles deep linking from Shortcuts App via henemm-lht:// URLs.
//  Parses URL parameters and coordinates tab navigation + session start.
//

import SwiftUI
import Foundation

// MARK: - Shortcut Action Types
enum ShortcutAction {
    case meditation(phase1Minutes: Int, phase2Minutes: Int)
    case breathing(presetName: String)
    case workout(intervalSec: Int, restSec: Int, repeats: Int)
}

// MARK: - Parsed Shortcut Request
struct ShortcutRequest {
    let tab: AppTab
    let action: ShortcutAction
}

// MARK: - Shortcut Handler
@MainActor
class ShortcutHandler: ObservableObject {

    /// Parses henemm-lht:// URL and returns ShortcutRequest
    /// - Parameter url: Deep link URL (e.g., henemm-lht://start?tab=offen&phase1=20&phase2=2)
    /// - Returns: Parsed ShortcutRequest or nil if invalid
    func parse(_ url: URL) -> ShortcutRequest? {
        // Validate scheme
        guard url.scheme == "henemm-lht" else {
            print("[ShortcutHandler] Invalid scheme: \(url.scheme ?? "nil")")
            return nil
        }

        // Parse query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("[ShortcutHandler] No query parameters found")
            return nil
        }

        let params = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item in
            item.value.map { (item.name, $0) }
        })

        // Extract tab
        guard let tabString = params["tab"],
              let tab = AppTab(rawValue: tabString) else {
            print("[ShortcutHandler] Missing or invalid 'tab' parameter")
            return nil
        }

        // Parse action based on tab
        let action: ShortcutAction

        switch tab {
        case .offen:
            // Meditation: phase1 (required), phase2 (optional, default 0)
            guard let phase1String = params["phase1"],
                  let phase1 = Int(phase1String) else {
                print("[ShortcutHandler] Missing or invalid 'phase1' parameter")
                return nil
            }
            let phase2 = params["phase2"].flatMap(Int.init) ?? 0

            // Validate ranges
            guard (1...120).contains(phase1) else {
                print("[ShortcutHandler] phase1 out of range (1-120): \(phase1)")
                return nil
            }
            guard (0...30).contains(phase2) else {
                print("[ShortcutHandler] phase2 out of range (0-30): \(phase2)")
                return nil
            }

            action = .meditation(phase1Minutes: phase1, phase2Minutes: phase2)

        case .atem:
            // Breathing: preset (required)
            guard let presetName = params["preset"] else {
                print("[ShortcutHandler] Missing 'preset' parameter")
                return nil
            }

            // Validate preset name (basic check, full validation in AtemView)
            let validPresets = ["Box 4-4-4-4", "4-0-6-0", "Coherent 5-0-5-0", "7-0-5-0", "4-7-8", "Rectangle 6-3-6-3"]
            guard validPresets.contains(presetName) else {
                print("[ShortcutHandler] Invalid preset name: \(presetName)")
                return nil
            }

            action = .breathing(presetName: presetName)

        case .workouts:
            // Workout: interval, rest, repeats (all required)
            guard let intervalString = params["interval"],
                  let restString = params["rest"],
                  let repeatsString = params["repeats"],
                  let interval = Int(intervalString),
                  let rest = Int(restString),
                  let repeats = Int(repeatsString) else {
                print("[ShortcutHandler] Missing or invalid workout parameters")
                return nil
            }

            // Validate ranges
            guard (5...600).contains(interval) else {
                print("[ShortcutHandler] interval out of range (5-600): \(interval)")
                return nil
            }
            guard (0...600).contains(rest) else {
                print("[ShortcutHandler] rest out of range (0-600): \(rest)")
                return nil
            }
            guard (1...200).contains(repeats) else {
                print("[ShortcutHandler] repeats out of range (1-200): \(repeats)")
                return nil
            }

            action = .workout(intervalSec: interval, restSec: rest, repeats: repeats)
        }

        return ShortcutRequest(tab: tab, action: action)
    }

    /// Handles shortcut URL with full session auto-start
    /// - Parameters:
    ///   - url: Deep link URL
    ///   - selectedTab: Binding to current tab selection
    func handle(_ url: URL, selectedTab: Binding<AppTab>) {
        print("[ShortcutHandler] Received URL: \(url.absoluteString)")

        guard let request = parse(url) else {
            print("[ShortcutHandler] Failed to parse URL")
            return
        }

        print("[ShortcutHandler] Parsed request: tab=\(request.tab), action=\(request.action)")

        // Switch to target tab
        selectedTab.wrappedValue = request.tab
        print("[ShortcutHandler] Switched to tab: \(request.tab)")

        // Wait for tab to render, then trigger session start
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.triggerSession(for: request)
        }
    }

    /// Triggers session start via NotificationCenter
    private func triggerSession(for request: ShortcutRequest) {
        let notification: Notification.Name

        switch request.action {
        case .meditation(let phase1, let phase2):
            // Update AppStorage values (OffenView will pick them up)
            UserDefaults.standard.set(phase1, forKey: "phase1Minutes")
            UserDefaults.standard.set(phase2, forKey: "phase2Minutes")
            notification = .startMeditationSession
            print("[ShortcutHandler] Triggering meditation: \(phase1)min + \(phase2)min")

        case .breathing(let presetName):
            // Pass preset name via notification userInfo
            NotificationCenter.default.post(
                name: .startBreathingSession,
                object: nil,
                userInfo: ["presetName": presetName]
            )
            print("[ShortcutHandler] Triggering breathing: \(presetName)")
            return // Early return (already posted)

        case .workout(let interval, let rest, let repeats):
            // Update AppStorage values (WorkoutsView will pick them up)
            UserDefaults.standard.set(interval, forKey: "intervalSec")
            UserDefaults.standard.set(rest, forKey: "restSec")
            UserDefaults.standard.set(repeats, forKey: "repeats")
            notification = .startWorkoutSession
            print("[ShortcutHandler] Triggering workout: \(interval)s/\(rest)s x\(repeats)")
        }

        // Post notification to trigger session start
        NotificationCenter.default.post(name: notification, object: nil)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let startMeditationSession = Notification.Name("startMeditationSession")
    static let startBreathingSession = Notification.Name("startBreathingSession")
    static let startWorkoutSession = Notification.Name("startWorkoutSession")
}
