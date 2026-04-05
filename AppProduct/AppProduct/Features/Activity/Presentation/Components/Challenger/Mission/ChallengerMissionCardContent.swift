//
//  ChallengerMissionCardContent.swift
//  AppProduct
//
//  Created by jaewon Lee on 01/29/26.
//

import SwiftUI

// MARK: - ChallengerMissionCardContent

/// 미션 카드 확장 콘텐츠 (미션 설명, 제출 타입 선택, 링크 입력/제출 버튼)
struct ChallengerMissionCardContent: View, Equatable {

    // MARK: - Property

    let model: MissionCardModel

    static func == (lhs: ChallengerMissionCardContent, rhs: ChallengerMissionCardContent) -> Bool {
        lhs.model == rhs.model
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
            switch model.status {
            case .notStarted, .inProgress:
                EmptyView()
            case .pendingApproval, .pass, .fail:
                missionTitleText
                statusResultView
            case .locked:
                EmptyView()
            }
        }
    }

    // MARK: - Private Views

    private var missionTitleText: some View {
        Text(model.missionTitle)
            .appFont(.subheadline, color: .gray)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var statusResultView: some View {
        switch model.status {
        case .pendingApproval:
            pendingApprovalView
        case .pass:
            passView
        case .fail:
            failView
        default:
            EmptyView()
        }
    }

    private var pendingApprovalView: some View {
        MissionStatusResultView(
            icon: "hourglass",
            message: "확인 대기 중입니다.",
            color: .orange
        )
    }

    private var passView: some View {
        MissionStatusResultView(
            icon: "checkmark.circle.fill",
            message: "미션을 통과하였습니다.",
            color: .green
        )
    }

    private var failView: some View {
        MissionStatusResultView(
            icon: "xmark.circle.fill",
            message: "미션을 통과하지 못했습니다.",
            color: .red
        )
    }
    
}

// MARK: - Preview

#if DEBUG
#Preview("ChallengerMissionCardContent - InProgress", traits: .sizeThatFitsLayout) {
    ZStack {
        Color.grey100.ignoresSafeArea().frame(height: 400)
        ChallengerMissionCardContent(model: MissionPreviewData.singleMission)
            .glass()
    }
}

#Preview("ChallengerMissionCardContent - All Status") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(MissionPreviewData.allStatusMissions) { model in
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.status.displayText)
                        .appFont(.title3, color: .gray)
                    ChallengerMissionCardContent(model: model)
                        .padding()
                        .background(Color.grey000)
                        .clipShape(RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius))
                }
            }
        }
        .padding()
    }
    .background(Color.grey100)
}
#endif

// MARK: - MissionStatusResultView

/// 미션 상태 결과 뷰 (아이콘 + 메시지 + 배경)
fileprivate struct MissionStatusResultView: View, Equatable {

    // MARK: - Property

    let icon: String
    let message: String
    let color: Color

    private enum Constants {

        static let backgroundOpacity: Double = 0.15
    }

    // MARK: - Body

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(message)
                .appFont(.callout, color: color)
        }
        .padding(ActivityConstants.statusCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            color.opacity(Constants.backgroundOpacity),
            in: RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius)
        )
    }
}

