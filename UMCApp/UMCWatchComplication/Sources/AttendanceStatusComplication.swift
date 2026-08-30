//
//  AttendanceStatusComplication.swift
//  UMCWatchComplication
//
//  Created by euijjang97 on 8/30/26.
//

import CoreWatchConnectivity
import CoreWatchDesignSystem
import SwiftUI
import WidgetKit

// MARK: - AttendanceStatusComplication

struct AttendanceStatusComplication: Widget {

    // MARK: - Body

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "UMCAttendanceStatus",
            provider: ComplicationProvider()
        ) { entry in
            AttendanceStatusComplicationView(entry: entry)
        }
        .configurationDisplayName("출석 상태")
        .description("다음 세션의 출석 상태를 확인합니다.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - AttendanceStatusComplicationView

struct AttendanceStatusComplicationView: View {

    // MARK: - Property

    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: ComplicationEntry

    private var state: ComplicationAttendanceState { entry.snapshot.attendance }

    /// 승인 대기 링 두께. 링은 색이 아니라 형태라, accented 모드에서 색이 치환돼도 살아남는다.
    private let pendingRingWidth: CGFloat = 2

    // MARK: - Body

    var body: some View {
        content
            .privacySensitive()
            .containerBackground(.clear, for: .widget)
    }

    // MARK: - Function

    @ViewBuilder
    private var content: some View {
        if entry.snapshot.isSignedIn {
            switch family {
            case .accessoryInline:      inline
            case .accessoryRectangular: rectangular
            default:                    circular
            }
        } else {
            ComplicationSignedOutView()
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            statusSymbol
                .font(.watch(.cardValue))
                .widgetAccentable()
        }
        .overlay {
            if state.hasPendingRing {
                Circle()
                    .strokeBorder(lineWidth: pendingRingWidth)
                    .complicationTint(state.fullColorTint, mode: renderingMode)
            }
        }
        .accessibilityLabel(state.shortLabel)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: WatchLayout.tightSpacing) {
            HStack(spacing: WatchLayout.tightSpacing) {
                statusSymbol
                    .widgetAccentable()
                Text(state.shortLabel)
                    .font(.watch(.cardValue))
            }
            if let session = entry.snapshot.nextSession {
                Text(session.name)
                    .font(.watch(.caption))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Label {
            Text(state.shortLabel)
        } icon: {
            Image(systemName: state.symbolName)
        }
    }

    private var statusSymbol: some View {
        Image(systemName: state.symbolName)
            .complicationTint(state.fullColorTint, mode: renderingMode)
    }
}
