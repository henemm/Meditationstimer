//
//  MeditationstimerWidgetBundle.swift
//  MeditationstimerWidget
//
//  Created by Henning Emmrich on 12.09.25.
//

import WidgetKit
import SwiftUI

@main
struct MeditationstimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        MeditationstimerWidget()
        MeditationstimerWidgetControl()
        MeditationstimerWidgetLiveActivity()
    }
}
