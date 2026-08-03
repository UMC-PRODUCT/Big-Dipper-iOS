//
//  StudyManagementWeekRow.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/3/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import SwiftUI

// MARK: - StudyManagementWeekRow

/// 제출 현황 카드 안의 주차 행
///
/// 스터디원 1명의 특정 주차 워크북 상태를 한 줄로 보여줍니다.
/// 워크북이 배포되지 않은 주차(``StudyManagementItem/canOpenDetail`` == `false`)는 상세가
/// 없으므로 탭을 막고 시각적으로도 흐리게 표시합니다.
///
/// - Note: 레거시 `CoreStudyManagementList` 를 이식하면서 이름을 바꿨습니다. 원본은 항목
///   **한 개**를 그리는데 이름이 `List` 라 역할과 어긋났습니다.
struct StudyManagementWeekRow: View {

    // MARK: - Constants

    fileprivate enum Constants {
        static let verticalPadding: CGFloat = 8
        static let disabledOpacity: Double = 0.55
        static let chevronWidth: CGFloat = 6
        static let chevronHeight: CGFloat = 10
    }

    // MARK: - Property

    /// 주차 행 정보
    let item: StudyManagementItem

    /// 워크북 상세 진입 액션 — 미배포 주차에서는 호출되지 않습니다.
    let onSelect: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: onSelect) {
            StudyManagementWeekRowContent(item: item)
                .equatable()
        }
        .buttonStyle(.plain)
        .disabled(!item.canOpenDetail)
        .opacity(item.canOpenDetail ? 1 : Constants.disabledOpacity)
        .accessibilityHint(item.canOpenDetail ? "워크북 상세 보기" : "아직 워크북이 배포되지 않았어요")
    }
}

// MARK: - StudyManagementWeekRowContent

/// 주차 행의 표시 전용 본문 (클로저를 비교에서 제외하기 위한 Presenter)
private struct StudyManagementWeekRowContent: View, Equatable {

    // MARK: - Property

    let item: StudyManagementItem

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Text(item.title)
                .appFont(.footnote, color: .grey700)
                .lineLimit(1)

            if item.isBest {
                InfoBadge(
                    "베스트",
                    textColor: .orange500,
                    tintColor: .orange500
                )
            }

            Spacer(minLength: DefaultSpacing.spacing8)

            statusLabel

            if item.canOpenDetail {
                Image(systemName: "chevron.right")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: StudyManagementWeekRow.Constants.chevronWidth,
                        height: StudyManagementWeekRow.Constants.chevronHeight
                    )
                    .foregroundStyle(Color.grey400)
            }
        }
        .padding(.vertical, StudyManagementWeekRow.Constants.verticalPadding)
        .contentShape(.rect)
    }

    // MARK: - View Components

    private var statusLabel: some View {
        Label(item.state.displayText, systemImage: item.state.badgeIcon)
            .appFont(.caption1, color: .grey900)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(item.state.badgeColor)
            .lineLimit(1)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("주차 행", traits: .sizeThatFitsLayout) {
    VStack(spacing: 0) {
        ForEach(OperatorStudyPreviewData.submissions.flatMap(\.managementItems)) { item in
            StudyManagementWeekRow(item: item, onSelect: {})
        }
    }
    .padding()
}
#endif
