//
//  MeditationActivityAttributes.swift (Widget copy)
//  MeditationstimerWidget
//
//  This file mirrors the ActivityAttributes used by the app target so the widget
//  can compile independently and render Live Activities/Dynamic Island.
//  Keep this in sync with the app target's MeditationActivityAttributes.swift
//

import Foundation

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit

struct MeditationAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var endDate: Date
        var phase: Int // 1 = Meditation, 2 = Besinnung
    }
    var title: String
}
#else
// Preview/Simulator fallback - provides the same structure without ActivityKit dependency
struct MeditationAttributes {
    public struct ContentState: Codable, Hashable {
        var endDate: Date
        var phase: Int
    }
    var title: String
}
#endif
