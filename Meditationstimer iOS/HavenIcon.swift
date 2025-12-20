//
//  HavenIcon.swift
//  Meditationstimer iOS
//
//  Created by Claude Code on 20.12.25.
//

import SwiftUI

/// The Haven Icon represents "Healthy Habits Haven" (HHHaven)
/// - Outer ring (the "harbor"): A protective arc opening upward, symbolizing safety and guidance
/// - Inner circle (the "habit"): A solid core representing the habits being nurtured
struct HavenIcon: View {
    // MARK: - Properties

    /// Color for the outer ring (default: workoutViolet #944FBA)
    var outerColor: Color = .workoutViolet

    /// Color for the inner circle (default: alcoholSteady green)
    var innerColor: Color = Color("alcoholSteady")

    /// Stroke width for the outer ring (scales with icon size)
    var lineWidth: CGFloat = 12

    /// Optional background color (nil = transparent)
    var backgroundColor: Color? = nil

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background (if provided)
            if let bg = backgroundColor {
                Rectangle()
                    .fill(bg)
            }

            // Outer Ring (The Harbor)
            // Trim creates the opening at the top (70% of circle shown)
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(outerColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(90)) // Rotates opening to top
                .padding(lineWidth / 2) // Prevents stroke from being clipped

            // Inner Circle (The Habit)
            Circle()
                .fill(innerColor)
                .scaleEffect(0.35) // Size relative to outer ring
                .offset(y: 5) // Slightly offset down for visual balance
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Convenience Initializers

extension HavenIcon {
    /// Creates a HavenIcon with custom hex colors
    init(outerHex: String, innerHex: String, lineWidth: CGFloat = 12) {
        self.outerColor = Color(hex: outerHex)
        self.innerColor = Color(hex: innerHex)
        self.lineWidth = lineWidth
    }

    /// Creates a grayscale version for iOS 26 tinted icons
    static var tinted: some View {
        HavenIcon(
            outerColor: .white,
            innerColor: .white.opacity(0.9),
            lineWidth: 12
        )
    }
}

// MARK: - Preview

#Preview("Haven Icon Sizes") {
    VStack(spacing: 40) {
        // Small (list items)
        HavenIcon()
            .frame(width: 50, height: 50)

        // Medium (buttons)
        HavenIcon()
            .frame(width: 100, height: 100)

        // Large (app icon size)
        HavenIcon(lineWidth: 20)
            .frame(width: 200, height: 200)
    }
    .padding()
}

#Preview("Haven Icon Variants") {
    HStack(spacing: 30) {
        // Light mode
        HavenIcon(backgroundColor: .white)
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 22))

        // Dark mode
        HavenIcon(backgroundColor: Color(white: 0.1))
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 22))

        // Tinted (grayscale)
        HavenIcon.tinted
            .frame(width: 100, height: 100)
            .background(Color.gray.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 22))
    }
    .padding()
}
