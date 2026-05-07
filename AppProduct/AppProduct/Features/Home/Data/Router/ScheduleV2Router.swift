//
//  ScheduleV2Router.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation
internal import Alamofire
import Moya

/// 일정 V2 API 라우터
///
/// 서버 일정 도메인의 V1 → V2 마이그레이션에 따라 신설된 엔드포인트를 정의합니다.
/// V1 라우터(`ScheduleRouter`) 와 분리해 V2 마이그레이션 완료 후 V1 을 안전하게 제거할 수 있도록 합니다.
///
/// - SeeAlso: ``ScheduleRouter``
enum ScheduleV2Router {
    /// 일정 생성/수정 권한 사전 조회 (SCHEDULE-Q001)
    case getCapabilities
    /// 내 일정 목록 조회 (기간 + 출석 필수 필터)
    case getMySchedules(query: MySchedulesQuery)
    /// 일정 상세 조회
    case getScheduleDetail(scheduleId: Int)
    /// 일정 생성
    case postSchedule(request: GenerateScheduleRequetDTO)
    /// 일정 수정 (부분 갱신)
    case patchSchedule(scheduleId: Int, request: UpdateScheduleRequestDTO)
    /// 일정 삭제 (스터디 그룹 일정 2단계 실패 시 베스트 에포트 롤백 등)
    case deleteSchedule(scheduleId: Int)
    /// 운영진용 일정 출석 현황 목록 조회 (SCHEDULE-Q004)
    ///
    /// - `from` / `to` 미지정 시 서버 기본값(요청 시점 -1개월 ~ +24시간) 적용
    /// - `attendanceStatus` 미지정 시 모든 상태 반환
    /// - 직책별 조회 범위는 서버에서 자동 분기
    case getAttendanceList(query: AttendanceListQuery)
    /// 운영진용 단일 일정 출석 현황 조회 (SCHEDULE-Q005)
    case getAttendanceDetail(scheduleId: Int, query: AttendanceDetailQuery)
}

extension ScheduleV2Router: BaseTargetType {

    // MARK: - Path

    var path: String {
        switch self {
        case .getCapabilities:
            return "/api/v2/schedules/capabilities"
        case .getMySchedules:
            return "/api/v2/schedules/me"
        case .getScheduleDetail(let scheduleId):
            return "/api/v2/schedules/\(scheduleId)"
        case .postSchedule:
            return "/api/v2/schedules"
        case .patchSchedule(let scheduleId, _):
            return "/api/v2/schedules/\(scheduleId)"
        case .deleteSchedule(let scheduleId):
            return "/api/v2/schedules/\(scheduleId)"
        case .getAttendanceList:
            return "/api/v2/schedules/attendance"
        case .getAttendanceDetail(let scheduleId, _):
            return "/api/v2/schedules/\(scheduleId)/attendance"
        }
    }

    // MARK: - Method

    var method: Moya.Method {
        switch self {
        case .getCapabilities, .getMySchedules, .getScheduleDetail,
             .getAttendanceList, .getAttendanceDetail:
            return .get
        case .postSchedule:
            return .post
        case .patchSchedule:
            return .patch
        case .deleteSchedule:
            return .delete
        }
    }

    // MARK: - Task

    var task: Moya.Task {
        switch self {
        case .getCapabilities, .getScheduleDetail, .deleteSchedule:
            return .requestPlain
        case .getMySchedules(let query):
            return .requestParameters(
                parameters: query.toParameters,
                encoding: URLEncoding.queryString
            )
        case .postSchedule(let request):
            return .requestJSONEncodable(request)
        case .patchSchedule(_, let request):
            return .requestJSONEncodable(request)
        case .getAttendanceList(let query):
            return .requestParameters(
                parameters: query.toParameters,
                encoding: URLEncoding.queryString
            )
        case .getAttendanceDetail(_, let query):
            let params = query.toParameters
            guard !params.isEmpty else {
                return .requestPlain
            }
            return .requestParameters(
                parameters: params,
                encoding: URLEncoding.queryString
            )
        }
    }
}
