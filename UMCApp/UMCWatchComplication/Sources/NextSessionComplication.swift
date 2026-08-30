//
//  NextSessionComplication.swift
//  UMCWatchComplication
//
//  Created by euijjang97 on 8/30/26.
//

import CoreWatchConnectivity
import CoreWatchDesignSystem
import SwiftUI
import WidgetKit

// MARK: - NextSessionComplication

struct NextSessionComplication: Widget {

    // MARK: - Body

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UMCNextSession", provider: ComplicationProvider()) { entry in
            NextSessionComplicationView(entry: entry)
        }
        .configurationDisplayName("다음 세션")
        .description("가장 가까운 세션까지 남은 시간을 확인합니다.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - NextSessionComplicationView

struct NextSessionComplicationView: View {

    // MARK: - Property

    @Environment(\.widgetFamily) private var family

    let entry: ComplicationEntry

    private var session: ComplicationSession? { entry.snapshot.nextSession }

    /// 진행 중이면 종료까지, 아니면 시작까지를 링으로 그린다.
    /// 역전된 구간(`start >= end`)은 `ClosedRange` 생성 자체가 트랩이라 `nil` 로 떨군다.
    private var countdownRange: ClosedRange<Date>? {
        guard let session else { return nil }
        let isInProgress = session.isInProgress(now: entry.date)
        let start = isInProgress ? session.startsAt : entry.date
        let end = isInProgress ? session.endsAt : session.startsAt
        guard start < end else { return nil }
        return start...end
    }

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
            if let countdownRange {
                // 카운트다운 숫자로 타임라인 엔트리를 늘리지 않는다 — 링과 숫자 모두
                // 시스템이 스스로 갱신한다.
                ProgressView(timerInterval: countdownRange, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    Text(countdownRange.upperBound, style: .timer)
                        .font(.watch(.caption))
                        .minimumScaleFactor(0.5)
                        .widgetAccentable()
                }
                .progressViewStyle(.circular)
            } else {
                Image(systemName: "calendar")
                    .font(.watch(.cardValue))
                    .widgetAccentable()
                    .accessibilityLabel("예정된 세션 없음")
            }
        }
    }

    @ViewBuilder
    private var rectangular: some View {
        if let session {
            VStack(alignment: .leading, spacing: WatchLayout.tightSpacing) {
                Text(session.name)
                    .font(.watch(.cardLabel))
                    .lineLimit(1)
                Text(session.startsAt, style: .relative)
                    .font(.watch(.cardValue))
                    .widgetAccentable()
                Text(session.startsAt, format: .dateTime.hour().minute())
                    .font(.watch(.caption))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Label("예정된 세션 없음", systemImage: "calendar")
                .font(.watch(.cardLabel))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var inline: some View {
        if let session {
            Label {
                Text("\(session.name) · \(session.startsAt.formatted(.dateTime.hour().minute()))")
            } icon: {
                Image(systemName: "calendar")
            }
        } else {
            Label("예정된 세션 없음", systemImage: "calendar")
        }
    }
}
