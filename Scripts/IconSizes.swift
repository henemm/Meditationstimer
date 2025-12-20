#!/usr/bin/env swift

//
//  IconSizes.swift
//  Varianten A und C (rechts-oben) mit verschiedenen Größen
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

struct HavenIconSized: View {
    var ringColor: Color
    var coreColor: Color
    var backgroundColor: Color
    var ringWidth: CGFloat
    var coreScale: CGFloat
    var openingSize: CGFloat

    var body: some View {
        ZStack {
            Rectangle().fill(backgroundColor)

            // Äußerer Ring - Öffnung rechts-oben (45°)
            Circle()
                .trim(from: openingSize, to: 1.0 - openingSize)
                .stroke(ringColor, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .rotationEffect(.degrees(45))
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
}

struct SizeVariant {
    let name: String
    let ringWidth: CGFloat
    let coreScale: CGFloat
    let openingSize: CGFloat
    let description: String
}

let colorSchemes: [ColorScheme] = [
    ColorScheme(name: "A", ringColor: Color(hex: "#2563EB"), coreColor: Color(hex: "#10B981")),
    ColorScheme(name: "C", ringColor: Color(hex: "#1E40AF"), coreColor: Color(hex: "#FBBF24"))
]

let sizeVariants: [SizeVariant] = [
    // Ring-Variationen
    SizeVariant(name: "1-duenn-klein", ringWidth: 100, coreScale: 0.20, openingSize: 0.12,
                description: "Dünner Ring, kleiner Kern"),
    SizeVariant(name: "2-duenn-mittel", ringWidth: 100, coreScale: 0.30, openingSize: 0.12,
                description: "Dünner Ring, mittlerer Kern"),
    SizeVariant(name: "3-duenn-gross", ringWidth: 100, coreScale: 0.40, openingSize: 0.12,
                description: "Dünner Ring, großer Kern"),

    SizeVariant(name: "4-mittel-klein", ringWidth: 140, coreScale: 0.20, openingSize: 0.12,
                description: "Mittlerer Ring, kleiner Kern"),
    SizeVariant(name: "5-mittel-mittel", ringWidth: 140, coreScale: 0.30, openingSize: 0.12,
                description: "Mittlerer Ring, mittlerer Kern"),
    SizeVariant(name: "6-mittel-gross", ringWidth: 140, coreScale: 0.40, openingSize: 0.12,
                description: "Mittlerer Ring, großer Kern"),

    SizeVariant(name: "7-dick-klein", ringWidth: 180, coreScale: 0.20, openingSize: 0.12,
                description: "Dicker Ring, kleiner Kern"),
    SizeVariant(name: "8-dick-mittel", ringWidth: 180, coreScale: 0.30, openingSize: 0.12,
                description: "Dicker Ring, mittlerer Kern"),
    SizeVariant(name: "9-dick-gross", ringWidth: 180, coreScale: 0.40, openingSize: 0.12,
                description: "Dicker Ring, großer Kern"),

    // Extreme Varianten
    SizeVariant(name: "X1-extrem-duenn", ringWidth: 70, coreScale: 0.35, openingSize: 0.15,
                description: "Sehr dünner Ring, mittlerer Kern"),
    SizeVariant(name: "X2-extrem-dick", ringWidth: 220, coreScale: 0.25, openingSize: 0.10,
                description: "Sehr dicker Ring, kleiner Kern"),
    SizeVariant(name: "X3-grosser-kern", ringWidth: 130, coreScale: 0.50, openingSize: 0.12,
                description: "Mittlerer Ring, sehr großer Kern"),
]

@MainActor
func exportIcon(scheme: ColorScheme, size: SizeVariant, to directory: String) {
    let icon = HavenIconSized(
        ringColor: scheme.ringColor,
        coreColor: scheme.coreColor,
        backgroundColor: .white,
        ringWidth: size.ringWidth,
        coreScale: size.coreScale,
        openingSize: size.openingSize
    )

    let renderer = ImageRenderer(content: icon)
    renderer.scale = 1.0

    guard let cgImage = renderer.cgImage else { return }

    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    bitmapRep.size = NSSize(width: 1024, height: 1024)

    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }

    let filename = "icon-\(scheme.name)-\(size.name).png"
    let filePath = (directory as NSString).appendingPathComponent(filename)

    do {
        try pngData.write(to: URL(fileURLWithPath: filePath))
        print("✅ \(filename)")
    } catch {
        print("❌ \(filename)")
    }
}

@MainActor
func main() {
    let outputDir = "/Users/hem/Desktop/HHHaven-Groessen"

    try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

    print("📐 HHHaven Größen-Varianten Generator")
    print("=====================================")
    print("Alle mit Öffnung rechts-oben ↗\n")

    for scheme in colorSchemes {
        print("📦 Variante \(scheme.name):")
        for size in sizeVariants {
            exportIcon(scheme: scheme, size: size, to: outputDir)
        }
        print("")
    }

    print("🎉 Fertig! 24 Varianten erstellt.\n")

    print("Legende (Ring × Kern):")
    print("──────────────────────")
    print("1-3: Dünner Ring (100px)")
    print("4-6: Mittlerer Ring (140px)")
    print("7-9: Dicker Ring (180px)")
    print("X1-X3: Extreme Varianten")
    print("")
    print("klein = 20%, mittel = 30%, gross = 40%")
}

MainActor.assumeIsolated {
    main()
}
