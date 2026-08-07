//
//  LocationManager.swift
//  UMCFoundation
//
//  Created by jaewon Lee on 1/6/26.
//

import CoreLocation
import Foundation
import MapKit
import Observation

/// 위치 갱신·역지오코딩·지오펜스 모니터링을 담당하는 Core 매니저
///
/// `CLLocationManager`/`CLMonitor` 래퍼로, GPS 기반 스마트 출석 등 위치가 필요한 기능이
/// 공유하는 단일 canonical 구현체입니다. 아직 `LocationProviding`(ActivityDomain)에는
/// conform 하지 않으며, 이는 후속 어댑터(#992 Phase B)에서 처리합니다.
///
/// Core 모듈은 Feature 모듈(Coordinate/Address 등)에 의존할 수 없으므로, 이 타입은
/// `CLLocationCoordinate2D`/`GeocodedAddress` 같은 Feature-독립 타입만 노출합니다.
/// 어댑터가 이를 도메인 타입으로 변환합니다.
///
/// - Important: `CLMonitor`는 watchOS에서 지원되지 않습니다(`API_UNAVAILABLE(watchos)`).
///   `UMCFoundation`은 iOS/watchOS 멀티플랫폼 모듈이므로 지오펜스 모니터링 관련 API는
///   `#if !os(watchOS)`로 감쌌습니다. 위치 조회/권한/역지오코딩은 두 플랫폼 모두 사용 가능합니다.
@MainActor
@Observable
public final class LocationManager: NSObject {

    // MARK: - Property

    public static let shared: LocationManager = .init()

    public private(set) var currentLocation: CLLocationCoordinate2D?
    public private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    public private(set) var isAuthorized: Bool = false
    public private(set) var locationError: Error?

    public private(set) var activeGeofenceId: String?
    public private(set) var isInsideGeofence: Bool = false
    public private(set) var geofenceEvent: GeofenceEvent?

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    #if !os(watchOS)
    private var monitor: CLMonitor?
    private var monitorTask: Task<Void, Never>?
    private let monitorName = "LocationGeofenceMonitor"
    /// 식별자별로 모니터링 중인 지오펜스의 중심/반경 캐시.
    /// `CLMonitor`는 식별자 단위 조회 API가 async라 `isInside(geofenceId:)`를 동기로
    /// 노출하기 위해 등록 시점 값을 별도로 들고 있다.
    private var monitoredGeofences: [String: MonitoredGeofence] = [:]
    #endif

