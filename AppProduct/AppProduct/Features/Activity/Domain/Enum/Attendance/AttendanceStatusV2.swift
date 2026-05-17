//
//  AttendanceStatusV2.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation

/// 운영진 출석 현황 V2 응답의 참여자별 출석 상태
///
/// `GET /api/v2/schedules/attendance` 와 `GET /api/v2/schedules/{id}/attendance` 의
/// `participants[].attendanceStatus` 필드 전용 enum 입니다.
///
/// Swagger 에는 `PRESENT_PENDING` 만 명시되어 있어 전체 케이스가 미확정이므로,
/// **`unknown` 폴백 패턴** 으로 디코딩합니다. 백엔드가 새 케이스를 추가해도
/// 디코딩 실패가 발생하지 않으며, UI 는 `.unknown` 을 "상태 미지정" 으로 표시합니다.
///
/// 기존 ``AttendanceStatus`` 와 분리한 이유:
/// - V1 enum 은 5개 케이스(`beforeAttendance/pendingApproval/present/late/absent`)
///   로 합쳐져 `EXCUSED` 등 V2 신규 케이스를 별도 표시할 수 없음
/// - V1 enum 은 화면 색상까지 들고 있어 책임이 섞여 있음
/// - V2 응답은 참여자별 상태이며, 운영진 출석 현황 화면 전용
///
/// - SeeAlso: ``AttendanceStatus``, ``ScheduleAttendanceInfo``
enum AttendanceStatusV2: String, Codable, Sendable, CaseIterable, Equatable, Hashable {

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
    /// 알 수 없는 상태 (서버가 새 케이스를 추가했을 때 폴백)
    case unknown

    // MARK: - Decoding

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AttendanceStatusV2(rawValue: raw) ?? .unknown
    }

    // MARK: - Filterable

    /// 필터 UI 에 노출할 케이스 (`.unknown` 제외)
    ///
    /// PRD 결정: `.unknown` 은 사용자 의도와 무관한 시스템 케이스이므로
    /// 필터 칩에서 제외합니다.
    static var filterableCases: [AttendanceStatusV2] {
        allCases.filter { $0 != .unknown }
    }

    // MARK: - Display

    /// 배지/필터 칩에 표시할 한국어 텍스트
    ///
    /// `.unknown` 은 "상태 미지정" — 접근성 라벨 및 필터 옵션에 사용합니다.
    /// 폭 제약이 있는 뱃지 UI 에는 ``badgeText`` 를 사용하세요.
    var displayText: String {
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
    /// `.unknown` 은 폭 제약 때문에 `"알 수 없음"` 으로 단축합니다.
    /// VoiceOver 에는 ``displayText`` 가 읽히므로 접근성이 유지됩니다.
    var badgeText: String {
        self == .unknown ? "알 수 없음" : displayText
    }

    /// 서버 쿼리 파라미터로 보낼 raw 값
    ///
    /// `.unknown` 은 서버에 보낼 수 없으므로 `nil` 을 반환합니다.
    var serverQueryValue: String? {
        self == .unknown ? nil : rawValue
    }

    // MARK: - Categorization

    /// 승인 대기 상태 여부
    ///
    /// 운영진 화면에서 "처리 필요" 표시 등에 활용합니다.
    var isPending: Bool {
        switch self {
        case .presentPending, .latePending, .excusedPending:
            return true
        default:
            return false
        }
    }
}
