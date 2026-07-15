//
//  CoreMemberManagementList.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/15/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import SwiftUI
import UMCFoundation

// MARK: - CoreMemberManagementList

/// 구성원 목록의 리스트 아이템 뷰입니다.
///
/// 프로필 이미지, 이름·파트, 운영진 직책 배지를 가로로 배치합니다.
/// 챌린저 구성원 목록과 운영진 멤버 관리 화면(후속 이슈)에서 공유합니다.
struct CoreMemberManagementList: View {

    // MARK: - Property

    /// 표시할 멤버 정보
    let memberManagementItem: MemberManagementItem

    // MARK: - Body

    var body: some View {
        HStack {
            MemberImagePresenter(memberManagementItem: memberManagementItem)

            CoreMemberTextPresenter(
                name: memberManagementItem.name,
                nickname: memberManagementItem.nickname,
                part: memberManagementItem.part
            )

            Spacer()

            ManagementTeamBadgePresenter(
                managementTeam: memberManagementItem.managementTeam
            )
        }
    }
}

// MARK: - CoreMemberTextPresenter

/// 멤버의 닉네임·이름과 파트 배지를 표시합니다.
struct CoreMemberTextPresenter: View {

    /// 멤버 이름
    let name: String

    /// 멤버 닉네임
    let nickname: String

    /// 소속 파트
    let part: UMCPartType

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Text("\(nickname)/\(name)")
                .appFont(.callout, weight: .semibold, color: .black)

            Text(part.name)
                .appFont(.footnote, color: part.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    Capsule()
                        .fill(part.color.opacity(0.16))
                }
                .overlay {
                    Capsule()
                        .stroke(part.color.opacity(0.4), lineWidth: 1)
                }
        }
    }
}

// MARK: - ManagementTeamBadgePresenter

/// 운영진 직책 배지입니다. 일반 챌린저(`.challenger`)는 아무것도 표시하지 않습니다.
struct ManagementTeamBadgePresenter: View {

    /// 운영진 직책 타입
    let managementTeam: ManagementTeam

    private enum Constants {
        static let verticalPadding: CGFloat = 6
        static let horizontalPadding: CGFloat = 8
    }

    var body: some View {
        Group {
            if managementTeam != .challenger {
                Text(managementTeam.korean)
                    .font(.app(.footnote, weight: .regular))
                    .foregroundStyle(managementTeam.textColor)
                    .padding(.vertical, Constants.verticalPadding)
                    .padding(.horizontal, Constants.horizontalPadding)
                    .background {
                        RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius)
                            .fill(managementTeam.backgroundColor)
                    }
            }
        }
    }
}

// MARK: - PenaltyBadgePresenter

/// 운영진 화면에서 멤버의 벌점을 표시하는 배지입니다.
struct PenaltyBadgePresenter: View {

    let penalty: Double

    private enum Constants {
        static let verticalPadding: CGFloat = 6
        static let horizontalPadding: CGFloat = 8
        static let bgOpacity: Double = 0.2
    }

    var body: some View {
        Text("벌점 \(String(format: "%.0f", penalty))")
            .font(.app(.footnote, weight: .regular))
            .foregroundStyle(.red)
            .padding(.vertical, Constants.verticalPadding)
            .padding(.horizontal, Constants.horizontalPadding)
            .background {
                RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius)
                    .fill(.red.opacity(Constants.bgOpacity))
            }
    }
}

// MARK: - Preview

#if DEBUG
#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 4) {
        CoreMemberManagementList(
            memberManagementItem: MemberManagementItem(
                profile: nil,
                name: "이예지",
                nickname: "소피",
                generation: "9기",
                school: "가천대학교",
                position: "Part Leader",
                part: .front(type: .ios),
                penalty: 0,
                badge: false,
                managementTeam: .schoolPartLeader,
                attendanceRecords: [],
                penaltyHistory: []
            )
        )

        CoreMemberManagementList(
            memberManagementItem: MemberManagementItem(
                profile: nil,
                name: "홍길동",
                nickname: "라이언",
                generation: "9기",
                school: "가천대학교",
                position: "Challenger",
                part: .front(type: .ios),
                penalty: 1,
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
