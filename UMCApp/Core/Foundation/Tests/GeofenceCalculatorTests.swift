//
//  GeofenceCalculatorTests.swift
//  UMCFoundationTests
//
//  Created by jaewon Lee on 1/6/26.
//

import CoreLocation
import Testing
@testable import UMCFoundation

@Suite("GeofenceCalculator — 지오펜스 거리·판정 순수 로직")
struct GeofenceCalculatorTests {

    /// 서울시청 좌표 (기준점)
    private let seoulCityHall = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)

    @Test("동일 좌표의 거리는 0에 가깝다")
    func distanceToSelfIsZero() {
        let distance = GeofenceCalculator.distance(from: seoulCityHall, to: seoulCityHall)
        #expect(distance == 0)
    }

    @Test("위도 1도 차이는 약 111km(허용 오차 내)")
    func distanceOneDegreeLatitude() {
        let oneDegreeNorth = CLLocationCoordinate2D(
            latitude: seoulCityHall.latitude + 1,
            longitude: seoulCityHall.longitude
        )
        let distance = GeofenceCalculator.distance(from: seoulCityHall, to: oneDegreeNorth)
        #expect((110_000...112_000).contains(distance))
    }

    @Test("반경 이내 좌표는 isInside == true")
    func isInsideTrueWhenWithinRadius() {
        let nearbyPoint = CLLocationCoordinate2D(
            latitude: seoulCityHall.latitude + 0.0001,
            longitude: seoulCityHall.longitude
        )
        let isInside = GeofenceCalculator.isInside(
            current: nearbyPoint,
            center: seoulCityHall,
            radius: 100
        )
        #expect(isInside == true)
    }

    @Test("반경 밖 좌표는 isInside == false")
    func isInsideFalseWhenOutsideRadius() {
        let farPoint = CLLocationCoordinate2D(
            latitude: seoulCityHall.latitude + 1,
            longitude: seoulCityHall.longitude
        )
        let isInside = GeofenceCalculator.isInside(
            current: farPoint,
            center: seoulCityHall,
            radius: 100
        )
        #expect(isInside == false)
    }

    @Test("경계값(정확히 반경)은 isInside == true (이하 포함)")
    func isInsideBoundaryIsInclusive() {
        let center = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let boundaryPoint = CLLocationCoordinate2D(latitude: 0.001, longitude: 0)
        let radius = GeofenceCalculator.distance(from: boundaryPoint, to: center)

        let isInside = GeofenceCalculator.isInside(
            current: boundaryPoint,
            center: center,
            radius: radius
        )
        #expect(isInside == true)
    }

    // MARK: - isInside(geofenceId:current:geofences:)

    @Test("등록된 식별자의 반경 안이면 true")
    func isInsideGeofenceIdTrueWhenWithinRadius() {
        let nearbyPoint = CLLocationCoordinate2D(
            latitude: seoulCityHall.latitude + 0.0001,
            longitude: seoulCityHall.longitude
        )
        let isInside = GeofenceCalculator.isInside(
            geofenceId: "schedule-100",
            current: nearbyPoint,
            geofences: ["schedule-100": MonitoredGeofence(center: seoulCityHall, radius: 100)]
        )
        #expect(isInside == true)
    }

    @Test("등록된 식별자의 반경 밖이면 false")
    func isInsideGeofenceIdFalseWhenOutsideRadius() {
        let farPoint = CLLocationCoordinate2D(
            latitude: seoulCityHall.latitude + 1,
            longitude: seoulCityHall.longitude
        )
        let isInside = GeofenceCalculator.isInside(
            geofenceId: "schedule-100",
            current: farPoint,
            geofences: ["schedule-100": MonitoredGeofence(center: seoulCityHall, radius: 100)]
        )
        #expect(isInside == false)
    }

    @Test("다른 식별자가 반경 안이어도 요청한 식별자가 미등록이면 false")
    func isInsideGeofenceIdFalseWhenIdentifierNotRegistered() {
        let isInside = GeofenceCalculator.isInside(
            geofenceId: "schedule-999",
            current: seoulCityHall,
            geofences: ["schedule-100": MonitoredGeofence(center: seoulCityHall, radius: 100)]
        )
        #expect(isInside == false)
    }

    @Test("현재 위치를 모르면 등록된 식별자여도 false")
    func isInsideGeofenceIdFalseWhenCurrentLocationMissing() {
        let isInside = GeofenceCalculator.isInside(
            geofenceId: "schedule-100",
            current: nil,
            geofences: ["schedule-100": MonitoredGeofence(center: seoulCityHall, radius: 100)]
        )
        #expect(isInside == false)
    }
}
