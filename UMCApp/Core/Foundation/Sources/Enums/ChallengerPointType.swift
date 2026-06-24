//
//  ChallengerPointType.swift
//  UMCFoundation
//
//  Created by jaewon Lee on 6/17/26.
//

import Foundation

/// 챌린저 포인트(상벌점) 유형
///
/// 서버 API 의 포인트 타입 문자열과 1:1 매핑됩니다.
/// 점수 표시(SF Symbol, Color)는 Presentation 레이어의 extension 에서 제공합니다.
public enum ChallengerPointType: String, Codable, Sendable, CaseIterable, Identifiable {
    case bestWorkbook = "BEST_WORKBOOK"
    case warning = "WARNING"
    case out = "OUT"
    case custom = "CUSTOM"
    case blogChallenge = "BLOG_CHALLENGE"
    case bestWorkbookV2 = "BEST_WORKBOOK_V2"
    case umcEventReview = "UMC_EVENT_REVIEW"
    case peerReviewSubmission = "PEER_REVIEW_SUBMISSION"
    case noWorkbookMission = "NO_WORKBOOK_MISSION"
    case studyLate = "STUDY_LATE"
    case studyAbsent = "STUDY_ABSENT"
    case eventLate = "EVENT_LATE"
    case eventEarlyLeave = "EVENT_EARLY_LEAVE"
    case eventLateCancel = "EVENT_LATE_CANCEL"
    case eventNoShow = "EVENT_NO_SHOW"
    case partLeadFeedbackLate = "PART_LEAD_FEEDBACK_LATE"
    case schoolCoreMeetingAbsent = "SCHOOL_CORE_MEETING_ABSENT"
    case schoolCoreTaskNotCompleted = "SCHOOL_CORE_TASK_NOT_COMPLETED"

    public var id: String { rawValue }

    /// 포인트 유형의 한글 표시명
    public var displayName: String {
        switch self {
        case .bestWorkbook: return "우수 워크북"
        case .warning: return "경고"
        case .out: return "아웃"
        case .custom: return "기타"
        case .blogChallenge: return "블로그 챌린지"
        case .bestWorkbookV2: return "우수 워크북 V2"
        case .umcEventReview: return "UMC 행사 후기"
        case .peerReviewSubmission: return "동료 평가 제출"
        case .noWorkbookMission: return "워크북 미제출"
        case .studyLate: return "스터디 지각"
        case .studyAbsent: return "스터디 결석"
        case .eventLate: return "행사 지각"
        case .eventEarlyLeave: return "행사 조퇴"
        case .eventLateCancel: return "행사 당일 취소"
        case .eventNoShow: return "행사 노쇼"
        case .partLeadFeedbackLate: return "파트장 피드백 지연"
        case .schoolCoreMeetingAbsent: return "회장단 회의 결석"
        case .schoolCoreTaskNotCompleted: return "회장단 업무 미완료"
        }
    }

    /// 유형별 기본 배점 (상점은 양수, 벌점은 음수)
    ///
    /// - Note: `.warning`/`.out` 은 벌점 개념이지만 레거시 호환을 위해 양수(1)로 유지됩니다.
    ///   (이 때문에 `isReward` 가 `true` 로 평가되는 예외) 두 유형은 `availableTypes(for:)` 에서
    ///   이미 제외되므로 일반 부여 흐름에는 영향이 없습니다.
    public var defaultPointValue: Int {
        switch self {
        case .bestWorkbook: return 2
        case .warning: return 1
        case .out: return 1
        case .custom: return 0
        case .blogChallenge: return 3
        case .bestWorkbookV2: return 2
        case .umcEventReview: return 1
        case .peerReviewSubmission: return 1
        case .noWorkbookMission: return -4
        case .studyLate: return -2
        case .studyAbsent: return -4
        case .eventLate: return -2
        case .eventEarlyLeave: return -2
        case .eventLateCancel: return -4
        case .eventNoShow: return -10
        case .partLeadFeedbackLate: return -4
        case .schoolCoreMeetingAbsent: return -4
        case .schoolCoreTaskNotCompleted: return -4
        }
    }

    /// 상점(보상) 유형 여부
    public var isReward: Bool {
        defaultPointValue > 0
    }

    /// 사용자가 직접 배점을 입력해야 하는 유형 여부 (CUSTOM)
    public var isCustom: Bool {
        self == .custom
    }

    /// 부여에 필요한 최소 권한 레벨 (``ManagementTeam/level`` 기준)
    public var minimumRequiredLevel: Int {
        switch self {
        // 상점 유형 (일반 운영진 부여 가능)
        case .bestWorkbook, .bestWorkbookV2, .blogChallenge,
             .umcEventReview, .peerReviewSubmission:
            return 20
        // 벌점 유형 (일반 운영진 부여 가능)
        case .noWorkbookMission, .studyLate, .studyAbsent,
             .eventLate, .eventEarlyLeave, .eventLateCancel, .eventNoShow:
            return 20
        case .partLeadFeedbackLate:
            return 30
        case .schoolCoreMeetingAbsent, .schoolCoreTaskNotCompleted:
            return 50
        case .warning, .out:
            return 20
        case .custom:
            return 20
        }
    }

    /// 주어진 권한 레벨에서 부여 가능한 유형 목록
    ///
    /// `warning`/`out` 은 별도 흐름에서 처리하므로 목록에서 제외합니다.
    public static func availableTypes(for level: Int) -> [ChallengerPointType] {
        allCases.filter { type in
            type != .warning && type != .out && level >= type.minimumRequiredLevel
        }
    }
}
