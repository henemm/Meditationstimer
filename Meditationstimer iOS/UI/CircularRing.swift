// MARK: - AI ORIENTATION (Read me first)
// Purpose:
//   CircularRing is a reusable SwiftUI component for displaying progress as a circular ring.
//   Used throughout the app for meditation timers, breathing exercises, and workout progress.
//   Supports customizable styling and dual-ring configurations.
//
// Usage Patterns:
//   • OffenView: Single ring for phase progress (meditation/besinnung)
//   • AtemView: Dual rings - outer (session total), inner (current breathing phase)
//   • WorkoutsView: Dual rings - outer (workout total), inner (work/rest phase)
//
// Customization Options:
//   • progress: 0.0 to 1.0 (automatically clamped)
//   • lineWidth: thickness of the ring stroke
//   • foreground: ring color (supports gradients via default)
//   • background: track color (subtle by default)
//
// Technical Implementation:
//   • Uses Circle().trim() for progress arc
//   • Rotated -90° to start at top (12 o'clock position)
//   • Rounded line caps for polished appearance
//   • Automatic padding equal to lineWidth for consistent spacing
//
// Visual Design:
//   • Default gradient: blue to cyan for visual appeal
//   • Semi-transparent background track
//   • Equal white space padding around ring
//   • Scales proportionally with frame size

import SwiftUI

/// Circular progress ring component.
/// - Parameters:
///   - progress: 0.0 ... 1.0
///   - lineWidth: ring thickness
///   - gradient: optional custom gradient (defaults to blue/cyan)
///   - background: background ring color
struct CircularRing: View {
    var progress: Double
    var lineWidth: CGFloat = 20
    var gradient: LinearGradient? = nil
    var background: Color = Color.primary.opacity(0.08)

    var body: some View {
        let defaultGradient = LinearGradient(colors: [.blue, .cyan],
                                              startPoint: .topLeading,
                                              endPoint: .bottomTrailing)
        let effectiveGradient = gradient ?? defaultGradient
        ZStack {
            // Background ring
            Circle()
                .stroke(background, lineWidth: lineWidth)

            // Foreground progress ring
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(
                    effectiveGradient,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .rotationEffect(.degrees(-90)) // start at top
        }
        // Equal white space around equal to the ring thickness
        .padding(lineWidth)
    }
}
