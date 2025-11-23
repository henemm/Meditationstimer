//
//  CountdownOverlayView.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 22.11.25.
//

import SwiftUI

/// Overlay view showing a countdown before starting a session
/// Used across all tabs (Offen, Atem, Workouts, Frei)
struct CountdownOverlayView: View {
    let totalSeconds: Int
    let onComplete: () -> Void
    let onCancel: () -> Void

    @State private var remainingSeconds: Int
    @State private var progress: Double = 1.0
    @State private var timer: Timer?

    init(totalSeconds: Int, onComplete: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.totalSeconds = totalSeconds
        self.onComplete = onComplete
        self.onCancel = onCancel
        self._remainingSeconds = State(initialValue: totalSeconds)
    }

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Progress ring with countdown number
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(lineWidth: 8)
                        .foregroundStyle(.gray.opacity(0.3))

                    // Progress ring (counting down)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .foregroundStyle(.blue)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)

                    // Countdown number
                    Text("\(remainingSeconds)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.spring(duration: 0.3), value: remainingSeconds)
                }
                .frame(width: 180, height: 180)

                // Info text
                Text(NSLocalizedString("Get ready...", comment: "Countdown overlay info text"))
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))

                // Cancel button
                Button {
                    stopTimer()
                    onCancel()
                } label: {
                    HStack {
                        Image(systemName: "xmark")
                        Text(NSLocalizedString("Cancel", comment: "Countdown cancel button"))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 20)
            }
        }
        .onAppear {
            startCountdown()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func startCountdown() {
        remainingSeconds = totalSeconds
        progress = 1.0

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingSeconds > 1 {
                remainingSeconds -= 1
                progress = Double(remainingSeconds) / Double(totalSeconds)
            } else {
                stopTimer()
                onComplete()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    CountdownOverlayView(
        totalSeconds: 5,
        onComplete: { print("Completed") },
        onCancel: { print("Cancelled") }
    )
}
