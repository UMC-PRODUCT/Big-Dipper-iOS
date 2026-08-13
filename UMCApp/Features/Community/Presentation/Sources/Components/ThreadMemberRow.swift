//
//  ThreadMemberRow.swift
//  CommunityPresentation
//

import SwiftUI
import CommunityDomain
import CoreDesignSystem
import CoreUIComponents

// MARK: - Constants

fileprivate enum Constants {
    static let avatarSize = CGSize(width: 40, height: 40)
    static let meSuffix = " (나)"
}

/// 참여자 목록 한 행 — 아바타 · 이름 · 파트 · 역할 배지.
///
/// ⋯ 메뉴는 개설자에게만 붙는다. 붙일지 말지는 상위가 정하고 여기서는 받은 대로만 그린다.
struct ThreadMemberRow: View {

    // MARK: - Property

    let member: ThreadMember
    let isMe: Bool
    let canManage: Bool
    let onTransferOwnership: () -> Void
    let onKick: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            RemoteImage(
                urlString: member.profileImageURL ?? "",
                size: Constants.avatarSize
            )

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                Text(isMe ? member.name + Constants.meSuffix : member.name)
                    .appFont(.subheadline, weight: .semibold, color: .grey900)
                    .lineLimit(1)

                if let part = member.part, !part.isEmpty {
                    Text(part)
                        .appFont(.caption1, color: .grey600)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: DefaultSpacing.spacing8)

            roleBadge

            if canManage {
                manageMenu
            }
        }
        .padding(.vertical, DefaultSpacing.spacing4)
    }

    // MARK: - View Component

    /// 배지는 개설자/참여자 둘뿐이다. 위임으로 생기는 `ADMIN` 도 나가기·권한이 참여자와 같아
    /// 별도 배지를 두면 화면마다 다른 이름으로 불리는 상태가 하나 더 늘어난다.
    private var roleBadge: some View {
        InfoBadge(
            member.role.displayName,
            textColor: member.role == .owner ? .indigo500 : .grey600,
            tintColor: member.role == .owner ? .indigo500 : nil
        )
    }

    private var manageMenu: some View {
        Menu {
            Button("개설자 위임", systemImage: "crown", action: onTransferOwnership)
            Button("내보내기", systemImage: "person.fill.xmark", role: .destructive, action: onKick)
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(Color.grey600)
                // 아이콘은 작아도 누를 곳은 44pt 를 채운다 (명세 접근성).
                .frame(
                    width: DefaultConstant.minimumTouchTarget,
                    height: DefaultConstant.minimumTouchTarget
                )
                .contentShape(.rect)
        }
        .accessibilityLabel("\(member.name) 님 관리")
    }
}
