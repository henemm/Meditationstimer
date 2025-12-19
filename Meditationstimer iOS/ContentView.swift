// probe: second-test
// probe: work-with-apps
//
//  ContentView.swift
//  Meditationstimer iOS
//
//  Created by Henning Emmrich on 01.09.25.
//

import SwiftUI
import HealthKit

// MARK: - AI ORIENTATION (Read me first)
// Purpose:
//   ContentView is ONLY the tab container and the cross-cutting session controller for the
//   two-phase meditation (start/stop, phase change, notifications, live activity, idle timer).
//   UI for each tab lives in its own file.
//
// Files & Responsibilities (where to look next):
//   • OffenView.swift       – "Offen" tab UI, including the circular ring overlay.
//   • AtemView.swift        – Breathing presets list, editor, and run card.
//   • WorkoutsView.swift    – Workout sessions.
//   • SettingsSheet.swift   – Shared settings sheet used by all tabs.
//   • CircularRing.swift    – Reusable progress ring view.
//   • TwoPhaseTimerEngine   – Timer state machine (model) for Offen tab sessions.
//   • (Live Activities entfernt)
//   • NotificationHelper    – Local notifications (backup when app backgrounds).
//   • HealthKitManager      – Logs mindfulness to Health.
//   • BackgroundAudioKeeper – Keeps audio session alive so timers/gongs aren't killed.
//
// Control Flow (high level):
//   Tabs only. No engine state handling here; each tab manages its own session flow,
//   sounds, idle timer, notifications, and Live Activity updates.

// MARK: - Tab Enum for Shortcuts Deep Linking
enum AppTab: String, CaseIterable {
    case meditation, workout, tracker, erfolge
}

struct ContentView: View {
    // Einstellungen (merken letzte Werte)
    @AppStorage("phase1Minutes") private var phase1Minutes: Int = 15
    @AppStorage("phase2Minutes") private var phase2Minutes: Int = 3

    // Services
    private let hk = HealthKitManager()
    private let notifier = NotificationHelper()
    @StateObject private var engine = TwoPhaseTimerEngine()
    @StateObject private var streakManager = StreakManager()
    @StateObject private var shortcutHandler = ShortcutHandler()
    @StateObject private var liveActivity = LiveActivityController()
    @State private var showingError: String?
    @State private var askedPermissions = false
    @State private var showingCalendar = false

    // Tab selection (for Shortcuts deep linking)
    @State private var selectedTab: AppTab = .meditation


    var body: some View {
        // MARK: Tabs & global background
        NavigationView {
            TabView(selection: $selectedTab) {
                MeditationTab()
                    .environmentObject(engine)
                    .environmentObject(streakManager)
                    .environmentObject(liveActivity)
                    .tabItem {
                        Label("Meditation", systemImage: "figure.mind.and.body")
                    }
                    .tag(AppTab.meditation)

                WorkoutTab()
                    .environmentObject(streakManager)
                    .environmentObject(liveActivity)
                    .tabItem {
                        Label("Workout", systemImage: "flame")
                    }
                    .tag(AppTab.workout)

                TrackerTab()
                    .environmentObject(streakManager)
                    .tabItem {
                        Label("Tracker", systemImage: "chart.bar.fill")
                    }
                    .tag(AppTab.tracker)

                ErfolgeTab()
                    .environmentObject(streakManager)
                    .tabItem {
                        Label("Erfolge", systemImage: "trophy.fill")
                    }
                    .tag(AppTab.erfolge)
            }
            .background(
                LinearGradient(colors: [Color.blue.opacity(0.20), Color.purple.opacity(0.15)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            )
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // Permissions are now requested on-demand in each tab when needed
            #if DEBUG
            let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            #else
            let isPreview = false
            #endif

            // Reset stored streaks to force recalculation with new filtering logic
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: "meditationStreak")
            defaults.removeObject(forKey: "workoutStreak")

            // Update streaks with new filtered data
            Task {
                await streakManager.updateStreaks()
                // Force UI update by reassigning the published properties
                await MainActor.run {
                    let medStreak = streakManager.meditationStreak
                    let workStreak = streakManager.workoutStreak
                    streakManager.meditationStreak = medStreak
                    streakManager.workoutStreak = workStreak
                }
            }
        }
        .onOpenURL { url in
            // Handle deep links from Shortcuts App
            shortcutHandler.handle(url, selectedTab: $selectedTab)
        }
        .onReceive(NotificationCenter.default.publisher(for: .startMeditationSession)) { _ in
            // Switch to Meditation tab before session starts
            selectedTab = .meditation
            print("[ContentView] Switched to Meditation tab for meditation session")
        }
        .onReceive(NotificationCenter.default.publisher(for: .startBreathingSession)) { _ in
            // Switch to Meditation tab before session starts (breathing is now part of Meditation tab)
            selectedTab = .meditation
            print("[ContentView] Switched to Meditation tab for breathing session")
        }
        .onReceive(NotificationCenter.default.publisher(for: .startWorkoutSession)) { _ in
            // Switch to Workout tab before session starts
            selectedTab = .workout
            print("[ContentView] Switched to Workout tab for workout session")
        }
        .alert("Notice", isPresented: .constant(showingError != nil), actions: {
            Button("OK") { showingError = nil }
        }, message: { Text(showingError ?? "") })
    }
}


#Preview {
    ContentView()
}

