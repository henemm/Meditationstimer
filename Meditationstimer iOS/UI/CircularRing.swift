import SwiftUI

/// Circular progress ring component.
/// - Parameters:
///   - progress: 0.0 ... 1.0
///   - lineWidth: ring thickness
///   - foreground: foreground ring color
///   - background: background ring color
struct CircularRing: View {
    var progress: Double
    var lineWidth: CGFloat = 20
    var foreground: Color = .blue
    var background: Color = Color.primary.opacity(0.08)

    var body: some View {
        let gradient = LinearGradient(colors: [.blue, .cyan],
                                      startPoint: .topLeading,
                                      endPoint: .bottomTrailing)
        ZStack {
            // Background ring
            Circle()
                .stroke(background, lineWidth: lineWidth)

            // Foreground progress ring
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(
                    gradient,
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
