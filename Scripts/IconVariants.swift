#!/usr/bin/env swift

//
//  IconVariants.swift
//  Generiert verschiedene HHHaven Icon-Varianten zur Auswahl
//

import SwiftUI
import AppKit
import Foundation

// MARK: - Color Extension

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

// MARK: - Icon View

struct HavenIconVariant: View {
    var ringColor: Color
    var coreColor: Color
    var backgroundColor: Color
    var ringWidth: CGFloat      // Dicke des Rings
    var coreScale: CGFloat      // Größe des inneren Kreises (0.0 - 1.0)
    var coreOffset: CGFloat     // Y-Offset des Kerns (0 = zentriert)
    var openingSize: CGFloat    // Größe der Öffnung (0.0 - 0.5)

    var body: some View {
        ZStack {
            Rectangle().fill(backgroundColor)

            // Äußerer Ring
            Circle()
                .trim(from: openingSize, to: 1.0 - openingSize)
                .stroke(ringColor, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .rotationEffect(.degrees(90))
                .padding(ringWidth / 2 + 80)

            // Innerer Kreis (zentriert oder mit Offset)
            Circle()
                .fill(coreColor)
                .scaleEffect(coreScale)
                .offset(y: coreOffset)
                .padding(80)
        }
        .frame(width: 1024, height: 1024)
    }
}

// MARK: - Varianten Definition

struct IconVariant {
    let name: String
    let description: String
    let ringColor: Color
    let coreColor: Color
    let ringWidth: CGFloat
    let coreScale: CGFloat
    let coreOffset: CGFloat
    let openingSize: CGFloat
}

let variants: [IconVariant] = [
    // VARIANTE A: Kräftiger blauer Ring, zentrierter grüner Kern
    IconVariant(
        name: "A_BlauKraeftig",
        description: "Kräftiger blauer Ring (#2563EB), zentrierter grüner Kern",
        ringColor: Color(hex: "#2563EB"),  // Kräftiges Blau
        coreColor: Color(hex: "#10B981"),  // Smaragd-Grün
        ringWidth: 140,                     // Dicker!
        coreScale: 0.30,
        coreOffset: 0,                      // Zentriert!
        openingSize: 0.12
    ),

    // VARIANTE B: Türkis-Duo, sehr harmonisch
    IconVariant(
        name: "B_TuerkisDuo",
        description: "Türkis Ring (#0891B2), hellerer türkis Kern",
        ringColor: Color(hex: "#0891B2"),  // Cyan/Türkis
        coreColor: Color(hex: "#5EEAD4"),  // Helles Türkis
        ringWidth: 130,
        coreScale: 0.35,
        coreOffset: 0,
        openingSize: 0.15
    ),

    // VARIANTE C: Dunkelblau Premium, kleiner Akzent
    IconVariant(
        name: "C_DunkelblauPremium",
        description: "Dunkelblau Ring (#1E40AF), gold-gelber Akzent",
        ringColor: Color(hex: "#1E40AF"),  // Dunkelblau
        coreColor: Color(hex: "#FBBF24"),  // Gold/Amber
        ringWidth: 150,                     // Sehr dick
        coreScale: 0.25,                    // Kleiner Kern
        coreOffset: 0,
        openingSize: 0.10                   // Kleinere Öffnung
    ),

    // VARIANTE D: Grün-Monochrom, natürlich
    IconVariant(
        name: "D_GruenNatur",
        description: "Dunkelgrün Ring (#059669), hellgrüner Kern",
        ringColor: Color(hex: "#059669"),  // Dunkelgrün
        coreColor: Color(hex: "#6EE7B7"),  // Hellgrün
        ringWidth: 135,
        coreScale: 0.32,
        coreOffset: 0,
        openingSize: 0.13
    ),

    // VARIANTE E: Lila-Rosa Gradient-Look
    IconVariant(
        name: "E_ModernLila",
        description: "Modernes Lila (#7C3AED), rosa Kern",
        ringColor: Color(hex: "#7C3AED"),  // Violet
        coreColor: Color(hex: "#F472B6"),  // Pink
        ringWidth: 120,
        coreScale: 0.38,                    // Größerer Kern
        coreOffset: 0,
        openingSize: 0.18                   // Größere Öffnung
    ),

    // VARIANTE F: Schwarz-Weiß Minimalist
    IconVariant(
        name: "F_Minimalist",
        description: "Schwarzer Ring, weißer Kern (minimalistisch)",
        ringColor: Color(hex: "#1F2937"),  // Fast Schwarz
        coreColor: Color(hex: "#F3F4F6"),  // Fast Weiß
        ringWidth: 160,                     // Sehr dick
        coreScale: 0.28,
        coreOffset: 0,
        openingSize: 0.08                   // Kleine Öffnung
    )
]

// MARK: - Export

@MainActor
func exportVariant(_ variant: IconVariant, to directory: String) {
    let icon = HavenIconVariant(
        ringColor: variant.ringColor,
        coreColor: variant.coreColor,
        backgroundColor: .white,
        ringWidth: variant.ringWidth,
        coreScale: variant.coreScale,
        coreOffset: variant.coreOffset,
        openingSize: variant.openingSize
    )

    let renderer = ImageRenderer(content: icon)
    renderer.scale = 1.0

    guard let cgImage = renderer.cgImage else {
        print("❌ Failed: \(variant.name)")
        return
    }

    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    bitmapRep.size = NSSize(width: 1024, height: 1024)

    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        print("❌ PNG failed: \(variant.name)")
        return
    }

    let filename = "icon-\(variant.name).png"
    let filePath = (directory as NSString).appendingPathComponent(filename)

    do {
        try pngData.write(to: URL(fileURLWithPath: filePath))
        print("✅ \(filename)")
        print("   → \(variant.description)")
    } catch {
        print("❌ Write failed: \(error)")
    }
}

// MARK: - Main

@MainActor
func main() {
    let outputDir = "/Users/hem/Desktop/HHHaven-Varianten"

    // Create output directory
    try? FileManager.default.createDirectory(
        atPath: outputDir,
        withIntermediateDirectories: true
    )

    print("🎨 HHHaven Icon-Varianten Generator")
    print("===================================\n")
    print("Output: \(outputDir)\n")

    for variant in variants {
        exportVariant(variant, to: outputDir)
    }

    print("\n🎉 Fertig! Öffne den Desktop-Ordner und wähle deine Favoriten.")
    print("\nVarianten-Übersicht:")
    print("─────────────────────")
    for v in variants {
        print("• \(v.name): \(v.description)")
    }
}

MainActor.assumeIsolated {
    main()
}
