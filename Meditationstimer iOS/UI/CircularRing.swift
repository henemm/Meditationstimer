
//
//  CircularRing.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 27.09.25.
//

import SwiftUI

/// Runder, schrumpfender Fortschrittsring (1.0 → 0.0)
struct CircularRing: View {
    var progress: Double      // 0...1 (remaining/total)
    var lineWidth: CGFloat = 26
    var trackOpacity: CGFloat = 0.18

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(trackOpacity), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    LinearGradient(colors: [.blue, .cyan],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))   // Start oben
                .animation(.easeInOut(duration: 0.25), value: progress)
        }
    }
}

