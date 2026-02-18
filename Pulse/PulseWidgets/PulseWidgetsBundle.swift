//
//  PulseWidgetsBundle.swift
//  PulseWidgets
//
//  Created by Joshua Costanza on 2/3/26.
//

import WidgetKit
import SwiftUI

@main
struct PulseWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PulseWidgets()
        PulseWidgetsControl()
        PulseWidgetsLiveActivity()
    }
}
