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
        NavigationView {
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
            .navigationTitle("Meditationstimer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
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
