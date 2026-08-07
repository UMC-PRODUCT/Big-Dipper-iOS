//
//  LocationManagerAdapterTests.swift
//  ActivityDataTests
//
//  Created by jaewon Lee on 7/30/26.
//

import CoreLocation
import Foundation
import Testing
import ActivityDomain
import UMCFoundation
@testable import ActivityData

// MARK: - Fixtures

/// 서울시청 좌표. 값 자체에 의미는 없고 변환이 값을 보존하는지만 봅니다.
private let seoulCityHall = Coordinate(latitude: 37.5665, longitude: 126.9780)

private func makeGeocoded(
    fullAddress: String = "서울특별시 중구 세종대로 110",
    shortAddress: String? = "세종대로 110",
    city: String? = "서울특별시",
    district: String? = "중구"
) -> GeocodedAddress {
    GeocodedAddress(
        fullAddress: fullAddress,
        shortAddress: shortAddress,
        city: city,
        district: district
    )
}

// MARK: - Suite: 좌표 변환

@Suite("LocationManagerAdapter — Core ↔ Domain 좌표 변환 (도메인 규칙)")
struct LocationCoordinateConversionTests {

    @Test("도메인 좌표 → CoreLocation 좌표는 위경도를 보존한다")
    func domainToCoreLocationPreservesValues() {
        let converted = CLLocationCoordinate2D(seoulCityHall)

        #expect(converted.latitude == seoulCityHall.latitude)
        #expect(converted.longitude == seoulCityHall.longitude)
    }

    @Test("CoreLocation 좌표 → 도메인 좌표는 위경도를 보존한다")
    func coreLocationToDomainPreservesValues() {
        let source = CLLocationCoordinate2D(latitude: 35.1796, longitude: 129.0756)

        let converted = Coordinate(source)

        #expect(converted == Coordinate(latitude: 35.1796, longitude: 129.0756))
    }

    /// 위경도가 뒤바뀌면 지오펜스 판정이 통째로 틀어지므로 왕복으로 고정합니다.
    @Test(
        "좌표 왕복 변환이 원본과 같다",
        arguments: [
            Coordinate(latitude: 37.5665, longitude: 126.9780),
            Coordinate(latitude: -33.8688, longitude: 151.2093),
            Coordinate(latitude: 0, longitude: 0)
        ]
    )
    func coordinateRoundTripIsLossless(coordinate: Coordinate) {
        #expect(Coordinate(CLLocationCoordinate2D(coordinate)) == coordinate)
    }
}

// MARK: - Suite: 주소 변환

@Suite("LocationManagerAdapter — 역지오코딩 결과 → 도메인 주소 (도메인 규칙)")
struct GeocodedAddressConversionTests {

    @Test("시/구가 모두 있으면 그대로 옮긴다")
    func mapsPresentFields() {
        let address = Address(makeGeocoded())

        #expect(address == Address(
            fullAddress: "서울특별시 중구 세종대로 110",
            city: "서울특별시",
            district: "중구"
        ))
    }

    /// `GeocodedAddress` 의 시/구는 옵셔널인데 도메인 `Address` 는 비옵셔널이라,
    /// 누락 시 빈 문자열로 떨어지는 경로가 실제로 실행되는지 확인합니다.
    @Test(
        "시/구가 없으면 빈 문자열로 채운다",
        arguments: [
            (nil as String?, nil as String?, "", ""),
            ("서울특별시", nil as String?, "서울특별시", ""),
            (nil as String?, "중구", "", "중구")
        ]
    )
    func fillsMissingFieldsWithEmptyString(
        city: String?,
        district: String?,
        expectedCity: String,
        expectedDistrict: String
    ) {
        let address = Address(makeGeocoded(city: city, district: district))

        #expect(address.city == expectedCity)
        #expect(address.district == expectedDistrict)
    }

    @Test("전체 주소는 변형 없이 그대로 전달한다")
    func passesFullAddressThrough() {
        let address = Address(makeGeocoded(fullAddress: "부산광역시 해운대구"))

        #expect(address.fullAddress == "부산광역시 해운대구")
    }

    /// `shortAddress` 가 도메인 모델에 대응 필드 없이 버려지는 것은 의도된 손실입니다.
    /// 나중에 `Address` 에 필드가 추가되면 이 테스트가 실패하며 변환 확장을 상기시킵니다.
    @Test("shortAddress 유무는 변환 결과를 바꾸지 않는다")
    func shortAddressDoesNotAffectResult() {
        let withShort = Address(makeGeocoded(shortAddress: "세종대로 110"))
        let withoutShort = Address(makeGeocoded(shortAddress: nil))

        #expect(withShort == withoutShort)
    }
}

// MARK: - Suite: 메인 액터 접근 계약

@Suite("LocationManagerAdapter — 메인 액터 접근 계약 (도메인 규칙)")
@MainActor
struct LocationManagerAdapterMainActorTests {

    /// 상태 멤버는 `@MainActor` 인 매니저를 `MainActor.assumeIsolated` 로 읽으므로, 메인 액터
    /// 호출에서는 트랩 없이 값을 돌려줘야 합니다. 격리 전제가 깨지면(비격리 경로로 바뀌면)
    /// 이 테스트가 트랩으로 실패해 결선 실수를 드러냅니다.
    ///
    /// 반환값 자체는 호스트의 위치 권한·GPS 상태에 좌우돼 결정론적이지 않으므로 단언하지
    /// 않습니다. 분기 로직은 위 두 변환 스위트가 덮습니다.
    @Test("메인 액터에서 상태 멤버 접근이 트랩 없이 성립한다")
    func stateAccessSucceedsOnMainActor() {
        let adapter: any LocationProviding = LocationManagerAdapter()

        _ = adapter.isAuthorized
        _ = adapter.isInsideAnyGeofence
        _ = adapter.currentCoordinate
        _ = adapter.isInside(geofenceId: "schedule-1")
    }
}
