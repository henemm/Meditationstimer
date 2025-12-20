#!/usr/bin/env swift

//
//  IconDirections.swift
//  Varianten A und C mit verschiedenen Ring-Öffnungsrichtungen
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

struct HavenIconDirectional: View {
    var ringColor: Color
    var coreColor: Color
    var backgroundColor: Color
    var ringWidth: CGFloat
    var coreScale: CGFloat
    var openingSize: CGFloat
    var rotationDegrees: Double  // Richtung der Öffnung

    var body: some View {
        ZStack {
            Rectangle().fill(backgroundColor)

            // Äußerer Ring mit variabler Öffnungsrichtung
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

struct ColorScheme {
    let name: String
    let ringColor: Color
    let coreColor: Color
    let ringWidth: CGFloat
    let coreScale: CGFloat
    let openingSize: CGFloat
}

struct Direction {
    let name: String
    let degrees: Double
    let description: String
}

let colorSchemes: [ColorScheme] = [
    ColorScheme(
        name: "A",
        ringColor: Color(hex: "#2563EB"),  // Kräftiges Blau
        coreColor: Color(hex: "#10B981"),  // Smaragd-Grün
        ringWidth: 140,
        coreScale: 0.30,
        openingSize: 0.12
    ),
    ColorScheme(
        name: "C",
        ringColor: Color(hex: "#1E40AF"),  // Dunkelblau
        coreColor: Color(hex: "#FBBF24"),  // Gold
        ringWidth: 150,
        coreScale: 0.25,
        openingSize: 0.10
    )
]

let directions: [Direction] = [
    Direction(name: "oben", degrees: 90, description: "Öffnung nach oben ↑"),
    Direction(name: "rechts", degrees: 0, description: "Öffnung nach rechts →"),
    Direction(name: "unten", degrees: -90, description: "Öffnung nach unten ↓"),
    Direction(name: "links", degrees: 180, description: "Öffnung nach links ←"),
    Direction(name: "rechts-oben", degrees: 45, description: "Öffnung nach rechts-oben ↗"),
    Direction(name: "links-oben", degrees: 135, description: "Öffnung nach links-oben ↖"),
]

@MainActor
func exportIcon(scheme: ColorScheme, direction: Direction, to directory: String) {
    let icon = HavenIconDirectional(
        ringColor: scheme.ringColor,
        coreColor: scheme.coreColor,
        backgroundColor: .white,
        ringWidth: scheme.ringWidth,
        coreScale: scheme.coreScale,
        openingSize: scheme.openingSize,
        rotationDegrees: direction.degrees
    )

    let renderer = ImageRenderer(content: icon)
    renderer.scale = 1.0

    guard let cgImage = renderer.cgImage else { return }

    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    bitmapRep.size = NSSize(width: 1024, height: 1024)

    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }

    let filename = "icon-\(scheme.name)-\(direction.name).png"
    let filePath = (directory as NSString).appendingPathComponent(filename)

    do {
        try pngData.write(to: URL(fileURLWithPath: filePath))
        print("✅ \(filename) — \(direction.description)")
    } catch {
        print("❌ \(filename)")
    }
}

@MainActor
func main() {
    let outputDir = "/Users/hem/Desktop/HHHaven-Richtungen"

    try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

    print("🧭 HHHaven Ring-Richtungen Generator")
    print("====================================\n")

    for scheme in colorSchemes {
        print("📦 Variante \(scheme.name):")
        for direction in directions {
            exportIcon(scheme: scheme, direction: direction, to: outputDir)
        }
        print("")
    }

    print("🎉 Fertig! 12 Varianten erstellt.")
    print("\nÖffne: \(outputDir)")
}

MainActor.assumeIsolated {
    main()
}
