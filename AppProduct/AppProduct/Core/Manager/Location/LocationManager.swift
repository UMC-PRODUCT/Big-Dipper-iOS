//
//  LocationManager.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/6/26.
//

import Foundation
import CoreLocation
import MapKit
import Observation

@Observable
final class LocationManager: NSObject {
    // MARK: - Property
    static let shared: LocationManager = .init()
    
    private(set) var currentLocation: CLLocationCoordinate2D?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var isAuthorized: Bool = false
    private(set) var locationError: Error?

    private(set) var activeGeofenceId: String?
    private(set) var isInsideGeofence: Bool = false
    private(set) var geofenceEvent: GeofenceEvent?

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
    private var monitor: CLMonitor?
    private var monitorTask: Task<Void, Never>?

    static let geofenceRadius: CLLocationDistance = AttendanceGeofenceConstants.geofenceRadius
    private let monitorName = "AttendanceGeofenceMonitor"
    
    // Computed Property
    
    var currentCoordinate: Coordinate? {
        guard let currentLocation = currentLocation else {
            return nil
        }
        
        return .init(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
    }

    // MARK: - Lifecycle

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        updateAuthorizationStatus(manager.authorizationStatus)
    }
    
    deinit {
        monitorTask?.cancel()
    }

    // MARK: - Location

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdating() {
        guard isAuthorized else {
            requestAuthorization()
            return
        }
        
        manager.startUpdatingLocation()
    }
    
    func stopLocationUpdating() {
        manager.stopUpdatingLocation()
    }
    
    func getCurrentLocation() async throws -> CLLocationCoordinate2D {
        guard isAuthorized else {
            requestAuthorization()
            throw LocationError.notAuthorized
        }
        
        if let location = currentLocation {
            return location
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
    /// - Throws: LocationError.geocodingFailed
    func reverseGeocode(coordinate: Coordinate) async throws -> String {
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

    func startGeofenceMonitoring(
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
    
    func stopGeofenceMonitoring(identifier: String) async {
        await monitor?.remove(identifier)
        
        if activeGeofenceId == identifier {
            activeGeofenceId = nil
            isInsideGeofence = false
        }
    }
    
    func stopAllGeofenceMonitoring() async {
        monitorTask?.cancel()
        monitorTask = nil
        
        if let monitor = monitor {
            for identifier in await monitor.identifiers {
                await monitor.remove(identifier)
            }
        }
        
        activeGeofenceId = nil
        isInsideGeofence = false
        geofenceEvent = nil
    }

    // MARK: - Private

    private func distance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }

    private func checkCurrentLocationInGeofence(
        center: CLLocationCoordinate2D,
        radius: CLLocationDistance = geofenceRadius
    ) {
        guard let location = currentLocation else { return }
        isInsideGeofence = distance(from: location, to: center) <= radius
    }
    
    private func updateAuthorizationStatus(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        isAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
    }
    
    private func startMonitoringEvents() {
        monitorTask?.cancel()
        
        monitorTask = Task { [weak self] in
            guard let self = self, let monitor = self.monitor else { return }
            
            do {
                for try await event in await monitor.events {
                    await MainActor.run {
                        self.handleMonitorEvent(event)
                    }
                }
            } catch {
                print("모니터링 에러: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
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
        guard let current = currentLocation,
              let _ = activeGeofenceId else { return }

        Task {
            guard let monitor = monitor else { return }

            for identifier in await monitor.identifiers {
                guard let record = await monitor.record(for: identifier) else { continue }

                if let condition = record.condition as? CLMonitor.CircularGeographicCondition {
                    let dist = distance(from: current, to: condition.center)

                    await MainActor.run {
                        self.isInsideGeofence = dist <= condition.radius
                    }
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location.coordinate
        
        if let continuation = locationContinuation {
            locationContinuation = nil
            continuation.resume(returning: location.coordinate)
        }
        
        updateGeofenceStatus()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        locationError = error
        
        if let continuation = locationContinuation {
            locationContinuation = nil
            continuation.resume(throwing: LocationError.locationFailed(error.localizedDescription))
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateAuthorizationStatus(manager.authorizationStatus)
        
        if isAuthorized {
            manager.startUpdatingLocation()
        }
    }
}

