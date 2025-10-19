//
//  MeditationActivityAttributes.swift (Widget copy)
//  MeditationstimerWidget
//
//  This file mirrors the ActivityAttributes used by the app target so the widget
//  can compile independently and render Live Activities/Dynamic Island.
//  Keep this in sync with the app target's MeditationActivityAttributes.swift
//

import ActivityKit
import Foundation

#if canImport(ActivityKit)
struct MeditationAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
    var endDate: Date
    var phase: Int // 1 = Meditation, 2 = Besinnung
    var ownerId: String?
    var isPaused: Bool
    }
    var title: String
}
#endif
