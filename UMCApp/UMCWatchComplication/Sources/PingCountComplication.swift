//
//  PingCountComplication.swift
//  UMCWatchComplication
//
//  Created by euijjang97 on 8/30/26.
//

import CoreWatchConnectivity
import CoreWatchDesignSystem
import SwiftUI
import WidgetKit

// MARK: - PingCountComplication

struct PingCountComplication: Widget {

    // MARK: - Body

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UMCPingCount", provider: ComplicationProvider()) { entry in
            PingCountComplicationView(entry: entry)
        }
        .configurationDisplayName("미확인 공지")
        .description("아직 확인하지 않은 공지 개수를 확인합니다.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - PingCountComplicationView

struct PingCountComplicationView: View {

    // MARK: - Property

    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: ComplicationEntry

    /// 워치페이스 지름 안에서 잘리지 않는 상한. 넘으면 정확한 수보다 「많다」가 더 쓸모 있다.
    private let displayLimit = 99

    private var count: Int { entry.snapshot.unreadPingCount }

    private var countText: String { count > displayLimit ? "\(displayLimit)+" : "\(count)" }

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

    @ViewBuilder
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if count > 0 {
                Text(countText)
                    .font(.watch(.metric))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .complicationTint(WatchColor.brandAccent, mode: renderingMode)
                    .widgetAccentable()
                    .accessibilityLabel("미확인 공지 \(countText)")
            } else {
                Image(systemName: "bell")
                    .font(.watch(.cardValue))
                    .widgetAccentable()
                    .accessibilityLabel("미확인 공지 없음")
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: WatchLayout.tightSpacing) {
            Label {
                Text(count > 0 ? "미확인 공지 \(countText)" : "미확인 공지 없음")
                    .font(.watch(.cardValue))
            } icon: {
                Image(systemName: count > 0 ? "bell.badge" : "bell")
                    .complicationTint(WatchColor.brandAccent, mode: renderingMode)
                    .widgetAccentable()
            }
            // 워치는 서버를 직접 폴링하지 않는다. 값이 언제 기준인지 보여 줘야 사용자가
            // 「0인데 실제로는 새 공지가 있다」를 오해하지 않는다.
            Text("\(entry.snapshot.generatedAt, style: .relative) 기준")
                .font(.watch(.caption))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Label {
            Text(count > 0 ? "미확인 \(countText)" : "미확인 없음")
        } icon: {
            Image(systemName: count > 0 ? "bell.badge" : "bell")
        }
    }
}
