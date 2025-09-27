
//
//  GlassCard.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 27.09.25.
//

import SwiftUI

struct GlassCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
    }
}

