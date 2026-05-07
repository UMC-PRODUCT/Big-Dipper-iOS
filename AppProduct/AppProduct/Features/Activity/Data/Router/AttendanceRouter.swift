//
//  AttendanceRouter.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/17/26.
//

import Foundation
internal import Alamofire
import Moya

/// 출석체크 Feature API 라우터
///
/// 출석 관련 9개 API 엔드포인트를 정의합니다.
/// 모든 API는 JWT 인증이 필요합니다 (`adapter.request()` 사용).
enum AttendanceRouter {

    // MARK: - GET

    /// 출석 기록 상세 조회
    case getDetail(recordId: Int)
    /// 승인 대기 목록 조회 (관리자)
    case getPending(scheduleId: Int)
    /// 승인 대기 목록 일괄 조회 (관리자)
    case getAllPending
    /// 내 출석 이력 조회
    case getMyHistory
    /// 챌린저 출석 이력 조회
    case getChallengerHistory(challengerId: Int)
    /// 출석 가능 일정 조회
    case getAvailable

    // MARK: - POST

    /// 출석 반려 (관리자)
    case reject(recordId: Int)
    /// 출석 승인 (관리자)
    case approve(recordId: Int)
    /// 사유 제출 출석
    case submitReason(body: AttendanceReasonRequestDTO)
    /// GPS 출석 체크
    case check(body: AttendanceCheckRequestDTO)
    /// 일정 위치 변경 (관리자)
    case patchScheduleLocation(scheduleId: Int, body: ScheduleLocationUpdateRequestDTO)
}

// MARK: - BaseTargetType

extension AttendanceRouter: BaseTargetType {

    // MARK: - Path

    var path: String {
        switch self {
        case .getDetail(let recordId):
            return "/api/v1/attendances/\(recordId)"
        case .getPending(let scheduleId):
            return "/api/v1/attendances/pending/\(scheduleId)"
        case .getAllPending:
            return "/api/v1/attendances/pending"
        case .getMyHistory:
            return "/api/v1/attendances/history"
        case .getChallengerHistory(let challengerId):
            return "/api/v1/attendances/challenger/\(challengerId)/history"
        case .getAvailable:
            return "/api/v1/attendances/available"
        case .reject(let recordId):
            return "/api/v1/attendances/\(recordId)/reject"
        case .approve(let recordId):
            return "/api/v1/attendances/\(recordId)/approve"
        case .submitReason:
            return "/api/v1/attendances/reason"
        case .check:
            return "/api/v1/attendances/check"
        case .patchScheduleLocation(let scheduleId, _):
            return "/api/v1/schedules/\(scheduleId)/location"
        }
    }

    // MARK: - Method

    var method: Moya.Method {
        switch self {
        case .getDetail, .getPending, .getAllPending, .getMyHistory,
             .getChallengerHistory, .getAvailable:
            return .get
        case .reject, .approve, .submitReason, .check:
            return .post
        case .patchScheduleLocation:
            return .patch
        }
    }

    // MARK: - Task

    var task: Moya.Task {
        switch self {
        case .getDetail, .getPending, .getAllPending, .getMyHistory,
             .getChallengerHistory, .getAvailable,
             .reject, .approve:
            return .requestPlain
        case .submitReason(let body):
            return .requestJSONEncodable(body)
        case .check(let body):
            return .requestJSONEncodable(body)
        case .patchScheduleLocation(_, let body):
            return .requestJSONEncodable(body)
        }
    }
}
