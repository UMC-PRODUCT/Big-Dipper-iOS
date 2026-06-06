//
//  LocationProviding.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/20/26.
//

import Foundation

/// 위치/지오펜스/지오코딩 추상화
///
/// 챌린저 출석 UseCase 가 `LocationManager` 싱글톤에 직접 의존하지 않도록 분리한 Protocol.
/// Domain 레이어가 CoreLocation 에 의존하지 않게 하여 단위 테스트에서 Mock 주입을 가능하게 합니다.
///
/// ## 동시성 / Sendable
///
/// Swift 6 strict concurrency 에서 `async` 컨텍스트 cross-actor 접근 시 안전하도록 `Sendable` 채택.
/// 실제 구현체(`LocationManager`) 는 `@MainActor` 또는 actor 격리 등 자기 isolation 정책을 선택할 수 있습니다.
///
/// ## 멀티 지오펜스
///
/// 여러 활동이 동시에 진행될 수 있으므로 지오펜스 판정은 **식별자 기반**(`isInside(geofenceId:)`)을 권장합니다.
/// 단순 "어느 하나라도 안에 있는지"는 `isInsideAnyGeofence` 가 fallback 으로 노출됩니다 (UI 상태 표시 등).
///
/// - Note: 실제 구현체(`LocationManager`)는 후속 Core 모듈 이관에서 제공됩니다.
public protocol LocationProviding: Sendable {

    // MARK: - 상태

    /// 시스템 위치 권한이 부여된 상태인지
    var isAuthorized: Bool { get }

    /// 추적 중인 지오펜스 중 어느 하나라도 현재 위치가 안에 있는지 (fallback / UI 상태 표시용)
    ///
    /// - Important: 특정 지오펜스 안인지 검증할 때는 `isInside(geofenceId:)` 를 사용하세요.
    ///   본 프로퍼티는 멀티 지오펜스 시 어느 지오펜스인지 구분하지 않습니다.
    var isInsideAnyGeofence: Bool { get }

    /// 현재 위치 좌표 (위치 갱신 전이거나 권한이 없으면 nil)
    var currentCoordinate: Coordinate? { get }

    // MARK: - 액션

    /// 특정 지오펜스 식별자 안에 현재 위치가 있는지 판정
    ///
    /// 멀티 지오펜스(여러 활동 동시 진행) 시나리오에서도 정확한 판정을 보장합니다.
    /// - Parameter geofenceId: 출석/일정 등의 식별자 (스케줄 ID 와 1:1 매핑되는 운영 정책)
    func isInside(geofenceId: String) -> Bool

    /// 좌표 → 주소 역지오코딩 (도메인 모델 반환)
    /// - throws: `LocationError.geocodingFailed` 등 위치 관련 에러
    func reverseGeocode(coordinate: Coordinate) async throws -> Address

    /// 등록된 모든 지오펜스 모니터링 중지
    func stopAllGeofenceMonitoring() async
}
