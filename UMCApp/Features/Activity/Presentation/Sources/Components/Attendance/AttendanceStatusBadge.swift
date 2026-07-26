//
//  AttendanceStatusBadge.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/25/26.
//

import ActivityDomain
import CoreDesignSystem
import SwiftUI

// MARK: - AttendanceStatusBadge

/// 참여자별 출석 상태를 표시하는 뱃지 컴포넌트
///
/// ``ParticipantAttendanceStatus`` 9개 케이스(`unknown` 포함)를 색상으로 구분합니다.
/// 운영진 출석 목록·상세 양쪽에서 동일하게 사용됩니다.
///
/// > Note: 배치 예외 — 뱃지가 `ParticipantAttendanceStatus`(ActivityDomain)에 직접
///   의존하므로 `CoreUIComponents` 로 올리면 Core → Feature 역방향 의존이 됩니다.
///   색상·아이콘 매핑은 ``ParticipantAttendanceStatus`` 확장에 두고, 뱃지 자체는
///   ActivityPresentation 에 둡니다.
struct AttendanceStatusBadge: View {

    // MARK: - Constants

    fileprivate enum Constants {
        static let backgroundOpacity: Double = 0.18
        static let unknownIconSize: CGFloat = 11
    }

    // MARK: - Property

    let status: ParticipantAttendanceStatus

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing4) {
            if status == .unknown {
                Image(systemName: status.iconName)
                    .font(.system(size: Constants.unknownIconSize, weight: .semibold))
            }
            Text(status.badgeText)
                .lineLimit(1)
        }
        .appFont(.caption1, color: status.badgeForegroundColor)
        .padding(.horizontal, DefaultSpacing.spacing8)
        .padding(.vertical, DefaultSpacing.spacing4)
        .glassEffect(
            .clear.tint(status.badgeTintColor.opacity(Constants.backgroundOpacity)),
            in: Capsule()
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.displayText)
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
        ForEach(ParticipantAttendanceStatus.allCases, id: \.self) { status in
            HStack {
                AttendanceStatusBadge(status: status)
                Text(status.rawValue)
                    .appFont(.footnote, color: .grey500)
            }
        }
    }
    .padding()
}
