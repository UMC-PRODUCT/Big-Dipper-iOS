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
}

// MARK: - MapPickerLocationProvider

/// `MapPlacePickerView` 전용 현재 위치 조회 헬퍼
///
/// Feature 모듈의 `LocationManager`/`LocationProviding`은 Core 모듈에서 참조할 수 없어
/// 권한 요청 + 단발성 현재 좌표 조회만 담당하는 최소 범위로 별도 구성했다.
final class MapPickerLocationProvider: NSObject {

    // MARK: - Property

    static let shared = MapPickerLocationProvider()

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    private var isAuthorized: Bool {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

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

    func currentLocation() async throws -> CLLocationCoordinate2D {
        guard isAuthorized else {
            requestAuthorization()
            throw MapPickerLocationError.notAuthorized
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }
}

// MARK: - MapPickerLocationProvider + CLLocationManagerDelegate

extension MapPickerLocationProvider: CLLocationManagerDelegate {

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        continuation?.resume(returning: location.coordinate)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
