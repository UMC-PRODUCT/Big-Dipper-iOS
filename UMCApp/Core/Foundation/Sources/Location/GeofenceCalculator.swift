//
//  GeofenceCalculator.swift
//  UMCFoundation
//
//  Created by jaewon Lee on 1/6/26.
//

import CoreLocation

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
}
