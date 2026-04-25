//
//  Geofence.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 4/14/26.
//

import Foundation
import CoreLocation

/// 지오펜스 영역
///
/// 세션 장소를 중심으로 한 원형 영역으로, GPS 출석 유효 범위를 정의합니다.
public struct Geofence {
    public let center: Coordinate
    public let radiusInMeters: CLLocationDistance

    public init(center: Coordinate, radiusInMeters: CLLocationDistance) {
        self.center = center
        self.radiusInMeters = radiusInMeters
    }
}
