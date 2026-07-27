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
/// `CLLocationCoordinate2D`/`String` 같은 CoreLocation 원시 타입만 노출합니다.
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

    /// 좌표를 주소 문자열로 변환
    /// - Parameter coordinate: 변환할 좌표
    /// - Returns: 주소 문자열 (예: "서울특별시 강남구 테헤란로 123")
    /// - Throws: `LocationError.geocodingFailed`
    public func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> String {
        let location = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        guard let request = MKReverseGeocodingRequest(location: location) else {
            throw LocationError.geocodingFailed("요청을 생성할 수 없습니다.")
        }

        do {
            let mapItems = try await request.mapItems
            guard let address = mapItems.first?.address?.shortAddress else {
                throw LocationError.geocodingFailed("주소 정보가 없습니다.")
            }

            return address
        } catch let error as LocationError {
            throw error
        } catch {
            throw LocationError.geocodingFailed(error.localizedDescription)
        }
    }

    // MARK: - Geofence

    #if !os(watchOS)
    public func startGeofenceMonitoring(
        at coordinate: CLLocationCoordinate2D,
        identifier: String,
        radius: CLLocationDistance
    ) async {
        if activeGeofenceId == identifier {
            checkCurrentLocationInGeofence(center: coordinate, radius: radius)
        }

        if let currentId = activeGeofenceId {
            await monitor?.remove(currentId)
        }

        if monitor == nil {
            monitor = await CLMonitor(monitorName)
            startMonitoringEvents()
        }

        let condition = CLMonitor.CircularGeographicCondition(center: coordinate, radius: radius)
        await monitor?.add(condition, identifier: identifier, assuming: .unsatisfied)
        activeGeofenceId = identifier

        checkCurrentLocationInGeofence(center: coordinate, radius: radius)
    }

    public func stopGeofenceMonitoring(identifier: String) async {
        await monitor?.remove(identifier)

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

        activeGeofenceId = nil
        isInsideGeofence = false
        geofenceEvent = nil
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

    private func updateGeofenceStatus() {
        guard let currentLocation, activeGeofenceId != nil else { return }

        Task {
            guard let monitor else { return }

            for identifier in await monitor.identifiers {
                guard let record = await monitor.record(for: identifier) else { continue }

                if let condition = record.condition as? CLMonitor.CircularGeographicCondition {
                    isInsideGeofence = GeofenceCalculator.isInside(
                        current: currentLocation,
                        center: condition.center,
                        radius: condition.radius
                    )
                }
            }
        }
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
