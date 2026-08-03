//
//  ChallengerWorkbookStatus.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 8/3/26.
//

import Foundation

/// 챌린저 워크북 한 건의 평가 상태 (서버 contract)
///
/// 서버가 미션 제출물 단위 상태를 워크북 단위로 집계해 내려주는 값입니다.
/// 워크북 상세 조회와 스터디원 제출 현황 목록이 같은 enum 을 공유합니다.
///
/// 서버가 케이스를 추가했을 때 디코딩이 통째로 실패하지 않도록 ``unknown`` 폴백을 둡니다
/// (``ParticipantAttendanceStatus`` 와 동일한 forward-compatible 규약).
///
/// - Note: ``notSubmitted`` 는 **워크북 자체가 배포되지 않은** 인원에게만 나타납니다.
///   워크북 단건 조회에서는 나올 수 없고, 미배포 인원도 행으로 포함하는 스터디원 제출 현황
///   목록에서만 사용됩니다. 베스트 워크북 여부(`isBest`)는 이 상태와 **독립된 별도 필드**라
///   여기에 케이스로 섞지 않습니다.
public enum ChallengerWorkbookStatus: String, Codable, Sendable, CaseIterable, Equatable,
    Hashable {

    /// 배포된 워크북이 없음 (미배포 인원)
    case notSubmitted = "NOT_SUBMITTED"
    /// 배포됐으나 평가가 끝나지 않음 (미제출·일부 미션만 통과 포함)
    case inProgress = "IN_PROGRESS"
    /// 필수 미션을 모두 통과 (인정 처리 포함)
    case pass = "PASS"
    /// 피드백에 FAIL 이 하나라도 존재
    case fail = "FAIL"
    /// 알 수 없는 상태 (forward-compatible 폴백)
    case unknown

    // MARK: - Decoding

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ChallengerWorkbookStatus(serverStatus: raw)
    }

    /// 서버 문자열로부터 생성 (서버 contract 매퍼)
    ///
    /// 값이 없거나 매칭되는 케이스가 없으면 ``unknown`` 으로 폴백합니다.
    ///
    /// - Parameter serverStatus: 서버가 내려준 상태 문자열
    public init(serverStatus: String?) {
        guard let serverStatus else {
            self = .unknown
            return
        }
        self = ChallengerWorkbookStatus(rawValue: serverStatus) ?? .unknown
    }

    // MARK: - Filterable

    /// 필터 UI 에 노출할 케이스
    ///
    /// ``unknown`` 은 사용자 의도와 무관한 시스템 폴백이므로 필터에서 제외합니다.
    public static var filterableCases: [ChallengerWorkbookStatus] {
        allCases.filter { $0 != .unknown }
    }

    // MARK: - Display

    /// 뱃지/목록에 표시할 한국어 텍스트
    public var displayText: String {
        switch self {
        case .notSubmitted: return "미배포"
        case .inProgress:   return "검토 중"
        case .pass:         return "통과"
        case .fail:         return "미통과"
        case .unknown:      return "상태 미지정"
        }
    }

    /// 서버 쿼리 파라미터로 직렬화한 값 (``unknown`` 은 전송 차단)
    public var serverQueryValue: String? {
        self == .unknown ? nil : rawValue
    }

    // MARK: - Categorization

    /// 평가가 확정된 상태인지 여부 (통과/미통과)
    ///
    /// 운영진이 "처리가 끝난 인원"을 구분할 때 사용합니다.
    public var isEvaluated: Bool {
        self == .pass || self == .fail
    }
}
