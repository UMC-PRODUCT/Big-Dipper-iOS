//
//  UnavailableLocationProviderTests.swift
//  ActivityDataTests
//
//  Created by jaewon Lee on 7/26/26.
//

import Foundation
import Testing
import ActivityDomain
import UMCFoundation
@testable import ActivityData

// MARK: - Fixtures

/// 역지오코딩 입력용 고정 좌표(서울시청). 자리표시자는 좌표와 무관하게 항상 실패하므로
/// 값 자체는 검증 대상이 아니며, 호출이 좌표를 받는다는 사실만 표현합니다.
private let fixedCoordinate = Coordinate(latitude: 37.5665, longitude: 126.9780)

// MARK: - Suite: 위치 미연결 자리표시자 계약

@Suite("UnavailableLocationProvider — 위치 미연결 degraded 계약 (도메인 규칙)")
struct UnavailableLocationProviderTests {

    // MARK: - 상태 보고

    @Test("위치 권한을 보유하지 않아 GPS 출석 경로가 권한 가드에서 차단된다")
    func reportsUnauthorized() {
        #expect(UnavailableLocationProvider().isAuthorized == false)
    }

    @Test("현재 좌표를 제공하지 않는다")
    func reportsNoCoordinate() {
        #expect(UnavailableLocationProvider().currentCoordinate == nil)
    }

    @Test("모니터링 중인 지오펜스가 없어 어느 지오펜스 안에도 있지 않다")
    func reportsOutsideAnyGeofence() {
        #expect(UnavailableLocationProvider().isInsideAnyGeofence == false)
    }

    @Test(
        "어떤 지오펜스 식별자도 내부로 판정하지 않는다",
        arguments: ["schedule-1", "schedule-2", ""]
    )
    func reportsOutsideEveryGeofence(geofenceId: String) {
        #expect(UnavailableLocationProvider().isInside(geofenceId: geofenceId) == false)
    }

    @Test("모니터링 중지는 호출해도 계약이 중립으로 유지되는 no-op 이다")
    func stopAllGeofenceMonitoringIsNoOp() async {
        let provider = UnavailableLocationProvider()

        await provider.stopAllGeofenceMonitoring()

        #expect(provider.isInsideAnyGeofence == false)
    }

    // MARK: - 명시적 실패

    @Test("reverseGeocode — 더미 주소로 침묵 성공하지 않고 geocodingFailed 로 실패한다")
    func reverseGeocodeThrowsGeocodingFailed() async throws {
        let provider = UnavailableLocationProvider()

        let thrown = await #expect(throws: LocationError.self) {
            _ = try await provider.reverseGeocode(coordinate: fixedCoordinate)
        }

        let error = try #require(thrown)
        guard case .geocodingFailed(let message) = error else {
            Issue.record("LocationError.geocodingFailed 여야 함 — 실제: \(error)")
            return
        }

        #expect(message.isEmpty == false)
    }
}
