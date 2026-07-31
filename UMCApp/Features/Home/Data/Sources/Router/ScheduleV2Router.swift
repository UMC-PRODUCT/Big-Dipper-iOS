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
/// 홈 일정 캘린더 표시에 필요한 목록 조회만 다룬다. 출석 관련 엔드포인트
/// (`/api/v2/schedules/attendance`, `/api/v2/schedules/{id}/attendance`,
/// `.../attendances/decide`, `.../attendances/excuse`, `.../attendances/request`)는
/// `ActivityData`의 `AttendanceRouter`에 있다. 일정 생성/수정/삭제는 Schedule 모듈 분리
/// 이슈(#981)에서 다룬다.
///
/// - Note: `URLEncoding`(Alamofire) 노출을 막기 위해 `internal import Alamofire`를 쓰므로,
///   이 라우터와 멤버는 `HomeData` 모듈 내부(`ScheduleRepository`)에서만 사용하는 `internal`로 둔다.
enum ScheduleV2Router: BaseTargetType {

    // MARK: - Cases

    /// 내 일정 목록 조회 (기간 + 출석 필수 필터)
    case getMySchedules(query: MySchedulesQuery)

    // MARK: - Path

    var path: String {
        switch self {
        case .getMySchedules:
            return "/api/v2/schedules/me"
        }
    }

    // MARK: - Method

    var method: Moya.Method {
        switch self {
        case .getMySchedules:
            return .get
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
        }
    }
}
