//
//  MemberManagementCard.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/15/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import SwiftUI
import UMCFoundation

// MARK: - MemberManagementCard

/// 멤버 관리 리스트에서 사용하는 카드 뷰입니다.
///
/// 프로필 이미지, 이름·기수·직책·파트, 상벌점 배지, chevron 을 가로로 배치합니다.
/// 운영진 멤버 관리 화면(후속 이슈)에서 공유하는 컴포넌트입니다.
struct MemberManagementCard: View, Equatable {

    // MARK: - Property

    let memberManagementItem: MemberManagementItem

    // MARK: - Constants

    fileprivate enum Constants {
        static let hstackSpacing: CGFloat = 15
        static let chevronSize: CGSize = .init(width: 4, height: 8)
        static let innerPadding: CGFloat = 16
        static let radius: CGFloat = 14
        static let strokeWidth: CGFloat = 1
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: Constants.hstackSpacing) {
            MemberImagePresenter(memberManagementItem: memberManagementItem)
            MemberTextPresenter(memberManagementItem: memberManagementItem)
            Spacer()
            MemberPenaltyPresenter(memberManagementItem: memberManagementItem)
            Image(systemName: "chevron.right")
                .resizable()
                .frame(
                    width: Constants.chevronSize.width,
                    height: Constants.chevronSize.height
                )
                .foregroundStyle(Color.grey400)
        }
        .padding(Constants.innerPadding)
        .background {
            RoundedRectangle(cornerRadius: Constants.radius)
                .strokeBorder(Color.grey200, lineWidth: Constants.strokeWidth)
        }
    }
}

// MARK: - MemberImagePresenter

/// 프로필 사진과 선물 상자 배지를 표시합니다.
///
/// ``CoreMemberManagementList`` 에서도 사용하는 공유 컴포넌트입니다.
struct MemberImagePresenter: View, Equatable {

    // MARK: - Property

    let memberManagementItem: MemberManagementItem

    // MARK: - Constants

    fileprivate enum Constants {
        static let imageSize: CGSize = .init(width: 40, height: 40)
    }

    // MARK: - Body

    var body: some View {
        RemoteImage(
            urlString: memberManagementItem.profile ?? "",
            size: Constants.imageSize
        )
        .clipShape(Circle())
        .aspectRatio(contentMode: .fit)
        .overlay(alignment: .topTrailing) {
            if memberManagementItem.badge {
                MemberBadgePresenter()
            }
        }
    }
}

// MARK: - MemberTextPresenter

/// 멤버 이름·기수·직책·파트 텍스트를 세로로 배치합니다.
private struct MemberTextPresenter: View, Equatable {

    // MARK: - Property

    let memberManagementItem: MemberManagementItem

    // MARK: - Constants

    fileprivate enum Constants {
        static let vstackSpacing: CGFloat = 2
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.vstackSpacing) {
            MemberTopTextPresenter(memberManagementItem: memberManagementItem)
            MemberBottomTextPresenter(memberManagementItem: memberManagementItem)
        }
    }
}

// MARK: - MemberTopTextPresenter

/// 멤버 이름과 기수를 표시합니다.
private struct MemberTopTextPresenter: View, Equatable {

    // MARK: - Property

    let memberManagementItem: MemberManagementItem

    // MARK: - Constants

    fileprivate enum Constants {
        static let rectangleSize: CGSize = .init(width: 1, height: 16)
    }

    // MARK: - Body

    var body: some View {
        HStack {
            Text(memberManagementItem.name)
                .appFont(.callout, weight: .semibold)

            Rectangle()
                .frame(
                    width: Constants.rectangleSize.width,
                    height: Constants.rectangleSize.height
                )
                .foregroundStyle(Color.grey300)

            Text(memberManagementItem.generation)
                .font(.app(.subheadline, weight: .regular))
                .foregroundStyle(Color.grey900)
        }
    }
}

// MARK: - MemberBottomTextPresenter

/// 멤버 직책과 파트를 표시합니다.
private struct MemberBottomTextPresenter: View, Equatable {

