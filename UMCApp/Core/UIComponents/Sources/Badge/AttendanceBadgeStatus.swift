//
//  AttendanceBadgeStatus.swift
//  CoreUIComponents
//
//  Created by euijjang97 on 5/6/26.
//

import SwiftUI
import CoreDesignSystem

// MARK: - AttendanceBadgeStatus

/// ``AttendanceStatusBadge`` 가 표현하는 출석 상태의 Core-safe 추상화입니다.
///
/// CoreUIComponents는 Feature Domain 모듈(예: ActivityDomain의 `ParticipantAttendanceStatus`)에
/// 의존할 수 없으므로, 실제 출석 도메인 enum과 동일한 케이스 집합을 자체적으로 보유합니다.
/// 각 Feature는 자신의 도메인 enum을 Presentation 레이어에서 이 타입으로 매핑해 사용합니다.
public enum AttendanceBadgeStatus: String, CaseIterable, Equatable, Hashable, Sendable {

    /// 출석 승인 대기 (체크인 완료, 운영진 승인 전)
    case presentPending
    /// 지각 승인 대기
    case latePending
    /// 사유 결석 승인 대기
    case excusedPending
    /// 출석 (정시)
    case present
    /// 지각
    case late
    /// 결석
    case absent
    /// 사유 결석 (출석으로 인정)
    case excused
    /// 출석 전 (정책 시작 전)
    case pending
    /// 알 수 없는 상태 (도메인 enum이 forward-compatible 폴백으로 매핑)
    case unknown

    // MARK: - Display

    /// 뱃지 컴포넌트에 렌더링할 짧은 텍스트
    public var badgeText: String {
        switch self {
        case .presentPending: return "출석 승인 대기"
        case .latePending: return "지각 승인 대기"
        case .excusedPending: return "사유 승인 대기"
        case .present: return "출석"
        case .late: return "지각"
        case .absent: return "결석"
        case .excused: return "사유 결석"
        case .pending: return "출석 전"
        case .unknown: return "알 수 없음"
        }
    }

    /// VoiceOver 등 접근성 라벨에 사용할 전체 문구
    public var accessibilityText: String {
        self == .unknown ? "상태 미지정" : badgeText
    }

    // MARK: - Color

    /// 배지 배경(tint)에 사용할 색상
    public var tintColor: Color {
        switch self {
        case .present, .excused:
            return .green500
        case .late:
            return .orange500
        case .absent:
            return .red500
        case .presentPending, .latePending, .excusedPending:
            return .yellow500
        case .pending, .unknown:
            return .grey500
        }
    }

    /// 배지 텍스트/아이콘에 사용할 색상
    public var foregroundColor: Color {
        switch self {
        case .present, .excused:
            return .green500
        case .late:
            return .orange500
        case .absent:
            return .red500
        case .presentPending, .latePending, .excusedPending:
            return .orange500
        case .pending, .unknown:
            return .grey600
        }
    }
}
