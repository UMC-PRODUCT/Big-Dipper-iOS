//
//  AttendanceStatusBadge.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import SwiftUI

// MARK: - AttendanceStatusBadge

/// V2 출석 현황 화면에서 참여자별 상태를 표시하는 뱃지 컴포넌트
///
/// ``AttendanceStatusV2`` 의 9개 케이스(`unknown` 포함)를 색상으로 구분합니다.
/// 운영진 출석 현황 목록/상세 양쪽에서 동일하게 사용됩니다.
///
/// ## 색상 매핑
/// | 상태 | 색상 |
/// |------|------|
/// | 출석/사유결석 | 초록 |
/// | 지각 | 주황 |
/// | 결석 | 빨강 |
/// | *_PENDING | 노랑 |
/// | 출석 전 | 회색 |
/// | unknown | 회색 + "?" 아이콘 |
struct AttendanceStatusBadge: View, Equatable {

    // MARK: - Constants

    fileprivate enum Constants {
        static let backgroundOpacity: Double = 0.18
        static let unknownIconSize: CGFloat = 11
    }

    // MARK: - Property

    let status: AttendanceStatusV2

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing4) {
            if status == .unknown {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: Constants.unknownIconSize, weight: .semibold))
            }
            Text(status.displayText)
                .lineLimit(1)
        }
        .appFont(.caption1, color: foregroundColor)
        .padding(.horizontal, DefaultSpacing.spacing8)
        .padding(.vertical, DefaultSpacing.spacing4)
        .glassEffect(
            .clear.tint(tintColor.opacity(Constants.backgroundOpacity)),
            in: Capsule()
        )
    }

    // MARK: - Style

    private var tintColor: Color {
        switch status {
        case .present, .excused:
            return .green
        case .late:
            return .orange
        case .absent:
            return .red
        case .presentPending, .latePending, .excusedPending:
            return .yellow
        case .pending, .unknown:
            return .gray
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .present, .excused:
            return .green
        case .late:
            return .orange
        case .absent:
            return .red
        case .presentPending, .latePending, .excusedPending:
            return .orange
        case .pending, .unknown:
            return .grey600
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
        ForEach(AttendanceStatusV2.allCases, id: \.self) { status in
            HStack {
                AttendanceStatusBadge(status: status)
                Text(status.rawValue)
                    .appFont(.footnote, color: .grey500)
            }
        }
    }
    .padding()
}
