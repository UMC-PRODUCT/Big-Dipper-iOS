//
//  AttendanceRouter.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/6/26.
//

import Foundation
import CoreNetwork
internal import Alamofire
import Moya

/// 출석 API 라우터
///
/// 운영진/챌린저 출석 도메인의 엔드포인트를 정의합니다. 조회(목록/상세), 일괄 결정,
/// GPS 출석 요청, 사유 출석 제출, 일정 위치 변경을 단일 라우터로 묶어 표현합니다.
///
/// - Note: `scheduleId` / `participantMemberId` 등 서버 식별자는 전 레이어 `String`
///   으로 통일합니다. 쿼리 파라미터는 각 Query DTO의 `toParameters` 로, 바디는 Request
///   DTO로 캡슐화하며 라우터 `task` 에 인라인 딕셔너리를 두지 않습니다.
enum AttendanceRouter {
    /// 출석 현황 목록 조회 (운영진, 기간/상태 필터)
    case fetchAttendanceList(query: AttendanceListQuery)
    /// 단일 일정 출석 현황 조회 (운영진, 상태 필터)
    case fetchAttendanceDetail(scheduleId: String, query: AttendanceDetailQuery)
    /// 출석 일괄 승인/반려 (운영진)
    case decideAttendances(scheduleId: String, body: [DecideAttendanceItemDTO])
    /// GPS 출석 요청 (챌린저 본인)
    case requestAttendance(scheduleId: String, body: RequestAttendanceRequestDTO)
    /// 사유 출석 제출 (챌린저 본인)
    case excuseAttendance(scheduleId: String, body: ExcuseAttendanceRequestDTO)
    /// 일정 출석 위치 변경 (운영진, 부분 갱신)
    case updateScheduleLocation(scheduleId: String, body: UpdateScheduleLocationRequestDTO)
}

extension AttendanceRouter: BaseTargetType {

    // MARK: - Path

    var path: String {
        switch self {
        case .fetchAttendanceList:
            return "/api/v2/schedules/attendance"
        case .fetchAttendanceDetail(let scheduleId, _):
            return "/api/v2/schedules/\(scheduleId)/attendance"
        case .decideAttendances(let scheduleId, _):
            return "/api/v2/schedules/\(scheduleId)/attendances/decide"
        case .requestAttendance(let scheduleId, _):
            return "/api/v2/schedules/\(scheduleId)/attendances/request"
        case .excuseAttendance(let scheduleId, _):
            return "/api/v2/schedules/\(scheduleId)/attendances/excuse"
        case .updateScheduleLocation(let scheduleId, _):
            return "/api/v2/schedules/\(scheduleId)"
        }
    }

    // MARK: - Method

    var method: Moya.Method {
        switch self {
        case .fetchAttendanceList, .fetchAttendanceDetail:
            return .get
        case .decideAttendances, .requestAttendance, .excuseAttendance:
            return .post
        case .updateScheduleLocation:
            return .patch
        }
    }

    // MARK: - Task

    var task: Moya.Task {
        switch self {
        case .fetchAttendanceList(let query):
            let params = query.toParameters
            guard !params.isEmpty else {
                return .requestPlain
            }
            return .requestParameters(
                parameters: params,
                encoding: URLEncoding.queryString
            )
        case .fetchAttendanceDetail(_, let query):
            let params = query.toParameters
            guard !params.isEmpty else {
                return .requestPlain
            }
            return .requestParameters(
                parameters: params,
                encoding: URLEncoding.queryString
            )
        case .decideAttendances(_, let body):
            return .requestJSONEncodable(body)
        case .requestAttendance(_, let body):
            return .requestJSONEncodable(body)
        case .excuseAttendance(_, let body):
            return .requestJSONEncodable(body)
        case .updateScheduleLocation(_, let body):
            return .requestJSONEncodable(body)
        }
    }
}
