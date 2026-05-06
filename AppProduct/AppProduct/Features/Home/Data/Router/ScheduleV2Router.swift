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
}

extension ScheduleV2Router: BaseTargetType {

    // MARK: - Path

    var path: String {
        switch self {
        case .getCapabilities:
            return "/api/v2/schedules/capabilities"
        }
    }

    // MARK: - Method

    var method: Moya.Method {
        switch self {
        case .getCapabilities:
            return .get
        }
    }

    // MARK: - Task

    var task: Moya.Task {
        switch self {
        case .getCapabilities:
            return .requestPlain
        }
    }
}
