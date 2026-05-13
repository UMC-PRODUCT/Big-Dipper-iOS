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
/// 서버 일정 도메인의 V1 → V2 마이그레이션 완료 후 모든 V1 엔드포인트를 대체합니다.
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
    // TODO: [#688] 백엔드 OpenAPI 어노테이션 미등록 — 추가 후 Stella 재스캔 시 unmatched에서 제외 예정
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
    /// 출석 일괄 승인/반려 (V1 approve + reject 통합, SCHEDULE-0014)
    case decideAttendances(scheduleId: Int, body: [DecideAttendanceItemDTO])
    /// 사유 출석 제출 (V1 submitReason 대체, SCHEDULE-0015)
    case excuseAttendance(scheduleId: Int, body: ExcuseAttendanceRequestDTO)
    /// GPS 출석 요청 (V1 check 대체, SCHEDULE-0013)
    case requestAttendance(scheduleId: Int, body: RequestAttendanceRequestDTO)
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
        case .decideAttendances(let scheduleId, _):
            return "/api/v2/schedules/\(scheduleId)/attendances/decide"
        case .excuseAttendance(let scheduleId, _):
            return "/api/v2/schedules/\(scheduleId)/attendances/excuse"
        case .requestAttendance(let scheduleId, _):
            return "/api/v2/schedules/\(scheduleId)/attendances/request"
        }
    }

    // MARK: - Method

    var method: Moya.Method {
        switch self {
        case .getCapabilities, .getMySchedules, .getScheduleDetail,
             .getAttendanceList, .getAttendanceDetail:
            return .get
        case .postSchedule, .decideAttendances, .excuseAttendance, .requestAttendance:
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
        case .decideAttendances(_, let body):
            return .requestJSONEncodable(body)
        case .excuseAttendance(_, let body):
            return .requestJSONEncodable(body)
        case .requestAttendance(_, let body):
            return .requestJSONEncodable(body)
        }
    }
}
