//
//  Colors.swift
//  Meditationstimer iOS
//
//  Created by Henning Emmrich on 21.10.25.
//

import SwiftUI

extension Color {
    // MARK: - Hex Initializer

    /// Initialize Color from hex string (e.g., "#1FCF7E" or "1FCF7E")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    // MARK: - Predefined Colors

    /// Light blue color used for mindfulness activities in calendar
    static let mindfulnessBlue = Color(red: 0.67, green: 0.86, blue: 0.98)

    /// Violet color used for workout activities and buttons
    static let workoutViolet = Color(red: 0.58, green: 0.31, blue: 0.73)

    /// Red color used for today's indicator in calendar
    static let todayRed = Color.red

    // MARK: - Alcohol Tracking Colors
    // Note: Alcohol colors are now defined in Assets.xcassets/*.colorset
    // This supports Dark Mode variants properly:
    // - alcoholSteady: Green for 0-1 drinks (Steady)
    // - alcoholEasy: Orange for 2-5 drinks (Easy)
    // - alcoholWild: Red for 6+ drinks (Wild)
    // - alcoholText: White text for ALL alcohol tracking backgrounds
}