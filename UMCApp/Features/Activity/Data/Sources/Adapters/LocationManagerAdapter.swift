//
//  LocationManagerAdapter.swift
//  ActivityData
//
//  Created by jaewon Lee on 7/30/26.
//

import CoreLocation
import Foundation
import ActivityDomain
import UMCFoundation

/// canonical ``UMCFoundation/LocationManager`` 를 ``ActivityDomain/LocationProviding`` 에
/// 연결하는 얇은 어댑터.
///
/// 위치 로직을 재구현하지 않습니다. Core 모듈은 Feature 타입(`Coordinate`/`Address`)에 의존할
/// 수 없어 `CLLocationCoordinate2D`/`GeocodedAddress` 로만 값을 노출하므로, 이 어댑터가 그
/// 경계에서 타입만 변환하고 판정·모니터링은 전부 매니저에 위임합니다.
///
/// ## 격리
///
/// `LocationManager` 는 `@MainActor` 인데 ``ActivityDomain/LocationProviding`` 의 상태 멤버는
/// 비격리 동기 계약입니다. 소비 경로(`ChallengerAttendanceViewModel` → `ChallengerAttendanceUseCase`)
/// 가 모두 메인 액터에서 실행되므로 `MainActor.assumeIsolated` 로 읽습니다. 메인 액터 밖에서
/// 호출되면 잘못된 값을 조용히 반환하는 대신 즉시 트랩되어 결선 실수를 드러냅니다.
///
/// 저장 프로퍼티가 없어 `Sendable` 요구를 자동으로 충족합니다.
public struct LocationManagerAdapter: LocationProviding {

    // MARK: - Init

    public init() {}

    // MARK: - 상태

    public var isAuthorized: Bool {
        MainActor.assumeIsolated { LocationManager.shared.isAuthorized }
    }

    /// 추적 중인 지오펜스 안에 있는지 (UI 표시용 fallback).
    ///
    /// - Note: 매니저의 `isInsideGeofence` 는 마지막으로 등록된 `activeGeofenceId` **하나만**
    ///   추적하므로, 여러 지오펜스가 동시에 등록되면 "어느 하나라도" 를 정확히 답하지 못합니다.
    ///   프로토콜이 이 프로퍼티를 표시용 fallback 으로 규정하고 특정 지오펜스 판정에는
    ///   ``isInside(geofenceId:)`` 를 쓰도록 안내하는 것과 같은 한계입니다.
    public var isInsideAnyGeofence: Bool {
        MainActor.assumeIsolated { LocationManager.shared.isInsideGeofence }
    }

    public var currentCoordinate: Coordinate? {
        MainActor.assumeIsolated {
            guard let location = LocationManager.shared.currentLocation else { return nil }
            return Coordinate(location)
        }
    }

    // MARK: - 액션

    public func isInside(geofenceId: String) -> Bool {
        MainActor.assumeIsolated {
            LocationManager.shared.isInside(geofenceId: geofenceId)
        }
    }

    public func reverseGeocode(coordinate: Coordinate) async throws -> Address {
        let geocoded = try await LocationManager.shared.reverseGeocode(
            coordinate: CLLocationCoordinate2D(coordinate)
        )
        return Address(geocoded)
    }

    public func stopAllGeofenceMonitoring() async {
        await LocationManager.shared.stopAllGeofenceMonitoring()
    }
}

// MARK: - Core ↔ Domain 타입 변환

extension Coordinate {

    /// CoreLocation 좌표를 도메인 좌표로 변환합니다.
    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

extension CLLocationCoordinate2D {

    /// 도메인 좌표를 CoreLocation 좌표로 변환합니다.
    init(_ coordinate: Coordinate) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

extension Address {

    /// 역지오코딩 결과를 도메인 주소로 변환합니다.
    ///
    /// 도메인 `Address` 는 시/구를 비옵셔널로 요구하는데 `GeocodedAddress` 는 MapKit 응답을
    /// 손실 없이 담느라 둘 다 옵셔널입니다. 값이 없으면 빈 문자열로 채웁니다 — 표시 계층이
    /// 이미 빈 문자열을 "정보 없음" 으로 다루므로 별도 실패로 승격하지 않습니다.
    ///
    /// `shortAddress` 는 도메인 모델에 대응 필드가 없어 여기서 버려집니다. 짧은 주소 표기가
    /// 필요해지면 `Address` 에 필드를 추가하고 이 변환을 함께 넓혀야 합니다.
    init(_ geocoded: GeocodedAddress) {
        self.init(
            fullAddress: geocoded.fullAddress,
            city: geocoded.city ?? "",
            district: geocoded.district ?? ""
        )
    }
}
