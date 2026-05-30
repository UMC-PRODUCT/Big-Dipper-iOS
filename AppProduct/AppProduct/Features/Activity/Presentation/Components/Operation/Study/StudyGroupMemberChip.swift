//
//  StudyGroupMemberChip.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/9/26.
//

import SwiftUI

/// 스터디 그룹 멤버 칩
///
/// 프로필 아바타와 이름을 표시하는 컴팩트 뷰입니다.
struct StudyGroupMemberChip: View, Equatable {
    // MARK: - Constants
    fileprivate enum Constants {
        static let avatarSize: CGFloat = 22
        static let avatarCornerRadius: CGFloat = 0
        static let avatarPlaceholderImageName: String = "person.fill"
        static let bestBorderWidth: CGFloat = 1
        static let bestPointThreshold: Int = 0
        /// 칩 corner radius — Nested Material/Glass 환경에서 ConcentricRectangle inheritance가
        /// 끊기는 문제가 있어 명시 cornerRadius로 곡률을 직접 보장한다.
        static let chipCornerRadius: CGFloat = 16
        static let chipHeight: CGFloat = 68
        static let chipHorizontalPadding: CGFloat = 6
        static let chipVerticalPadding: CGFloat = 6
        static let nameLineLimit: Int = 1
        static let nameMinimumScaleFactor: CGFloat = 0.8
        static let bestIconSize: CGFloat = 12
        static let bestIconContainerSize: CGFloat = 22
        static let bestIconOverlapOffset: CGFloat = 7
        static let bestIconSystemName: String = "trophy.fill"
        static let baseTintOpacity: CGFloat = 0.15
        static let bestBorderOpacity: CGFloat = 0.32
        static let defaultBorderOpacity: CGFloat = 0.06
        static let bestIconBackgroundOpacity: CGFloat = 0.12
        static let chipWidth: CGFloat = 68
    }

    // MARK: - Property
    /// 표시할 멤버 정보
    let member: StudyGroupMember
    /// 베스트 워크북 배지 노출 여부
    let showsBestWorkbookBadge: Bool

    // MARK: - Initializer
    /// - Parameters:
    ///   - member: 표시할 멤버 정보
    ///   - showsBestWorkbookBadge: 베스트 워크북 배지 노출 여부
    init(
        member: StudyGroupMember,
        showsBestWorkbookBadge: Bool = false
    ) {
        self.member = member
        self.showsBestWorkbookBadge = showsBestWorkbookBadge
    }

    // MARK: - Equatable
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.member == rhs.member &&
            lhs.showsBestWorkbookBadge == rhs.showsBestWorkbookBadge
    }

    private var hasBestWorkbookPoint: Bool {
        showsBestWorkbookBadge && member.bestWorkbookPoint > Constants.bestPointThreshold
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: DefaultSpacing.spacing4) {
            avatarView
            // 칩에는 닉네임만 노출(없으면 본명). LeaderRow의 "닉네임/이름" 풀 표기와 다르게,
            // 좁은 폭의 칩에서는 한 글자라도 더 보여야 가독성이 높다는 디자인 결정.
            Text(member.nickname ?? member.name)
                .appFont(.caption1)
                .lineLimit(Constants.nameLineLimit)
                .minimumScaleFactor(Constants.nameMinimumScaleFactor)
        }
        .padding(.horizontal, Constants.chipHorizontalPadding)
        .padding(.vertical, Constants.chipVerticalPadding)
        .frame(width: Constants.chipWidth, height: Constants.chipHeight)
        // 명시 cornerRadius로 칩 곡률 보장 — ConcentricRectangle은 nested Material/Glass에서
        // corner inheritance가 끊겨 곡률이 무너진다(이번 이슈 캡처 검증).
        .glassEffect(
            .regular.tint(.gray.opacity(Constants.baseTintOpacity)),
            in: .rect(cornerRadius: Constants.chipCornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Constants.chipCornerRadius)
                .stroke(
                    hasBestWorkbookPoint
                        ? .orange.opacity(Constants.bestBorderOpacity)
                        : .black.opacity(Constants.defaultBorderOpacity),
                    lineWidth: Constants.bestBorderWidth
                )
        }
        .overlay(alignment: .topTrailing) {
            if hasBestWorkbookPoint {
                bestWorkbookIcon
                    .offset(
                        x: Constants.bestIconOverlapOffset,
                        y: -Constants.bestIconOverlapOffset
                    )
            }
        }
    }

    // MARK: - View Components
    @ViewBuilder
    private var avatarView: some View {
        RemoteImage(
            urlString: member.profileImageURL ?? "",
            size: CGSize(
                width: Constants.avatarSize,
                height: Constants.avatarSize
            ),
            cornerRadius: Constants.avatarCornerRadius,
            placeholderImage: Constants.avatarPlaceholderImageName
        )
        .clipShape(Circle())
    }

    private var bestWorkbookIcon: some View {
        Image(systemName: Constants.bestIconSystemName)
            .font(.system(size: Constants.bestIconSize, weight: .semibold))
        .foregroundStyle(.orange)
        .frame(
            width: Constants.bestIconContainerSize,
            height: Constants.bestIconContainerSize
        )
        .background(.orange.opacity(Constants.bestIconBackgroundOpacity), in: Circle())
    }
}

// MARK: - Preview
#Preview("StudyGroupMemberChip") {
    VStack(spacing: DefaultSpacing.spacing16) {
        // With profile image
        HStack(spacing: DefaultSpacing.spacing8) {
            StudyGroupMemberChip(
                member: StudyGroupMember(
                    serverID: "1",
                    name: "김철수",
                    university: "서울대",
                    profileImageURL: "https://picsum.photos/200",
                    role: .leader
                )
            )
            StudyGroupMemberChip(
                member: StudyGroupMember(
                    serverID: "2",
                    name: "이영희",
                    university: "연세대",
                    profileImageURL: "https://picsum.photos/201",
                    role: .member,
                    bestWorkbookPoint: 30
                )
            )
            StudyGroupMemberChip(
                member: StudyGroupMember(
                    serverID: "3",
                    name: "박민수",
                    university: "고려대",
                    profileImageURL: "https://picsum.photos/202",
                    role: .member
                )
            )
        }

        // Without profile images
        HStack(spacing: DefaultSpacing.spacing8) {
            StudyGroupMemberChip(
                member: StudyGroupMember(
                    serverID: "4",
                    name: "최지훈",
                    university: "서울대",
                    profileImageURL: nil,
                    role: .leader
                )
            )
            StudyGroupMemberChip(
                member: StudyGroupMember(
                    serverID: "5",
                    name: "정서연",
                    university: "연세대",
                    profileImageURL: nil,
                    role: .member
                )
            )
            StudyGroupMemberChip(
                member: StudyGroupMember(
                    serverID: "6",
                    name: "강태영",
                    university: "고려대",
                    profileImageURL: nil,
                    role: .member
                )
            )
        }
    }
    .padding()
}
