//
//  WheelPicker.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 27.09.25.
//

import SwiftUI

struct WheelPicker: View {
    var label: String
    @Binding var selection: Int
    var range: ClosedRange<Int>
    var unit: String

    var body: some View {
        VStack {
            Text(label).font(.caption)
            Picker(selection: $selection, label: Text(label)) {
                ForEach(range, id: \.self) { value in
                    Text("\(value) \(unit)").tag(value)
                }
            }
            .pickerStyle(.wheel)
        }
    }
}
