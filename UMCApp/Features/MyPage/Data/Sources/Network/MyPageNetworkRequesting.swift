//
//  MyPageNetworkRequesting.swift
//  MyPageData
//
//  Created by 김동민 on 7/5/26.
//

import Foundation
import CoreNetwork
import Moya

/// Repository 를 단위 테스트하기 위한 **네트워크 요청 seam (테스트 목적 추상화)**.
///
/// - Important: 이 프로토콜은 **오직 테스트 가능성을 위해** 존재합니다.
///   **런타임 동작에는 아무 영향이 없습니다** — 운영 빌드에서 이 프로토콜을 채택하는 타입은
///   `MoyaNetworkAdapter` **단 하나**이고, `MyPageRepository` 의 public init 도 여전히
///   구체 `MoyaNetworkAdapter` 를 받습니다. (이 프로토콜을 없애고 Repository 가 구체 타입에
///   직접 의존해도 앱 동작은 동일합니다.) `internal` 이라 모듈 밖(다른 피처·앱)에는
///   노출되지 않습니다.
///
/// ### 왜 필요한가
/// 구체 타입 ``CoreNetwork/MoyaNetworkAdapter`` 는 actor 기반 `NetworkClient` 와
/// `NetworkConfig.baseURL`(테스트 번들에 `BASE_URL` 미주입 시 `fatalError`)에 묶여 있어
/// 단위 테스트에서 직접 대체할 수 없습니다. 그래서 Repository 는 이 프로토콜에만 의존하고,
/// 운영 코드는 `MoyaNetworkAdapter` 를, 테스트는 `.path`/`.method` 만 읽는 가짜 구현을 주입합니다.
///
/// - Note: MyPage 레포지토리는 인증 요청(`request`)과 비인증 공개 요청
///   (`requestWithoutAuth`, 약관 조회)을 모두 사용하므로 두 메서드를 함께 요구합니다.
///   `MoyaNetworkAdapter` 는 모듈 경계 밖에서 `Sendable` 로 노출되지 않으므로 본 프로토콜은
///   `Sendable` 을 요구하지 않으며, Repository 가 `@unchecked Sendable` 로 감쌉니다.
///
/// - SeeAlso: 동일 목적·동일 패턴의 선례 `ActivityData/Sources/Network/NetworkRequesting.swift`.
protocol MyPageNetworkRequesting {
    /// Moya `TargetType` 라우터로 인증 요청을 보내고 원시 `Response` 를 반환합니다.
    func request<T: TargetType>(_ target: T) async throws -> Response

    /// 인증 없이 공개 API 요청을 보내고 원시 `Response` 를 반환합니다 (예: 약관 조회).
    func requestWithoutAuth<T: TargetType>(_ target: T) async throws -> Response
}

// MARK: - MoyaNetworkAdapter 적합

/// 운영 빌드에서 이 프로토콜을 채택하는 **유일한 실제 타입**입니다.
/// `MoyaNetworkAdapter` 의 `request(_:)` / `requestWithoutAuth(_:)` 시그니처가
/// 프로토콜 요구사항과 정확히 일치하므로 빈 적합 선언만으로 충분합니다.
/// (그 외 채택자는 테스트 타깃의 가짜 구현뿐입니다.)
extension MoyaNetworkAdapter: MyPageNetworkRequesting {}
