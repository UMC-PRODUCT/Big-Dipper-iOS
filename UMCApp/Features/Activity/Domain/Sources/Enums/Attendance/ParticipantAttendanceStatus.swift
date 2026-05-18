//
//  ParticipantAttendanceStatus.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/17/26.
//

import Foundation

/// 참여자(타인 관찰 시점) 출석 상태
///
/// 운영진이 출석 현황을 조회할 때 사용합니다. 챌린저 본인 시점의
/// ``AttendanceStatus`` 와는 의미가 달라 별도 enum 으로 분리했습니다.
///
/// 서버가 케이스를 추가했을 때 디코딩 실패를 막기 위해 `.unknown` 폴백을 둡니다.
///
/// - SeeAlso: ``AttendanceStatus``, ``ScheduleAttendanceInfo``
public enum ParticipantAttendanceStatus: String, Codable, Sendable, CaseIterable, Equatable, Hashable {

    /// 출석 승인 대기 (체크인 완료, 운영진 승인 전)
    case presentPending = "PRESENT_PENDING"
    /// 지각 승인 대기
    case latePending = "LATE_PENDING"
    /// 사유 결석 승인 대기
    case excusedPending = "EXCUSED_PENDING"
    /// 출석 (정시)
    case present = "PRESENT"
    /// 지각
    case late = "LATE"
    /// 결석
    case absent = "ABSENT"
    /// 사유 결석 (출석으로 인정)
    case excused = "EXCUSED"
    /// 출석 전 (정책 시작 전)
    case pending = "PENDING"
    /// 알 수 없는 상태 (forward-compatible 폴백)
    case unknown

    // MARK: - Decoding

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ParticipantAttendanceStatus(rawValue: raw) ?? .unknown
    }

    // MARK: - Filterable

    /// 필터 UI 에 노출할 케이스
    ///
    /// `.unknown` 은 사용자 의도와 무관한 시스템 폴백이므로 필터 칩에서 제외합니다.
    public static var filterableCases: [ParticipantAttendanceStatus] {
        allCases.filter { $0 != .unknown }
    }

    // MARK: - Display

    /// 배지/필터 칩에 표시할 한국어 텍스트
    ///
    /// 폭 제약이 있는 뱃지 UI 에는 ``badgeText`` 를 사용하세요.
    public var displayText: String {
        switch self {
        case .presentPending:   return "출석 승인 대기"
        case .latePending:      return "지각 승인 대기"
        case .excusedPending:   return "사유 승인 대기"
        case .present:          return "출석"
        case .late:             return "지각"
        case .absent:           return "결석"
        case .excused:          return "사유 결석"
        case .pending:          return "출석 전"
        case .unknown:          return "상태 미지정"
        }
    }

    /// 뱃지 컴포넌트에 렌더링할 짧은 텍스트
    ///
    /// `.unknown` 만 폭 제약 때문에 단축하고, 나머지는 ``displayText`` 와 동일합니다.
    public var badgeText: String {
        self == .unknown ? "알 수 없음" : displayText
    }

    /// 서버 쿼리 파라미터로 직렬화한 값 (`.unknown` 은 전송 차단)
    public var serverQueryValue: String? {
        self == .unknown ? nil : rawValue
    }

    // MARK: - Categorization

    /// 승인 대기 상태 여부 (운영진 "처리 필요" 표시용)
    public var isPending: Bool {
        switch self {
        case .presentPending, .latePending, .excusedPending:
            return true
        default:
            return false
        }
    }
}
