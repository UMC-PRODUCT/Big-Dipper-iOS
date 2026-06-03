//
//  ChallengerMissionStatusIcon.swift
//  AppProduct
//
//  Created by jaewon Lee on 02/01/26.
//

import SwiftUI

// MARK: - ChallengerMissionStatusIcon

/// 미션 상태 아이콘 (미션 카드 좌측 상태 표시)
struct ChallengerMissionStatusIcon: View, Equatable {

    // MARK: - Property

    let status: MissionStatus
    let weekNumber: Int

    // MARK: - Equatable

    static func == (lhs: ChallengerMissionStatusIcon, rhs: ChallengerMissionStatusIcon) -> Bool {
        lhs.status == rhs.status &&
        lhs.weekNumber == rhs.weekNumber
    }

    // MARK: - Body

    var body: some View {
        iconView
            .frame(
                width: ActivityConstants.statusIconSize.width,
                height: ActivityConstants.statusIconSize.height)
    }

    // MARK: - View Components

    @ViewBuilder
    private var iconView: some View {
        switch status {
        case .pass:
            passIcon
        case .fail:
            failIcon
        case .inProgress:
            inProgressIcon
        case .locked:
            lockedIcon
        case .completed:
            completedIcon
        case .notStarted:
            notStartedIcon
        case .pendingApproval:
            pendingApprovalIcon
        }
    }

    private var completedIcon: some View {
        Image(systemName: "checkmark.circle.fill")
            .resizable()
            .foregroundStyle(status.missionListIconColor)
            .symbolDrawOn(isActive: true)
    }

    private var passIcon: some View {
        Image(systemName: "checkmark.circle.fill")
            .resizable()
            .foregroundStyle(status.missionListIconColor)
            .symbolDrawOn(isActive: true)
    }

    private var failIcon: some View {
        Image(systemName: "xmark.circle.fill")
            .resizable()
            .foregroundStyle(status.missionListIconColor)
    }

    private var inProgressIcon: some View {
        ZStack {
            Circle()
                .fill(status.missionListIconColor)

            Text("\(weekNumber)")
                .appFont(.caption1Emphasis, color: .white)
        }
    }

    private var lockedIcon: some View {
        Image(systemName: "lock.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(status.missionListIconColor)
    }

    private var notStartedIcon: some View {
        Circle()
            .strokeBorder(status.missionListIconColor, lineWidth: 2)
    }

    private var pendingApprovalIcon: some View {
        Image(systemName: "clock.fill")
            .resizable()
            .foregroundStyle(status.missionListIconColor)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ChallengerMissionStatusIcon - All States") {
    VStack(spacing: DefaultSpacing.spacing24) {
        ForEach(MissionStatus.allCases, id: \.self) { status in
            HStack(spacing: DefaultSpacing.spacing16) {
                ChallengerMissionStatusIcon(status: status, weekNumber: 3)
                    .equatable()

                Text(status.displayText)
                    .appFont(.callout, color: .grey900)

                Spacer()
            }
        }
    }
    .padding()
    .background(Color.grey100)
}

#Preview("ChallengerMissionStatusIcon - Week Numbers") {
    VStack(spacing: DefaultSpacing.spacing16) {
        ForEach(1...10, id: \.self) { week in
            HStack(spacing: DefaultSpacing.spacing12) {
                ChallengerMissionStatusIcon(status: .inProgress, weekNumber: week)
                    .equatable()

                Text("Week \(week)")
                    .appFont(.callout)

                Spacer()
            }
        }
    }
    .padding()
    .background(Color.grey100)
}

#Preview("ChallengerMissionStatusIcon - Card Context") {
    VStack(spacing: DefaultSpacing.spacing12) {
        // Pass
        HStack(spacing: DefaultSpacing.spacing12) {
            ChallengerMissionStatusIcon(status: .pass, weekNumber: 1)
            VStack(alignment: .leading) {
                Text("SpringBoot 워크북 1주차")
                    .appFont(.calloutEmphasis)
                Text("통과")
                    .appFont(.footnote, color: .grey500)
            }
            Spacer()
        }

        // In Progress
        HStack(spacing: DefaultSpacing.spacing12) {
            ChallengerMissionStatusIcon(status: .inProgress, weekNumber: 2)
            VStack(alignment: .leading) {
                Text("SpringBoot 워크북 2주차")
                    .appFont(.calloutEmphasis)
                Text("진행 중")
                    .appFont(.footnote, color: .grey500)
            }
            Spacer()
        }

        // Locked
        HStack(spacing: DefaultSpacing.spacing12) {
            ChallengerMissionStatusIcon(status: .locked, weekNumber: 3)
            VStack(alignment: .leading) {
                Text("SpringBoot 워크북 3주차")
                    .appFont(.calloutEmphasis)
                Text("잠김")
                    .appFont(.footnote, color: .grey500)
            }
            Spacer()
        }
    }
    .padding()
    .background(Color.white)
    .clipShape(RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius))
    .padding()
    .background(Color.grey100)
}

#Preview("ChallengerMissionStatusIcon - With Connector (ZStack)") {
    let iconSize: CGFloat = 28
    let connectorWidth: CGFloat = 2
    let connectorLeading: CGFloat = 13

    ZStack(alignment: .topLeading) {
        // 배경: 연결선
        Rectangle()
            .fill(Color.grey300)
            .frame(width: connectorWidth)
            .padding(.leading, connectorLeading)
            .padding(.top, iconSize / 2)
            .padding(.bottom, iconSize / 2)

        // 전경: 아이콘 리스트
        VStack(spacing: DefaultSpacing.spacing16) {
            ChallengerMissionStatusIcon(status: .pass, weekNumber: 1)
            ChallengerMissionStatusIcon(status: .fail, weekNumber: 2)
            ChallengerMissionStatusIcon(status: .inProgress, weekNumber: 3)
            ChallengerMissionStatusIcon(status: .locked, weekNumber: 4)
            ChallengerMissionStatusIcon(status: .locked, weekNumber: 5)
        }
    }
    .padding()
    .background(Color.grey100)
}
#endif
