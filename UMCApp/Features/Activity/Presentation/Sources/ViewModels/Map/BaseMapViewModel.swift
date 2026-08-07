//
//  BaseMapViewModel.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/30/26.
//

import ActivityDomain
import Foundation
import MapKit
import SwiftUI
import UMCFoundation

/// 지도 뷰의 카메라·지오펜스·주소 상태를 관리하는 ViewModel
///
/// 세션 위치 표시, 출석용 지오펜스 등록, 역지오코딩을 담당합니다.
///
/// ## 지오펜스 식별자 계약
///
/// `geofenceId` 는 **출석 판정이 조회하는 식별자와 반드시 같아야** 합니다.
/// `ChallengerAttendanceUseCase.requestGPSAttendance(...)` 가
/// `LocationProviding.isInside(geofenceId: scheduleId)` 로 판정하므로, 화면은 해당 일정의
/// 서버 `scheduleId` 를 그대로 넘겨야 합니다. 식별자가 어긋나면 지오펜스가 등록돼 있어도
/// 조회 대상이 없어 판정이 항상 `false` 가 되고 출석이 범위 밖으로 거부됩니다.
/// 그래서 명명 규칙을 이 타입 안에 감추지 않고 호출부가 명시적으로 주입합니다.
///
/// - Note: 지오펜스 해제는 화면이 아니라 출석 흐름의 종료 시점에 일어납니다
///   (`ChallengerAttendanceViewModel.geofenceCleanup()` → `stopAllGeofenceMonitoring()`).
///   지도는 위치 갱신만 화면 생명주기에 맞춰 시작/중지합니다.
@MainActor
@Observable
final class BaseMapViewModel {

    // MARK: - Property

    private let locationManager: LocationManager = .shared
    private let errorHandler: ErrorHandler

    let sessionInfo: SessionInfo

    /// 출석 판정과 공유하는 지오펜스 식별자 (서버 `scheduleId`)
    let geofenceId: String

    var cameraPosition: MapCameraPosition
    private(set) var geofenceCenter: CLLocationCoordinate2D?
    private(set) var sessionAddress: String?

    /// 지도 카메라 스팬
    private enum CameraSpan {
        static let initialDelta: CLLocationDegrees = 0.002
    }

    // MARK: - Computed Property

    var isAuthorized: Bool {
        locationManager.isAuthorized
    }

    /// 이 세션의 지오펜스 안에 있는지
    ///
    /// 여러 활동이 동시에 지오펜스를 등록할 수 있으므로 "아무 지오펜스 안"(`isInsideGeofence`)이
    /// 아니라 식별자 기반으로 판정합니다. 출석 판정과 같은 기준이라 화면 표시와 실제 출석 가능
    /// 여부가 어긋나지 않습니다.
    var isUserInsideGeofence: Bool {
        locationManager.isInside(geofenceId: geofenceId)
    }

    var currentLocation: CLLocationCoordinate2D? {
        locationManager.currentLocation
    }

    var sessionLocation: CLLocationCoordinate2D {
        sessionInfo.location.toCLLocationCoordinate2D
    }

    // MARK: - Init

    /// - Parameter scheduleId: 서버 일정 ID. 출석 판정이 조회하는 값과 같아야 하므로
    ///   호출부가 헷갈리지 않도록 지오펜스 식별자가 아니라 **원본 개념 이름**으로 받습니다.
    ///   (`session.info.sessionId.value` 를 넘기면 컴파일은 되지만 출석이 항상 거부됩니다.)
    init(
        info: SessionInfo,
        scheduleId geofenceId: String,
        errorHandler: ErrorHandler
    ) {
        self.sessionInfo = info
        self.geofenceId = geofenceId
        self.errorHandler = errorHandler
        self.cameraPosition = .region(MKCoordinateRegion(
            center: info.location.toCLLocationCoordinate2D,
            span: MKCoordinateSpan(
                latitudeDelta: CameraSpan.initialDelta,
                longitudeDelta: CameraSpan.initialDelta
            )
        ))
    }

    // MARK: - Function

    /// 출석용 지오펜스 모니터링 시작
    func startGeofenceForAttendance() async {
        geofenceCenter = sessionLocation

        await locationManager.startGeofenceMonitoring(
            at: sessionLocation,
            identifier: geofenceId,
            radius: AttendancePolicy.geofenceRadius
        )
    }

    /// 실시간 위치 업데이트 시작
    func startLocationUpdate() {
        locationManager.startLocationUpdating()
    }

    /// 실시간 위치 업데이트 중지
    func stopLocationUpdate() {
        locationManager.stopLocationUpdating()
    }

    /// 세션 위치의 주소를 역지오코딩으로 조회
    ///
    /// - Important: 취소 판정에 `catch is CancellationError` 를 쓰면 안 됩니다.
    ///   `LocationManager.reverseGeocode` 가 탈출하는 모든 에러를
    ///   `LocationError.geocodingFailed(_:)` 로 재포장하기 때문에 취소도 그 타입으로 도착하고,
    ///   타입 기반 분기는 물론 `Error.isCancellation`(CancellationError/URLError 검사) 도 빗나갑니다.
    ///   그대로 두면 화면을 빠르게 벗어났을 때 `.task` 취소가 전역 에러 Alert 로 새어 나옵니다.
    ///   타입에 의존하지 않는 `Task.isCancelled` 로 판정합니다.
    func updateAddressForSession() async {
        do {
            let address = try await locationManager.reverseGeocode(
                coordinate: sessionLocation
            )
            sessionAddress = address.fullAddress
        } catch {
            // 화면 이탈 등으로 취소된 조회는 실패가 아니므로 기존 주소를 유지합니다.
            guard !Task.isCancelled else { return }

            errorHandler.handle(
                error,
                context: .init(feature: "Activity", action: "updateAddressForSession")
            )
        }
    }

    /// Apple Maps 에서 세션 위치를 엽니다.
    func openSessionLocationInMaps() {
        let mapItem = MKMapItem(
            location: CLLocation(
                latitude: sessionLocation.latitude,
                longitude: sessionLocation.longitude
            ),
            address: nil
        )
        mapItem.name = sessionAddress
        mapItem.openInMaps()
    }
}
