//
//  GeofenceCalculator.swift
//  UMCFoundation
//
//  Created by jaewon Lee on 1/6/26.
//

import CoreLocation

/// 모니터링 중인 지오펜스의 중심/반경
///
/// `LocationManager`와 `GeofenceCalculator` 양쪽에서 식별자 기반 판정에 쓰는 값 타입이라
/// 모듈 내부(`GeofenceCalculator.swift`)에 둡니다. Core 밖으로 노출할 필요가 없어 internal.
struct MonitoredGeofence {
    let center: CLLocationCoordinate2D
    let radius: CLLocationDistance
}

/// 지오펜스 판정에 쓰이는 순수 거리 계산 로직
///
/// `CLLocationManager`/`CLMonitor` 상태에 의존하지 않는 값 계산만 모아 두어
/// 델리게이트 없이도 단위 테스트가 가능하도록 `LocationManager`에서 분리했습니다.
enum GeofenceCalculator {

    // MARK: - Function

    /// 두 좌표 사이의 거리(미터)
    static func distance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }

    /// 현재 위치가 지정된 중심/반경의 지오펜스 안에 있는지 판정
    static func isInside(
        current: CLLocationCoordinate2D,
        center: CLLocationCoordinate2D,
        radius: CLLocationDistance
    ) -> Bool {
        distance(from: current, to: center) <= radius
    }

    /// 식별자로 등록된 지오펜스 기준 판정
    ///
    /// 등록되지 않은 식별자거나 현재 위치를 모르면 `false`. 여러 지오펜스가 동시에
    /// 모니터링 중이어도 요청한 식별자의 조건만으로 판정한다(다른 식별자 상태는 영향 없음).
    static func isInside(
        geofenceId: String,
        current: CLLocationCoordinate2D?,
        geofences: [String: MonitoredGeofence]
    ) -> Bool {
        guard let current, let geofence = geofences[geofenceId] else { return false }
        return isInside(current: current, center: geofence.center, radius: geofence.radius)
    }
}