    // MARK: - Lifecycle

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        updateAuthorizationStatus(manager.authorizationStatus)
    }

    // `shared` 싱글톤은 앱 생명주기 동안 해제되지 않으므로 `deinit` 정리 로직은 두지 않습니다.

    // MARK: - Location

    public func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    public func startLocationUpdating() {
        guard isAuthorized else {
            requestAuthorization()
            return
        }

        manager.startUpdatingLocation()
    }

    public func stopLocationUpdating() {
        manager.stopUpdatingLocation()
    }

    public func getCurrentLocation() async throws -> CLLocationCoordinate2D {
        guard isAuthorized else {
            requestAuthorization()
            throw LocationError.notAuthorized
        }

        if let currentLocation {
            return currentLocation
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    // MARK: - Reverse Geocoding

    /// 좌표를 구조화된 주소로 변환
    /// - Parameter coordinate: 변환할 좌표
    /// - Returns: `GeocodedAddress`(전체/짧은 주소 + 시/구 후보 필드, 정보 손실 없이 보존)
    /// - Throws: `LocationError.geocodingFailed`
    public func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> GeocodedAddress {
        let location = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        guard let request = MKReverseGeocodingRequest(location: location) else {
            throw LocationError.geocodingFailed("요청을 생성할 수 없습니다.")
        }

        do {
            let mapItems = try await request.mapItems
            guard let mapItem = mapItems.first, let address = mapItem.address else {
                throw LocationError.geocodingFailed("주소 정보가 없습니다.")
            }

            return GeocodedAddress(
                fullAddress: address.fullAddress,
                shortAddress: address.shortAddress,
                city: mapItem.addressRepresentations?.regionName,
                district: mapItem.addressRepresentations?.cityName
            )
        } catch let error as LocationError {
            throw error
        } catch {
            throw LocationError.geocodingFailed(error.localizedDescription)
        }
    }

    // MARK: - Geofence

    #if !os(watchOS)
    /// 여러 지오펜스를 동시에 등록할 수 있다(활동별 스케줄 ID 등). 기존에 등록된 다른
    /// 식별자는 유지되며, 같은 식별자로 다시 호출하면 조건(중심/반경)만 갱신된다.
    public func startGeofenceMonitoring(
        at coordinate: CLLocationCoordinate2D,
        identifier: String,
        radius: CLLocationDistance
    ) async {
        monitoredGeofences[identifier] = MonitoredGeofence(center: coordinate, radius: radius)

        if monitor == nil {
            monitor = await CLMonitor(monitorName)
        }
        if monitorTask == nil {
            startMonitoringEvents()
        }

        let condition = CLMonitor.CircularGeographicCondition(center: coordinate, radius: radius)
        await monitor?.add(condition, identifier: identifier, assuming: .unsatisfied)
        activeGeofenceId = identifier

        checkCurrentLocationInGeofence(center: coordinate, radius: radius)
    }

    public func stopGeofenceMonitoring(identifier: String) async {
        await monitor?.remove(identifier)
        monitoredGeofences.removeValue(forKey: identifier)

        if activeGeofenceId == identifier {
            activeGeofenceId = nil
            isInsideGeofence = false
        }
    }

    public func stopAllGeofenceMonitoring() async {
        monitorTask?.cancel()
        monitorTask = nil

        if let monitor {
            for identifier in await monitor.identifiers {
                await monitor.remove(identifier)
            }
        }

        monitoredGeofences.removeAll()
        activeGeofenceId = nil
        isInsideGeofence = false
        geofenceEvent = nil
    }

    /// 특정 지오펜스 식별자 안에 현재 위치가 있는지 판정
    ///
    /// 여러 지오펜스가 동시에 모니터링 중이어도 요청한 식별자만 정확히 조회한다.
    /// 등록되지 않은 식별자거나 현재 위치를 모르면 `false`.
    public func isInside(geofenceId: String) -> Bool {
        GeofenceCalculator.isInside(
            geofenceId: geofenceId,
            current: currentLocation,
            geofences: monitoredGeofences
        )
    }
    #endif

    // MARK: - Private

    private func checkCurrentLocationInGeofence(
        center: CLLocationCoordinate2D,
        radius: CLLocationDistance
    ) {
        guard let currentLocation else { return }
        isInsideGeofence = GeofenceCalculator.isInside(
            current: currentLocation,
            center: center,
            radius: radius
        )
    }

    private func updateAuthorizationStatus(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        isAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
    }

    #if !os(watchOS)
    private func startMonitoringEvents() {
        monitorTask?.cancel()

        monitorTask = Task { [weak self] in
            guard let self, let monitor = self.monitor else { return }

            do {
                for try await event in await monitor.events {
                    self.handleMonitorEvent(event)
                }
            } catch {
                print("모니터링 에러: \(error.localizedDescription)")
            }
        }
    }

    private func handleMonitorEvent(_ event: CLMonitor.Event) {
        switch event.state {
        case .satisfied:
            isInsideGeofence = true
            geofenceEvent = .entered(event.identifier)

        case .unsatisfied:
            isInsideGeofence = false
            geofenceEvent = .exited(event.identifier)

        case .unknown:
            break

        case .unmonitored:
            if activeGeofenceId == event.identifier {
                isInsideGeofence = false
                activeGeofenceId = nil
                geofenceEvent = nil
            }

        @unknown default:
            break
        }
    }

    /// 현재 `activeGeofenceId` 하나만 갱신한다. 다른 모니터링 대상 지오펜스는
    /// `isInside(geofenceId:)`로 별도 조회하므로 이 상태와 무관하다.
    private func updateGeofenceStatus() {
        guard let currentLocation, let activeGeofenceId,
              let geofence = monitoredGeofences[activeGeofenceId] else { return }

        isInsideGeofence = GeofenceCalculator.isInside(
            current: currentLocation,
            center: geofence.center,
            radius: geofence.radius
        )
    }
    #endif

    // MARK: - Delegate Handling

    private func handleLocationUpdate(_ coordinate: CLLocationCoordinate2D) {
        currentLocation = coordinate

        if let continuation = locationContinuation {
            locationContinuation = nil
            continuation.resume(returning: coordinate)
        }

        #if !os(watchOS)
        updateGeofenceStatus()
        #endif
    }

    private func handleLocationFailure(_ error: Error) {
        locationError = error

        if let continuation = locationContinuation {
            locationContinuation = nil
            continuation.resume(throwing: LocationError.locationFailed(error.localizedDescription))
        }
    }

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        updateAuthorizationStatus(status)

        if isAuthorized {
            manager.startUpdatingLocation()
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    /// - Note: `CLLocationManagerDelegate` 요구사항은 `nonisolated`이므로, 상태 변경은
    ///   `Task { @MainActor in }`로 액터를 넘겨 처리합니다.
    nonisolated public func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.handleLocationUpdate(coordinate)
        }
    }

    nonisolated public func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: any Error
    ) {
        Task { @MainActor in
            self.handleLocationFailure(error)
        }
    }

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.handleAuthorizationChange(status)
        }
    }
}
