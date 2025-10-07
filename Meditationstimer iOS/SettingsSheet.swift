//
//  SettingsSheet.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 27.09.25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Gemeinsames Einstellungs‑Sheet für alle Tabs.
struct SettingsSheet: View {
    @AppStorage("soundEnabled") private var soundEnabled: Bool = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("logWorkoutsAsMindfulness") private var logWorkoutsAsMindfulness: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section("Feedback") {
                    Toggle("Ton (iPhone)", isOn: $soundEnabled)
                    Toggle("Haptik (Watch)", isOn: $hapticsEnabled)
                }
                Section("Entwickler") {
                    Toggle("Workouts als Mindfulness loggen (Debug)", isOn: $logWorkoutsAsMindfulness)
                        .tint(.blue)
                }
                #if os(iOS)
                Section {
                    Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                        Label("System‑Einstellungen öffnen", systemImage: "gearshape")
                    }
                }
                #endif
            }
            .navigationTitle("Einstellungen")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
