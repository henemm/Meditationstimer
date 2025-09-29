//
//  WorkoutsView.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 27.09.25.
//

import SwiftUI

struct WorkoutsView: View {
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                VStack {
                    Spacer()
                    Text("Workouts – kommt demnächst")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Einstellungen")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
                    .presentationDetents([PresentationDetent.medium, PresentationDetent.large])
            }
        }
    }
}
