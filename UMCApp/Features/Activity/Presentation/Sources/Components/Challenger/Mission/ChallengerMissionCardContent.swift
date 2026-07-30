//
//  ChallengerMissionCardContent.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/15/26.
//

import SwiftUI
import ActivityDomain
import CoreDesignSystem
import CoreUIComponents

// MARK: - ChallengerMissionCardContent

/// 미션 카드 확장 콘텐츠 (미션 설명, 상태 결과 표시)
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
            case .locked, .completed:
                EmptyView()
            }
        }
    }

    // MARK: - Private Views

    private var missionTitleText: some View {
        Text(model.missionTitle)
            .appFont(.subheadline, color: .grey600)
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
            color: .orange500
        )
    }

    private var passView: some View {
        MissionStatusResultView(
            icon: "checkmark.circle.fill",
            message: "미션을 통과하였습니다.",
            color: .green500,
            drawsOnAppear: true
        )
    }

    private var failView: some View {
        MissionStatusResultView(
            icon: "xmark.circle.fill",
            message: "미션을 통과하지 못했습니다.",
            color: .red500
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
                        .appFont(.title3, color: .grey600)
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
    /// `true`이면 등장 시 아이콘에 draw-on 애니메이션을 적용합니다. (통과 등 긍정 상태 전용)
    var drawsOnAppear: Bool = false

    private enum Constants {

        static let backgroundOpacity: Double = 0.15
    }

    // MARK: - Body

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .symbolDrawOn(isActive: drawsOnAppear)
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
