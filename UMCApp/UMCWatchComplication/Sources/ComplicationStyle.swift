//
//  ComplicationStyle.swift
//  UMCWatchComplication
//
//  Created by euijjang97 on 8/30/26.
//

import CoreWatchConnectivity
import CoreWatchDesignSystem
import SwiftUI
import WidgetKit

// MARK: - ComplicationAttendanceState + Tint

extension ComplicationAttendanceState {

    /// `.fullColor` 워치페이스에서만 쓰는 색.
    ///
    /// `.pending`(승인 대기)과 `.excused`(공결)가 같은 중립색인 것은 의도다 — 스펙상 둘 다
    /// 「확정되지 않았거나 예외」 축이라 색으로 갈리지 않는다. 구분은 심볼과 링이 맡는다.
    var fullColorTint: Color {
        switch self {
        case .none, .upcoming:  WatchColor.textSecondary
        case .awaiting:         WatchColor.brandPrimaryHighlight
        case .pending, .excused: WatchColor.statusPending
        case .present:          WatchColor.statusSuccess
        case .late:             WatchColor.statusWarning
        case .absent:           WatchColor.statusError
        }
    }
}

// MARK: - View + complicationTint

extension View {

    /// `.accented`·`.vibrant` 에서는 시스템이 색을 다시 칠한다. 그때 커스텀 색을 넘기면
    /// 치환 대상이 하나로 뭉개져 강조 계층만 사라지므로 `.primary` 를 준다.
    func complicationTint(_ color: Color, mode: WidgetRenderingMode) -> some View {
        foregroundStyle(mode == .fullColor ? color : Color.primary)
    }
}

// MARK: - ComplicationSignedOutView

/// 로그아웃(또는 아직 한 번도 동기화되지 않음) 상태의 공통 표시.
///
/// 3종이 같은 문구를 그려야 사용자가 「워치가 고장난 게 아니라 iPhone 에서 로그인해야 한다」를
/// 한 번에 안다. 워치는 스스로 로그인할 수 없다.
struct ComplicationSignedOutView: View {

    // MARK: - Property

    @Environment(\.widgetFamily) private var family

    private let message = "iPhone 로그인 필요"
    private let symbolName = "person.slash"

    // MARK: - Body

    var body: some View {
        switch family {
        case .accessoryInline:
            Label(message, systemImage: symbolName)
        case .accessoryRectangular:
            HStack(spacing: WatchLayout.tightSpacing) {
                Image(systemName: symbolName)
                    .widgetAccentable()
                Text(message)
                    .font(.watch(.cardLabel))
                    .lineLimit(2)
            }
        default:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: symbolName)
                    .font(.watch(.cardValue))
                    .widgetAccentable()
            }
        }
    }
}
