//
//  BaseMapViewModelTests.swift
//  ActivityPresentationTests
//
//  Created by jaewon Lee on 7/30/26.
//

import ActivityDomain
import Foundation
import MapKit
import Testing
import UMCFoundation

@testable import ActivityPresentation

// MARK: - Helpers

/// 결정론적 기준 시각 (epoch 100_000) — wall-clock 비의존
private let fixedNow = Date(timeIntervalSince1970: 100_000)

/// 좌표 비교 허용 오차 (부동소수 표현 오차만 흡수)
private let coordinateTolerance = 0.000_001

private func makeSessionInfo(
    sessionId: String = "S-1",
    latitude: Double = 37.5,
    longitude: Double = 127.0
) -> SessionInfo {
    SessionInfo(
        sessionId: SessionID(value: sessionId),
        iconName: "calendar.badge",
        title: "1주차 OT",
        week: 1,
        startTime: fixedNow,
        endTime: fixedNow.addingTimeInterval(3_600),
        location: Coordinate(latitude: latitude, longitude: longitude)
    )
}

@MainActor
private func makeViewModel(
    info: SessionInfo = makeSessionInfo(),
    geofenceId: String = "SCH-100"
) -> BaseMapViewModel {
    BaseMapViewModel(
        info: info,
        scheduleId: geofenceId,
        errorHandler: ErrorHandler()
    )
}

// MARK: - 카메라 초기화

// Suite 전체 @MainActor — SUT(BaseMapViewModel)가 @MainActor 격리이므로 필요.
@MainActor
@Suite("BaseMapViewModel — 카메라 초기 위치 (도메인 규칙)")
struct BaseMapViewModelCameraTests {

    @Test("초기 카메라는 세션 좌표를 중심으로 잡힌다")
    func initialCameraCentersOnSession() throws {
        let viewModel = makeViewModel(
            info: makeSessionInfo(latitude: 35.1595, longitude: 129.0756)
        )

        let region = try #require(viewModel.cameraPosition.region)

        #expect(abs(region.center.latitude - 35.1595) < coordinateTolerance)
        #expect(abs(region.center.longitude - 129.0756) < coordinateTolerance)
    }

    @Test("초기 카메라 스팬은 세션 주변을 확대해 보여준다")
    func initialCameraUsesCloseUpSpan() throws {
        let viewModel = makeViewModel()

        let region = try #require(viewModel.cameraPosition.region)

        // 지오펜스 반경(50m)이 화면에 담기려면 위경도 델타가 충분히 작아야 한다.
        #expect(region.span.latitudeDelta == 0.002)
        #expect(region.span.longitudeDelta == 0.002)
    }
}

// MARK: - 세션 좌표 변환

@MainActor
@Suite("BaseMapViewModel — 세션 좌표 변환 (도메인 규칙)")
struct BaseMapViewModelSessionLocationTests {

    @Test(
        "도메인 Coordinate 가 지도 좌표로 순서 뒤바뀜 없이 변환된다",
        arguments: [
            (37.5665, 126.9780),
            (-33.8688, 151.2093),
            (0.0, 0.0),
        ]
    )
    func sessionLocationMapsCoordinateVerbatim(latitude: Double, longitude: Double) {
        let viewModel = makeViewModel(
            info: makeSessionInfo(latitude: latitude, longitude: longitude)
        )

        #expect(abs(viewModel.sessionLocation.latitude - latitude) < coordinateTolerance)
        #expect(abs(viewModel.sessionLocation.longitude - longitude) < coordinateTolerance)
    }
}

// MARK: - 지오펜스 계약

@MainActor
@Suite("BaseMapViewModel — 지오펜스 식별자 계약 (도메인 규칙)")
struct BaseMapViewModelGeofenceContractTests {

    /// 박제 테스트 — 레거시(AppProduct)는 지오펜스를 `"Session_\(sessionId)"` 로 **파생**해
    /// 등록했다. UMCApp 의 출석 판정은 `LocationProviding.isInside(geofenceId: scheduleId)` 로
    /// 서버 `scheduleId` 를 조회하므로, 파생 규칙을 그대로 옮기면 등록 식별자와 조회 식별자가
    /// 어긋나 GPS 출석이 항상 범위 밖으로 거부된다. 그래서 주입값을 변형 없이 보존한다.
    @Test("주입한 지오펜스 식별자를 변형 없이 보존한다 (sessionId 파생 금지)")
    func geofenceIdIsNotDerivedFromSessionId() {
        let viewModel = makeViewModel(
            info: makeSessionInfo(sessionId: "S-1"),
            geofenceId: "SCH-100"
        )

        #expect(viewModel.geofenceId == "SCH-100")
        #expect(viewModel.geofenceId != "Session_S-1")
    }
}
