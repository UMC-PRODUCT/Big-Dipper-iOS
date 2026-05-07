//
//  AttendanceRouter.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/17/26.
//

import Foundation
internal import Alamofire
import Moya

enum AttendanceRouter {

    // MARK: - GET

    /// 승인 대기 목록 조회 (관리자)
    case getPending(scheduleId: Int)
    /// 승인 대기 목록 일괄 조회 (관리자)
    case getAllPending
}

// MARK: - BaseTargetType

extension AttendanceRouter: BaseTargetType {

    // MARK: - Path

    var path: String {
        switch self {
        case .getPending(let scheduleId):
            return "/api/v1/attendances/pending/\(scheduleId)"
        case .getAllPending:
            return "/api/v1/attendances/pending"
        }
    }

    // MARK: - Method

    var method: Moya.Method {
        switch self {
        case .getPending, .getAllPending:
            return .get
        }
    }

    // MARK: - Task

    var task: Moya.Task {
        switch self {
        case .getPending, .getAllPending:
            return .requestPlain
        }
    }
}
