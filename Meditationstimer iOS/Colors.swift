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

    /// Bright green for 0-1 drinks (Steady)
    static let alcoholSteady = Color(hex: "#1FCF7E")

    /// Medium green for 2-5 drinks (Easy)
    static let alcoholEasy = Color(hex: "#89D6B2")

    /// Gray for 6+ drinks (Wild)
    static let alcoholWild = Color(hex: "#B6B6B6")

    // MARK: - Alcohol Text Colors

    /// White text for Steady background
    static let alcoholSteadyText = Color.white

    /// Black text for Easy/Wild backgrounds
    static let alcoholEasyWildText = Color.black
}