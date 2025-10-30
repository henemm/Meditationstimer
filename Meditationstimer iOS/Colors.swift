//
//  Colors.swift
//  Meditationstimer iOS
//
//  Created by Henning Emmrich on 21.10.25.
//

import SwiftUI

extension Color {
    /// Light blue color used for mindfulness activities in calendar
    static let mindfulnessBlue = Color(red: 0.67, green: 0.86, blue: 0.98)

    /// Violet color used for workout activities and buttons
    static let workoutViolet = Color(red: 0.58, green: 0.31, blue: 0.73)

    /// Red color used for today's indicator in calendar
    static let todayRed = Color.red

    // MARK: - Alcohol Tracking Colors

    /// Deep green for 0-1 drinks (best - NoAlk streak eligible)
    static let alcoholLow = Color(red: 0.20, green: 0.70, blue: 0.45)

    /// Medium green for 2-6 drinks (moderate consumption)
    static let alcoholMedium = Color(red: 0.55, green: 0.78, blue: 0.55)

    /// Light green for 7+ drinks (heavy consumption)
    static let alcoholHigh = Color(red: 0.75, green: 0.85, blue: 0.75)
}