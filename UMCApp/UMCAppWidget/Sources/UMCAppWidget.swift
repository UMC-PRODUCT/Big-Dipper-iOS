//
//  UMCAppWidget.swift
//  UMCAppWidget
//
//  Created by euijjang97 on 4/23/26.
//

import WidgetKit
import SwiftUI

struct UMCHomeWidget: Widget {
    let kind: String = "UMCHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UMCHomeWidgetProvider()) { entry in
            UMCHomeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("UMC")
        .description("UMC 동아리 정보를 홈 화면에서 확인하세요.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
