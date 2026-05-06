//
//  HomeRouter.swift
//  AppProduct
//
//  Created by euijjang97 on 2/11/26.
//

import Foundation
internal import Alamofire
import Moya

/// 홈 Feature API 라우터
///
/// 홈 대시보드에 필요한 API 엔드포인트를 정의합니다.
/// 일정 관련 V1 엔드포인트는 V2 마이그레이션으로 ``ScheduleV2Router`` 로 이전되었습니다.
enum HomeRouter {
    /// 내 프로필 조회 (기수 + 역할 정보)
    case getGen
    /// 최근 공지사항 조회
    case getNoticeRecent(query: NoticeListRequestDTO)
    /// 기수 상세 조회
    case getGisuDetail(gisuId: Int)
    /// FCM 토큰 등록/갱신
    case putFCMToken(request: RegisterFCMTokenRequestDTO)
}

extension HomeRouter: BaseTargetType {

    // MARK: - Path

    var path: String {
        switch self {
        case .getGen:
            return "/api/v1/member/me"
        case .getNoticeRecent:
            return "/api/v1/notices"
        case .getGisuDetail(let gisuId):
            return "/api/v1/gisu/\(gisuId)"
        case .putFCMToken:
            return "/api/v1/notification/fcm/token"
        }
    }

    // MARK: - Method

    var method: Moya.Method {
        switch self {
        case .getGen, .getNoticeRecent, .getGisuDetail:
            return .get
        case .putFCMToken:
            return .put
        }
    }

    // MARK: - Task

    var task: Moya.Task {
        switch self {
        case .getGen:
            return .requestPlain
        case .getNoticeRecent(let query):
            return .requestParameters(
                parameters: query.queryItems,
                encoding: URLEncoding.queryString
            )
        case .getGisuDetail:
            return .requestPlain
        case .putFCMToken(let request):
            return .requestJSONEncodable(request)
        }
    }
}
