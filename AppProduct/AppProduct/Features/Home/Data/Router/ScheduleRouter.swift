//
//  ScheduleRouter.swift
//  AppProduct
//
//  Created by euijjang97 on 2/12/26.
//

import Foundation
internal import Alamofire
import Moya

/// 일정 Feature API 라우터 (V1 잔여 엔드포인트)
///
/// 일정 생성/수정 V1 엔드포인트는 ``ScheduleV2Router`` 로 이전되었으며,
/// 본 라우터에는 V2 미마이그레이션 잔여 엔드포인트만 남아 있습니다.
enum ScheduleRouter {
    /// 일정 + 출석부 통합 삭제 (V2 마이그레이션 보류)
    case deleteScheduleWithAttendance(scheduleId: Int)
    /// 일정별 출석 통계 목록 조회 (관리자, Activity 도메인)
    case getScheduleList
}

extension ScheduleRouter: BaseTargetType {

    // MARK: - Path

    var path: String {
        switch self {
        case .deleteScheduleWithAttendance(let scheduleId):
            return "/api/v1/schedules/\(scheduleId)/with-attendance"
        case .getScheduleList:
            return "/api/v1/schedules"
        }
    }

    // MARK: - Method

    var method: Moya.Method {
        switch self {
        case .deleteScheduleWithAttendance:
            return .delete
        case .getScheduleList:
            return .get
        }
    }

    // MARK: - Task

    var task: Moya.Task {
        switch self {
        case .deleteScheduleWithAttendance, .getScheduleList:
            return .requestPlain
        }
    }
}
