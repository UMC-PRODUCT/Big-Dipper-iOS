//
//  StudyGroupLeaderRow.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/15/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import SwiftUI

// MARK: - StudyGroupLeaderRow

/// 스터디 그룹 파트장 행
///
/// 프로필 이미지, 이름, 대학교, 역할 뱃지를 표시합니다.
struct StudyGroupLeaderRow: View, Equatable {

    // MARK: - Constants

    fileprivate enum Constants {
        static let avatarSize: CGFloat = 48
        static let rowPadding: CGFloat = 12
        static let surfaceShadowRadius: CGFloat = 10
        static let surfaceHighlightRadius: CGFloat = 4
        static let surfaceShadowYOffset: CGFloat = 6
        /// 표면 라운드 — Nested Material/Glass 환경에서 ConcentricRectangle inheritance가
        /// 끊기는 문제가 있어 명시 cornerRadius로 곡률을 직접 보장한다.
        static let surfaceCornerRadius: CGFloat = 16
    }

    // MARK: - Property

    /// 파트장 정보
    let leader: StudyGroupMember
    /// 스터디 파트 메인 색
    let partTintColor: Color

    // MARK: - Initializer

    /// - Parameters:
    ///   - leader: 표시할 파트장 정보
    ///   - partTintColor: 파트 메인 색상
    init(
        leader: StudyGroupMember,
        partTintColor: Color
    ) {
        self.leader = leader
        self.partTintColor = partTintColor
    }

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.leader == rhs.leader
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            avatarView

            // displayName = "{nickname}/{name}" 또는 "{name}". "운영이/김운영" 같은 단일 식별자가
            // 좁은 폭에서 임의로 줄바꿈되지 않도록 lineLimit(1) + minimumScaleFactor로 한 줄을
            // 강제하고, 그래도 부족하면 자동 축소 후 마지막에 ellipsis로 잘린다.
            Text(leader.displayName)
                .appFont(.callout, weight: .semibold, color: .black)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .truncationMode(.tail)
                .layoutPriority(1)

            InfoBadge(leader.university)
                .layoutPriority(-1)

            InfoBadge(leader.role.rawValue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Constants.rowPadding)
        .background(surfaceBackground)
    }

    // MARK: - View Components

    private var avatarView: some View {
        RemoteImage(
            urlString: leader.profileImageURL ?? "",
            size: CGSize(
                width: Constants.avatarSize,
                height: Constants.avatarSize
            ),
            cornerRadius: 0
        )
        .clipShape(Circle())
    }

    /// 표면 배경 — 파트 컬러 그라데이션 + 미묘한 highlight/shadow.
    ///
    /// 카드 외부가 이미 `.glassEffect(.regular)`이고 상위 `mentorSection`은 `.regularMaterial`이다.
    /// 추가 Glass를 중첩하면 Glass-on-Glass-on-Material 삼중 블러가 발생해 가독성·성능 모두 손해다.
    /// 따라서 Glass 없이 LinearGradient + shadow만 사용한다.
    ///
    /// 곡률은 `RoundedRectangle(cornerRadius:)`로 직접 보장한다. `ConcentricRectangle`은 nested
    /// Material 컨테이너에서 corner inheritance가 끊겨 곡률이 무너지는 문제가 있다.
    private var surfaceBackground: some View {
        RoundedRectangle(cornerRadius: Constants.surfaceCornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(0.85),
                        partTintColor.opacity(0.20),
                        partTintColor.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(
                color: .black.opacity(0.08),
                radius: Constants.surfaceShadowRadius,
                x: 0,
                y: Constants.surfaceShadowYOffset
            )
            .shadow(
                color: .white.opacity(0.7),
                radius: Constants.surfaceHighlightRadius,
                x: -2,
                y: -2
            )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: DefaultSpacing.spacing16) {
        StudyGroupLeaderRow(
            leader: StudyGroupMember(
                serverID: "1",
                name: "김운영",
                nickname: "운영이",
                university: "홍익대학교",
                profileImageURL: nil,
                role: .leader
            ),
            partTintColor: .indigo500
        )

        StudyGroupLeaderRow(
            leader: StudyGroupMember(
                serverID: "2",
                name: "이리더",
                university: "서울대학교",
                profileImageURL: nil,
                role: .leader
            ),
            partTintColor: .orange
        )
    }
    .padding()
}
