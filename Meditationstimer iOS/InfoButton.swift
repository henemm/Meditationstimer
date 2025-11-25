//
//  InfoButton.swift
//  Lean Health Timer
//
//  Created by Claude on 13.11.2025.
//

import SwiftUI

/// Reusable info button component that displays an info icon
/// Used throughout the app to trigger info sheets with explanatory content
struct InfoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .font(.title3)
        }
    }
}

#Preview {
    InfoButton {
        print("Info tapped")
    }
}
