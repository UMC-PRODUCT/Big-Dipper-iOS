//
//  CommunityThreadNetworkRequesting.swift
//  CommunityData
//

import CoreNetwork
import Foundation
import Moya

/// Repository 가 의존하는 인증 네트워크 요청 추상화.
///
/// 구체 타입 ``CoreNetwork/MoyaNetworkAdapter`` 는 actor 기반 `NetworkClient` 를 요구해
/// 단위 테스트에서 직접 대체하기 어렵습니다. Repository 는 이 프로토콜에만 의존하고,
/// 운영 코드에서는 `MoyaNetworkAdapter` 를, 테스트에서는 가짜 구현을 주입합니다.
///
/// - Note: `MoyaNetworkAdapter` 는 `public` 이지만 모듈 경계 밖에서 `Sendable` 로
///   노출되지 않으므로, 본 프로토콜은 `Sendable` 을 요구하지 않습니다. Repository 는
///   `@unchecked Sendable` 로 이 비-Sendable 의존성을 감쌉니다.
protocol CommunityThreadNetworkRequesting {
    /// Moya `TargetType` 라우터로 인증 요청을 보내고 원시 `Response` 를 반환합니다.
    func request<T: TargetType>(_ target: T) async throws -> Response
}

// MARK: - MoyaNetworkAdapter 적합

/// `MoyaNetworkAdapter.request(_:)` 시그니처가 프로토콜 요구사항과 정확히 일치하므로
/// 빈 적합 선언만으로 충분합니다.
extension MoyaNetworkAdapter: CommunityThreadNetworkRequesting {}
