//
//  AttendanceStatusBadge.swift
//  CoreUIComponents
//
//  Created by euijjang97 on 5/6/26.
//

import SwiftUI
import CoreDesignSystem

// MARK: - AttendanceStatusBadge

/// 출석 상태를 색상으로 구분해 표시하는 뱃지 컴포넌트
///
/// ``AttendanceBadgeStatus`` 의 9개 케이스(`unknown` 포함)를 색상으로 구분합니다.
/// 운영진 출석 현황 목록/상세 등 여러 Feature가 공유하는 컴포넌트입니다.
/// 색상/문구 매핑은 ``AttendanceBadgeStatus`` 가 소유하며, 본 뷰는 렌더링만 담당합니다.
public struct AttendanceStatusBadge: View, Equatable {

    // MARK: - Constants

    fileprivate enum Constants {
        static let unknownIconSize: CGFloat = 11
    }

    // MARK: - Property

    private let status: AttendanceBadgeStatus

    // MARK: - Initializer

    public init(status: AttendanceBadgeStatus) {
        self.status = status
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: DefaultSpacing.spacing4) {
            if status == .unknown {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: Constants.unknownIconSize, weight: .semibold))
            }
            Text(status.badgeText)
                .lineLimit(1)
        }
        .appFont(.caption1, color: status.foregroundColor)
        .padding(.horizontal, DefaultSpacing.spacing8)
        .padding(.vertical, DefaultSpacing.spacing4)
        .glassEffect(
            .clear.tint(status.backgroundColor),
            in: Capsule()
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.accessibilityText)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
        ForEach(AttendanceBadgeStatus.allCases, id: \.self) { status in
            HStack {
                AttendanceStatusBadge(status: status)
                Text(status.rawValue)
                    .appFont(.footnote, color: .grey500)
            }
        }
    }
    .padding()
}
#endif