    // MARK: - Property

    let memberManagementItem: MemberManagementItem

    // MARK: - Body

    var body: some View {
        HStack {
            Text(memberManagementItem.position)
                .font(.app(.subheadline, weight: .regular))
                .foregroundStyle(Color.grey500)

            Text(memberManagementItem.part.name)
                .font(.app(.subheadline, weight: .regular))
                .foregroundStyle(Color.grey500)
        }
    }
}

// MARK: - MemberPenaltyPresenter

/// 상점·벌점 배지를 표시합니다. 값이 0 이하인 배지는 숨깁니다.
private struct MemberPenaltyPresenter: View, Equatable {

    // MARK: - Property

    let memberManagementItem: MemberManagementItem

    // MARK: - Constants

    fileprivate enum Constants {
        static let hstackSpacing: CGFloat = 4
        static let horizonSpacing: CGFloat = 8
        static let verticalSpacing: CGFloat = 4
        static let radius: CGFloat = 8
        static let strokeWidth: CGFloat = 0.5
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: Constants.hstackSpacing) {
            if memberManagementItem.rewardPoints > 0 {
                pointBadge(
                    label: "상점",
                    value: memberManagementItem.rewardPoints,
                    fgColor: .green,
                    bgColor: Color.green.opacity(0.1),
                    borderColor: Color.green.opacity(0.3)
                )
            }
            if memberManagementItem.penalty > 0 {
                pointBadge(
                    label: "벌점",
                    value: memberManagementItem.penalty,
                    fgColor: Color.red700,
                    bgColor: Color.red100,
                    borderColor: Color.red300
                )
            }
        }
    }

    // MARK: - Function

    private func pointBadge(
        label: String,
        value: Double,
        fgColor: Color,
        bgColor: Color,
        borderColor: Color
    ) -> some View {
        HStack(spacing: 3) {
            Text(label)
            Text(String(format: "%.0f", value))
        }
        .appFont(.footnote, weight: .semibold)
        .foregroundStyle(fgColor)
        .padding(.horizontal, Constants.horizonSpacing)
        .padding(.vertical, Constants.verticalSpacing)
        .background {
            RoundedRectangle(cornerRadius: Constants.radius)
                .fill(bgColor)
                .strokeBorder(borderColor, lineWidth: Constants.strokeWidth)
        }
    }
}

// MARK: - MemberBadgePresenter

/// 선물 상자 배지입니다. 프로필 이미지 우상단에 겹쳐 표시합니다.
private struct MemberBadgePresenter: View, Equatable {

    // MARK: - Constants

    fileprivate enum Constants {
        static let imageSize: CGFloat = 10
        static let innerPadding: CGFloat = 3
        static let strokeWidth: CGFloat = 2
    }

    // MARK: - Body

    var body: some View {
        Image(systemName: "gift")
            .font(.system(size: Constants.imageSize))
            .padding(Constants.innerPadding)
            .background {
                Circle()
                    .fill(Color.yellow300)
                    .stroke(Color.white, lineWidth: Constants.strokeWidth)
            }
    }
}

// MARK: - Preview

#if DEBUG
#Preview(traits: .sizeThatFitsLayout) {
    VStack {
        MemberManagementCard(
            memberManagementItem: MemberManagementItem(
                profile: nil,
                name: "이예지",
                nickname: "소피",
                generation: "8기",
                school: "가천대학교",
                position: "Challenger",
                part: .front(type: .ios),
                penalty: 0,
                badge: true,
                managementTeam: .challenger,
                attendanceRecords: [],
                penaltyHistory: []
            )
        )

        MemberManagementCard(
            memberManagementItem: MemberManagementItem(
                profile: nil,
                name: "이예지",
                nickname: "소피",
                generation: "8기",
                school: "가천대학교",
                position: "Challenger",
                part: .front(type: .ios),
                penalty: 2,
                rewardPoints: 3,
                badge: false,
                managementTeam: .challenger,
                attendanceRecords: [],
                penaltyHistory: []
            )
        )
    }
    .padding()
}
#endif
