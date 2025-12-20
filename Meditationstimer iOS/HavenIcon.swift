//
//  HavenIcon.swift
//  Meditationstimer iOS
//
//  Finales Design: A-9 (dick-gross, rechts-oben ↗)
//

import SwiftUI

/// The Haven Icon represents "Healthy Habits Haven" (HHHaven)
/// - Outer ring (the "harbor"): A protective arc opening to the upper-right
/// - Inner circle (the "habit"): A solid core representing the habits being nurtured
struct HavenIcon: View {
    // MARK: - Customizable Properties

    /// Color for the outer ring (default: Kräftiges Blau #2563EB)
    var ringColor: Color = Color(hex: "#2563EB")

    /// Color for the inner circle (default: Smaragd-Grün #10B981)
    var coreColor: Color = Color(hex: "#10B981")

    /// Optional background color (nil = transparent)
    var backgroundColor: Color? = nil

    // MARK: - Fixed Design Parameters (A-9)

    /// Ring thickness relative to icon size (scaled automatically)
    private let ringWidthRatio: CGFloat = 0.176  // 180/1024

    /// Core size relative to icon (40% = gross)
    private let coreScale: CGFloat = 0.40

    /// Opening size (12% on each side = 76% ring visible)
    private let openingSize: CGFloat = 0.12

    /// Opening direction: 45° = upper-right ↗
    private let rotationDegrees: Double = 45

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let ringWidth = size * ringWidthRatio
            let padding = ringWidth / 2 + size * 0.08

            ZStack {
                // Background (if provided)
                if let bg = backgroundColor {
                    Rectangle().fill(bg)
                }

                // Outer Ring (The Harbor)
                Circle()
                    .trim(from: openingSize, to: 1.0 - openingSize)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(rotationDegrees))
                    .padding(padding)

                // Inner Circle (The Habit) - zentriert
                Circle()
                    .fill(coreColor)
                    .scaleEffect(coreScale)
                    .padding(size * 0.08)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Convenience Variants

extension HavenIcon {
    /// Dark mode variant with dark background
    static var dark: HavenIcon {
        HavenIcon(backgroundColor: Color(hex: "#1C1C1E"))
    }

    /// Tinted variant (grayscale for iOS 26)
    static var tinted: HavenIcon {
        HavenIcon(
            ringColor: .white,
            coreColor: .white.opacity(0.85),
            backgroundColor: .clear
        )
    }
}

// MARK: - Preview

#Preview("Haven Icon") {
    VStack(spacing: 30) {
        HStack(spacing: 20) {
            // Small
            HavenIcon()
                .frame(width: 60, height: 60)

            // Medium
            HavenIcon()
                .frame(width: 100, height: 100)

            // Large
            HavenIcon()
                .frame(width: 150, height: 150)
        }

        HStack(spacing: 20) {
            // Light
            HavenIcon(backgroundColor: .white)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22))

            // Dark
            HavenIcon.dark
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22))

            // Tinted
            HavenIcon.tinted
                .frame(width: 100, height: 100)
                .background(Color.gray.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 22))
        }
    }
    .padding()
}
