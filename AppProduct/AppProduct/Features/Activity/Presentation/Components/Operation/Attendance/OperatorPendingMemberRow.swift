//
//  OperatorPendingMemberRow.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/5/26.
//

import SwiftUI

/// 운영진 출석 관리 승인 대기 멤버 행
///
/// 승인 대기 중인 멤버 정보와 승인/반려 버튼을 표시합니다.
struct OperatorPendingMemberRow: View, Equatable {

    // MARK: - Property

    private let member: OperatorPendingMember
    private let isSelecting: Bool
    private let isSelected: Bool
    private var onToggleSelection: (() -> Void)?

    // MARK: - Initializer

    init(
        member: OperatorPendingMember,
        isSelecting: Bool = false,
        isSelected: Bool = false,
        onToggleSelection: (() -> Void)? = nil
    ) {
        self.member = member
        self.isSelecting = isSelecting
        self.isSelected = isSelected
        self.onToggleSelection = onToggleSelection
    }

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.member == rhs.member &&
        lhs.isSelecting == rhs.isSelecting &&
        lhs.isSelected == rhs.isSelected
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing16) {
            if isSelecting {
                selectionButton
            }
            avatarView
            memberInfoSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(
            .snappy(duration: DefaultConstant.animationTime), value: isSelecting)
    }

    // MARK: - View Components

    private var selectionButton: some View {
        Button {
            onToggleSelection?()
        } label: {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(isSelected ? .indigo500 : .grey400)
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
    }

    private var avatarView: some View {
        Group {
            if let urlString = member.profileImageURL {
                RemoteImage(
                    urlString: urlString,
                    size: CGSize(
                        width: DefaultConstant.iconSize,
                        height: DefaultConstant.iconSize
                    ),
                    cornerRadius: 0,
                    placeholderImage: "person.fill"
                )
            } else {
                defaultAvatarImage
                    .frame(width: DefaultConstant.iconSize, height: DefaultConstant.iconSize)
                    .background(Color.grey200, in: .circle)
            }
        }
    }

    private var defaultAvatarImage: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 16))
            .foregroundStyle(.grey400)
    }

    private var memberInfoSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
            Text(member.displayName)
                .appFont(.calloutEmphasis, color: .black)

            HStack(spacing: DefaultSpacing.spacing8) {
                Text(member.university)
                Text("\(formattedTime) 요청")
            }
            .appFont(.footnote, color: .grey600)
        }
    }

    // MARK: - Function

    /// 시간 포맷팅 (HH:mm)
    private var formattedTime: String {
        member.requestTime.toHourMinutes()
    }
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    // 일반 모드
    OperatorPendingMemberRow(
        member: OperatorPendingMember(
            serverID: "1",
            participantMemberId: 1,
            name: "이재원",
            nickname: "리버",
            university: "한성대학교",
            requestTime: Date.now.addingTimeInterval(-300),
            reason: "지각 사유입니다",
            profileImageURL: "https://picsum.photos/100"
        )
    )

    // 선택 모드 - 미선택
    OperatorPendingMemberRow(
        member: OperatorPendingMember(
            serverID: "2",
            participantMemberId: 2,
            name: "김철수",
            nickname: "철수",
            university: "서울대학교",
            requestTime: Date.now.addingTimeInterval(-300),
            reason: nil,
            profileImageURL: nil
        ),
        isSelecting: true,
        isSelected: false
    )

    // 선택 모드 - 선택됨
    OperatorPendingMemberRow(
        member: OperatorPendingMember(
            serverID: "1",
            participantMemberId: 3,
            name: "이예지",
            nickname: "소피",
            university: "가천대학교",
            requestTime: Date.now.addingTimeInterval(-300),
            reason: "지각 사유입니다",
            profileImageURL: nil
        ),
        isSelecting: true,
        isSelected: true
    )
}
