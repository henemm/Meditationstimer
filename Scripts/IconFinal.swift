#!/usr/bin/env swift

//
//  IconFinal.swift
//  Finales HHHaven Icon: A-9 (dick-gross, rechts-oben)
//

import SwiftUI
import AppKit
import Foundation

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}

struct HavenIconFinal: View {
    var ringColor: Color
    var coreColor: Color
    var backgroundColor: Color

    // Finale Parameter: A-9 (dick-gross, rechts-oben)
    let ringWidth: CGFloat = 180        // Dick
    let coreScale: CGFloat = 0.40       // Groß
    let openingSize: CGFloat = 0.12
    let rotationDegrees: Double = 45    // Rechts-oben ↗

    var body: some View {
        ZStack {
            Rectangle().fill(backgroundColor)

            // Äußerer Ring
            Circle()
                .trim(from: openingSize, to: 1.0 - openingSize)
                .stroke(ringColor, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .rotationEffect(.degrees(rotationDegrees))
                .padding(ringWidth / 2 + 80)

            // Innerer Kreis (zentriert)
            Circle()
                .fill(coreColor)
                .scaleEffect(coreScale)
                .padding(80)
        }
        .frame(width: 1024, height: 1024)
    }
}

// Finale Farben: Variante A
let ringColor = Color(hex: "#2563EB")   // Kräftiges Blau
let coreColor = Color(hex: "#10B981")   // Smaragd-Grün

struct IconVariant {
    let filename: String
    let ringColor: Color
    let coreColor: Color
    let backgroundColor: Color
}

let variants: [IconVariant] = [
    // Standard (Light Mode)
    IconVariant(
        filename: "app-icon.png",
        ringColor: ringColor,
        coreColor: coreColor,
        backgroundColor: .white
    ),
    // Dark Mode
    IconVariant(
        filename: "app-icon-dark.png",
        ringColor: ringColor,
        coreColor: coreColor,
        backgroundColor: Color(hex: "#1C1C1E")
    ),
    // Tinted (Graustufen für iOS 26)
    IconVariant(
        filename: "app-icon-tinted.png",
        ringColor: .white,
        coreColor: .white.opacity(0.85),
        backgroundColor: .clear
    )
]

let outputDirs = [
    "/Users/hem/Developer/Meditationstimer/Meditationstimer/Meditationstimer iOS/Assets.xcassets/AppIcon.appiconset",
    "/Users/hem/Developer/Meditationstimer/Meditationstimer/Meditationstimer Watch App/Assets.xcassets/AppIcon.appiconset",
    "/Users/hem/Developer/Meditationstimer/Meditationstimer/MeditationstimerWidget/Assets.xcassets/AppIcon.appiconset"
]

@MainActor
func exportIcon(_ variant: IconVariant, to directory: String) {
    let icon = HavenIconFinal(
        ringColor: variant.ringColor,
        coreColor: variant.coreColor,
        backgroundColor: variant.backgroundColor
    )

    let renderer = ImageRenderer(content: icon)
    renderer.scale = 1.0

    guard let cgImage = renderer.cgImage else {
        print("❌ Render failed: \(variant.filename)")
        return
    }

    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    bitmapRep.size = NSSize(width: 1024, height: 1024)

    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        print("❌ PNG failed: \(variant.filename)")
        return
    }

    let filePath = (directory as NSString).appendingPathComponent(variant.filename)

    do {
        try pngData.write(to: URL(fileURLWithPath: filePath))
        print("   ✅ \(variant.filename)")
    } catch {
        print("   ❌ \(variant.filename): \(error)")
    }
}

@MainActor
func main() {
    print("🏝️ HHHaven Finales Icon Generator")
    print("==================================")
    print("Design: A-9 (dick-gross, rechts-oben ↗)")
    print("Ring: Kräftiges Blau #2563EB")
    print("Kern: Smaragd-Grün #10B981\n")

    for dir in outputDirs {
        let shortDir = (dir as NSString).lastPathComponent
        print("📁 \(shortDir):")

        for variant in variants {
            exportIcon(variant, to: dir)
        }
        print("")
    }

    print("🎉 Fertig! Alle 9 Icons wurden ersetzt.")
    print("\nNächster Schritt: Build & Test")
}

MainActor.assumeIsolated {
    main()
}
