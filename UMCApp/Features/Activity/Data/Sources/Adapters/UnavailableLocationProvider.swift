//
//  UnavailableLocationProvider.swift
//  ActivityData
//
//  Created by jaewon Lee on 7/26/26.
//

import Foundation
import ActivityDomain
import UMCFoundation

// TODO: #668 CoreFoundation LocationManager 이관 후 실 어댑터로 교체 - [26.07.26] jaewon Lee

/// 위치 기능이 아직 연결되지 않은 상태를 표현하는 ``ActivityDomain/LocationProviding`` 자리표시자.
///
/// CoreLocation 실 구현체(`LocationManager`)는 Core 모듈 이관에서 제공되며, 그 시점에
/// 이 타입 대신 해당 매니저를 감싸는 얇은 어댑터를 등록합니다. 그전까지 Activity 화면이
/// 컴파일·실행되도록 "권한 없음 · 좌표 없음" 상태를 일관되게 보고합니다.
///
/// ## 의도된 degraded 계약
///
/// 모든 위치 질의가 부정으로 답합니다. 결함이 아니라 **GPS 비의존 화면만 동작시키기 위한
/// 의도된 계약**이며, 더미 좌표·더미 주소로 침묵 성공해 위치 검증 없이 출석이 성립하는 일을
/// 막기 위해 실패를 명시적으로 드러냅니다.
///
/// `ChallengerAttendanceUseCase` 소비 경로별 결과:
///
/// - `requestGPSAttendance`: 권한 가드에서 `LocationError.notAuthorized` 로 중단
/// - `getAddressToCurrentLocation`: 좌표 가드에서 `LocationError.locationFailed` 로 중단
/// - `submitLateReason` / `submitAbsentReason`: **중단되지 않습니다.** UseCase 의
///   `submitExcuse` 가 좌표 부재를 `isVerified: false` + `(0, 0)` 폴백으로 처리해 제출이
///   성공합니다. 이 폴백은 자리표시자가 만든 동작이 아니라 UseCase 가 이미 갖고 있던 정책이나,
///   자리표시자가 주입된 빌드에서는 사유 제출이 **항상** 위치 미검증으로 기록됩니다.
///
/// - Note: `LocationManager` 의 복제가 아닙니다. CoreLocation 을 import 하지 않고,
///   지오펜스 등록·위치 갱신 등 어떤 상태도 보유하지 않는 무상태 stub 입니다.
public struct UnavailableLocationProvider: LocationProviding {

    // MARK: - Init

    public init() {}

    // MARK: - 상태

    /// 항상 `false` — 위치 권한을 요청하지도, 보유하지도 않습니다.
    public var isAuthorized: Bool { false }

    /// 항상 `false` — 모니터링 중인 지오펜스가 없습니다.
    public var isInsideAnyGeofence: Bool { false }

    /// 항상 `nil` — 위치 갱신을 수행하지 않습니다.
    public var currentCoordinate: Coordinate? { nil }

    // MARK: - 액션

    /// 항상 `false` — 지오펜스를 모니터링하지 않으므로 어떤 식별자도 내부로 판정하지 않습니다.
    public func isInside(geofenceId: String) -> Bool { false }

    /// 항상 실패합니다 — 역지오코딩을 수행할 백엔드가 없습니다.
    ///
    /// 프로토콜이 문서화한 실패 계약(`LocationError.geocodingFailed`)을 그대로 사용해,
    /// 호출부가 "주소를 가져올 수 없음" 을 기존 경로로 처리하게 합니다.
    public func reverseGeocode(coordinate: Coordinate) async throws -> Address {
        throw LocationError.geocodingFailed("위치 기능이 아직 연결되지 않았습니다.")
    }

    /// no-op — 등록된 모니터링이 없어 중지할 대상도 없습니다.
    public func stopAllGeofenceMonitoring() async {}
}
