//
//  ScheduleV2Router.swift
//  HomeData
//
//  Created by euijjang97 on 7/11/26.
//

import CoreNetwork
import Foundation
internal import Alamofire
import Moya

/// 일정 V2 API 라우터
///
/// 일정 도메인의 목록·권한 조회와 생성/삭제를 다룬다. 출석 관련 엔드포인트
/// (`/api/v2/schedules/attendance`, `/api/v2/schedules/{id}/attendance`,
/// `.../attendances/decide`, `.../attendances/excuse`, `.../attendances/request`)는
/// `ActivityData`의 `AttendanceRouter`에 있다.
///
/// - Note: `URLEncoding`(Alamofire) 노출을 막기 위해 `internal import Alamofire`를 쓰므로,
///   이 라우터와 멤버는 `HomeData` 모듈 내부(`ScheduleRepository`)에서만 사용하는 `internal`로 둔다.
enum ScheduleV2Router: BaseTargetType {

    // MARK: - Cases

    /// 내 일정 목록 조회 (기간 + 출석 필수 필터)
    case getMySchedules(query: MySchedulesQuery)
    /// 단일 일정 상세 조회 (`deleteSchedule` 과 경로가 같고 method 로만 갈린다)
    case getScheduleDetail(scheduleId: String)
    /// 일정 생성/수정 권한 조회 (생성 가능 여부 · 출석 정책 부착 권한 · 최대 초대 인원)
    case getCapabilities
    /// 일정 생성
    case postSchedule(body: ScheduleCreateRequestDTO)
    /// 일정 수정 (부분 갱신 — 본문에 실린 필드만 반영된다)
    case patchSchedule(scheduleId: String, body: ScheduleUpdateRequestDTO)
    /// 일정 삭제 (스터디 일정 등록 2단계 실패 시 1단계 롤백 등)
    case deleteSchedule(scheduleId: String)
    /// 일정 강제 삭제 (출석 기록이 있어 일반 삭제가 거부된 일정 — 서버가 권한을 검증한다)
    case forceDeleteSchedule(scheduleId: String)

    // MARK: - Path

    var path: String {
        switch self {
        case .getMySchedules:
            return "/api/v2/schedules/me"
        case .getCapabilities:
            return "/api/v2/schedules/capabilities"
        case .postSchedule:
            return "/api/v2/schedules"
        case .getScheduleDetail(let scheduleId), .deleteSchedule(let scheduleId):
            return "/api/v2/schedules/\(scheduleId)"
        case .patchSchedule(let scheduleId, _):
            return "/api/v2/schedules/\(scheduleId)"
        case .forceDeleteSchedule(let scheduleId):
            return "/api/v2/schedules/\(scheduleId)/force"
        }
    }

    // MARK: - Method

    var method: Moya.Method {
        switch self {
        case .getMySchedules, .getScheduleDetail, .getCapabilities:
            return .get
        case .postSchedule:
            return .post
        case .patchSchedule:
            return .patch
        case .deleteSchedule, .forceDeleteSchedule:
            return .delete
        }
    }

    // MARK: - Task

    var task: Moya.Task {
        switch self {
        case .getMySchedules(let query):
            return .requestParameters(
                parameters: query.toParameters,
                encoding: URLEncoding.queryString
            )
        case .postSchedule(let body):
            return .requestJSONEncodable(body)
        case .patchSchedule(_, let body):
            return .requestJSONEncodable(body)
        case .getScheduleDetail, .getCapabilities, .deleteSchedule, .forceDeleteSchedule:
            return .requestPlain
        }
    }
}
