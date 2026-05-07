//
//  ChallengerMyAttendanceStatusView.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/22/26.
//

import SwiftUI

// MARK: - ChallengerMyAttendanceStatusView

/// 나의 출석 현황 섹션
struct ChallengerMyAttendanceStatusView: View {
    // MARK: - Property

    private let models: [MyAttendanceItemModel]

    // MARK: - Init

    /// History API 데이터로 초기화
    init(historyItems: [ScheduleDetailData]) {
        self.models = historyItems.compactMap {
            MyAttendanceItemModel(from: $0)
        }
    }
    
    // MARK: - Constant

    private enum Constant {
        static let listSpacing: CGFloat = 0
    }


    // MARK: - Body

    var body: some View {
        attendanceList
    }
    
    private var attendanceList: some View {
        LazyVStack(spacing: Constant.listSpacing) {
            ForEach(models, id: \.id) { model in
                ChallengerMyAttendanceCard(model: model)

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
