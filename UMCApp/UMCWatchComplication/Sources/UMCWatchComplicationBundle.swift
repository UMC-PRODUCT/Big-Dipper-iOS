//
//  UMCWatchComplicationBundle.swift
//  UMCWatchComplication
//
//  Created by euijjang97 on 8/30/26.
//

import SwiftUI
import WidgetKit

@main
struct UMCWatchComplicationBundle: WidgetBundle {
    var body: some Widget {
        NextSessionComplication()
        AttendanceStatusComplication()
        PingCountComplication()
    }
}
