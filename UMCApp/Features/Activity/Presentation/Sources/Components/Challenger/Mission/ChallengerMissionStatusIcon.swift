//
//  ChallengerMissionStatusIcon.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/15/26.
//

import SwiftUI
import ActivityDomain
import CoreDesignSystem
import CoreUIComponents

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
                .appFont(.caption1, weight: .semibold, color: .white)
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
#endif
