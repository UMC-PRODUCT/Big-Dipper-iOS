//
//  HomeRouter.swift
//  HomeData
//
//  Created by euijjang97 on 7/9/26.
//

import CoreNetwork
import Foundation
import Moya

/// Home 관련 API 엔드포인트 정의.
///
/// - Note: 내 프로필 조회는 정본 파이프라인(`CoreDomain.MemberProfileRepositoryProtocol` →
///   `CoreNetwork.MemberProfileRouter.getMyProfile`)으로 이관되어 이 라우터에서는 제거됐다.
///   `getGisuDetail`은 시즌 카드의 "누적 활동일"을 실제 값으로 계산하려면 기수 시작일이
///   필요해 유지한다.
public enum HomeRouter: BaseTargetType {

    // MARK: - Cases

    /// 기수 상세 조회 (시즌 카드의 활동일 계산용 시작일 조회)
    case getGisuDetail(gisuId: String)

    /// FCM 설치 등록/갱신 (설치 단위 upsert)
    ///
    /// - Note: 토큰만 보내던 `PUT /api/v1/notification/fcm/token` 은 서버에서 제거돼 404를
    ///   반환한다(서버 회귀 테스트 `FcmControllerTest.token_only_등록_API_비활성화`). 그래서
    ///   이 기기로는 푸시가 전혀 도착하지 않았고, 설치 단위 등록 엔드포인트로 대체한다.
    /// - Note: 요청 바디 DTO(``RegisterFCMTokenRequestDTO``)는 모듈 내부 타입이라 연관값으로
    ///   노출할 수 없어, 필드를 문자열로 받아 ``task`` 에서 DTO로 감싼다.
    case postFCMInstallation(
        installationId: String,
        fcmToken: String,
        platform: String,
        appVersion: String
    )

    // MARK: - Path

    public var path: String {
        switch self {
        case .getGisuDetail(let gisuId):
            return "/api/v1/gisu/\(gisuId)"
        case .postFCMInstallation:
            return "/api/v1/notifications/fcm/installations"
        }
    }

    // MARK: - Method

    public var method: Moya.Method {
        switch self {
        case .getGisuDetail:
            return .get
        case .postFCMInstallation:
            return .post
        }
    }

    // MARK: - Task

    public var task: Moya.Task {
        switch self {
        case .getGisuDetail:
            return .requestPlain
        case let .postFCMInstallation(installationId, fcmToken, platform, appVersion):
            return .requestJSONEncodable(
                RegisterFCMTokenRequestDTO(
                    installationId: installationId,
                    fcmToken: fcmToken,
                    platform: platform,
                    appVersion: appVersion
                )
            )
        }
    }
}
