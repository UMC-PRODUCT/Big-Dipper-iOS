//
//  ChallengerMyAttendanceStatusView.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/2/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import SwiftUI

// MARK: - ChallengerMyAttendanceStatusView

/// 나의 출석 현황 섹션
///
/// 카드를 탭하면 출석 정책/장소 상세가 펼쳐지며,
/// 출석 가능한 세션 목록과 동일하게 한 번에 하나만 펼쳐지는 아코디언으로 동작합니다.
///
/// - Note: 레거시에는 일정 상세 페이로드를 그대로 받는 이니셜라이저도 있었으나,
///   해당 타입(`ScheduleDetailData`)은 Home 도메인 소유라 Activity 모듈에서 참조할 수
///   없습니다. 변환은 호출부가 담당하고 여기서는 표시 모델만 받습니다 — 호출부가 빈 상태
///   분기를 위해 어차피 변환 결과 개수를 먼저 알아야 하므로 책임 배치도 여기가 맞습니다.
struct ChallengerMyAttendanceStatusView: View {

    // MARK: - Property

    private let models: [MyAttendanceItemModel]

    /// 현재 펼쳐진 카드 (아코디언 — 한 번에 하나만)
    @State private var expandedItemId: MyAttendanceItemModel.ID?

    // MARK: - Init

    init(models: [MyAttendanceItemModel]) {
        self.models = models
    }

    // MARK: - Constants

    fileprivate enum Constants {
        static let listSpacing: CGFloat = 0
        static let animationResponse: Double = 0.35
        static let animationDamping: Double = 0.8
    }

    // MARK: - Body

    var body: some View {
        LazyVStack(spacing: Constants.listSpacing) {
            ForEach(models) { model in
                ChallengerMyAttendanceCard(
                    model: model,
                    isExpanded: expandedItemId == model.id
                ) {
                    withAnimation(.spring(Spring(
                        response: Constants.animationResponse,
                        dampingRatio: Constants.animationDamping
                    ))) {
                        expandedItemId = expandedItemId == model.id ? nil : model.id
                    }
                }

                // 마지막 아이템이 아닐 때만 Divider
                if model.id != models.last?.id {
                    Divider()
                }
            }
        }
        .clipShape(ConcentricRectangle(
            corners: .concentric(minimum: DefaultConstant.concentricRadius),
            isUniform: true
        ))
        .cardShadow()
    }
}

#if DEBUG
// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    ZStack {
        Color.grey100.frame(height: 600)

        ChallengerMyAttendanceStatusView(
            models: AttendancePreviewData.myAttendanceItems
        )
        .padding()
    }
}
#endif
