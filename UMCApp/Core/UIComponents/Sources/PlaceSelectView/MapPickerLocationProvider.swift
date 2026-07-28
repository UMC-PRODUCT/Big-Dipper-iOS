//
//  MapPickerLocationProvider.swift
//  CoreUIComponents
//
//  Created by JEONG EUI CHAN on 7/27/26.
//

import CoreLocation

// MARK: - MapPickerLocationError

enum MapPickerLocationError: Error {
    case notAuthorized
    case locationUnavailable
}

// MARK: - MapPickerLocationProvider

/// `MapPlacePickerView` 전용 현재 위치 조회 헬퍼
///
/// Feature 모듈의 `LocationManager`/`LocationProviding`은 Core 모듈에서 참조할 수 없어
/// 권한 요청 + 단발성 현재 좌표 조회만 담당하는 최소 범위로 별도 구성했다.
///
/// - Note: `NSLocationWhenInUseUsageDescription` 권한 키는 별도 PR #1023(refactor/1017)에서
///   `UMCApp/Project.swift`에 추가된다. 이 provider가 실제로 시스템 권한 프롬프트를 띄우려면
///   `StudyScheduleRegistrationView` 결선(#1014) 이전에 PR #1023이 먼저 머지되어 있어야 한다.
// TODO(#1017): UMCFoundation.LocationManager 이관(PR #1023) 머지 후 이 타입 제거·통합 검토
@MainActor
final class MapPickerLocationProvider: NSObject {

    // MARK: - Property

    static let shared = MapPickerLocationProvider()

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    // MARK: - Initializer

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    // MARK: - Function

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// 현재 좌표를 단발성으로 조회한다.
    ///
    /// 권한이 아직 결정되지 않았으면 시스템 프롬프트를 띄우고 사용자의 응답을 기다린 뒤
    /// 승인 시 위치를 이어서 요청한다. 거부/제한 상태이면 즉시 실패한다.
    func currentLocation() async throws -> CLLocationCoordinate2D {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return try await awaitLocationUpdate { [manager] in manager.requestLocation() }
        case .notDetermined:
            return try await awaitLocationUpdate { [manager] in
                manager.requestWhenInUseAuthorization()
            }
        default:
            throw MapPickerLocationError.notAuthorized
        }
    }

    // MARK: - Private Function

    /// 대기 중이던 이전 요청은 취소로 마무리하고, 새 요청을 시작해 continuation을 대기한다.
    ///
    /// 대기 중 두 번째 호출(예: 초기 진입 대기 중 사용자가 "현재 위치" 버튼을 다시 누르는 경우)이
    /// 들어와도 첫 continuation이 resume 없이 폐기되지 않도록 보장한다.
    private func awaitLocationUpdate(
        _ triggerRequest: @escaping () -> Void
    ) async throws -> CLLocationCoordinate2D {
        resumePendingContinuation(throwing: CancellationError())
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            triggerRequest()
        }
    }

    private func resumePendingContinuation(throwing error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    private func resumePendingContinuation(returning coordinate: CLLocationCoordinate2D) {
        continuation?.resume(returning: coordinate)
        continuation = nil
    }
}

// MARK: - MapPickerLocationProvider + CLLocationManagerDelegate

extension MapPickerLocationProvider: CLLocationManagerDelegate {

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        let coordinate = locations.last?.coordinate
        Task { @MainActor in
            if let coordinate {
                self.resumePendingContinuation(returning: coordinate)
            } else {
                self.resumePendingContinuation(
                    throwing: MapPickerLocationError.locationUnavailable
                )
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.resumePendingContinuation(throwing: error)
        }
    }

    /// 권한 상태가 변경되면(주로 사용자가 시스템 프롬프트에 응답한 직후) 대기 중인 요청이
    /// 있을 때만 이어서 처리한다 — 대기 중인 요청이 없으면(예: 델리게이트 최초 등록 시
    /// 호출되는 초기 통지) 아무 것도 하지 않는다.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard self.continuation != nil else { return }
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .notDetermined:
                break
            default:
                self.resumePendingContinuation(throwing: MapPickerLocationError.notAuthorized)
            }
        }
    }
}
