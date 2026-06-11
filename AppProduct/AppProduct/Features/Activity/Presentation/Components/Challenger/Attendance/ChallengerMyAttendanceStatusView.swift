//
//  ChallengerMyAttendanceStatusView.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/22/26.
//

import SwiftUI

// MARK: - ChallengerMyAttendanceStatusView

/// 나의 출석 현황 섹션
///
/// 카드를 탭하면 출석 정책/장소 상세가 펼쳐지며,
/// 출석 가능한 세션 목록과 동일하게 한 번에 하나만 펼쳐지는 아코디언으로 동작합니다.
struct ChallengerMyAttendanceStatusView: View {
    // MARK: - Property

    private let models: [MyAttendanceItemModel]

    /// 현재 펼쳐진 카드 (아코디언 — 한 번에 하나만)
    @State private var expandedItemId: MyAttendanceItemModel.ID?

    // MARK: - Init

    /// History API 데이터로 초기화
    init(historyItems: [ScheduleDetailData]) {
        self.models = historyItems.compactMap {
            MyAttendanceItemModel(from: $0)
        }
    }

    /// 변환이 끝난 표시 모델로 초기화
    ///
    /// 호출 측에서 빈 상태 분기를 위해 모델 개수를 먼저 알아야 할 때 사용합니다.
    init(models: [MyAttendanceItemModel]) {
        self.models = models
    }

    // MARK: - Constant

    private enum Constant {
        static let listSpacing: CGFloat = 0
        static let animationResponse: Double = 0.35
        static let animationDamping: Double = 0.8
    }


    // MARK: - Body

    var body: some View {
        attendanceList
    }

    private var attendanceList: some View {
        LazyVStack(spacing: Constant.listSpacing) {
            ForEach(models, id: \.id) { model in
                ChallengerMyAttendanceCard(
                    model: model,
                    isExpanded: expandedItemId == model.id
                ) {
                    withAnimation(.spring(Spring(
                        response: Constant.animationResponse,
                        dampingRatio: Constant.animationDamping
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
        .clipShape(ConcentricRectangle(corners: .concentric(minimum: DefaultConstant.concentricRadius), isUniform:  true))
        .glass()
    }
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    ZStack {
        Color.grey100.ignoresSafeArea()

        ChallengerMyAttendanceStatusView(
            historyItems: [
                ScheduleDetailData(
                    scheduleId: 1,
                    name: "정기 세션",
                    description: "",
                    tags: ["STUDY"],
                    startsAt: Calendar.current.date(
                        bySettingHour: 14, minute: 0, second: 0,
                        of: Date()
                    ) ?? Date(),
                    endsAt: Calendar.current.date(
                        bySettingHour: 16, minute: 0, second: 0,
                        of: Date()
                    ) ?? Date(),
                    location: nil,
                    participants: [],
                    authorMemberId: 1,
                    attendancePolicy: nil,
                    attendanceStatus: .present,
                    isAttendanceChecked: true,
                    isOnline: false,
                    isParticipant: true
                )
            ]
        )
    }
    .frame(height: 600)
}
