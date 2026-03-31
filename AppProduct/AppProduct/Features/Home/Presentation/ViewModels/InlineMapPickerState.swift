//
//  InlineMapPickerState.swift
//  AppProduct
//
//  Created by euijjang97 on 3/13/26.
//

import CoreLocation
import MapKit
import SwiftUI

/// 지도 탭에서 임시 위치 선택 상태를 보관하는 객체입니다.
///
/// 핀 좌표, 역지오코딩 결과, 카메라 위치를 함께 관리하며
/// 시트가 닫히기 전까지 상위 폼과 분리된 상태를 유지합니다.
@Observable
final class InlineMapPickerState {
    // MARK: - Property

    private static let defaultCenter = CLLocationCoordinate2D(
        latitude: 37.5665,
        longitude: 126.9780
    )
    private static let defaultSpan = MKCoordinateSpan(
        latitudeDelta: 0.02,
        longitudeDelta: 0.02
    )

    /// 현재 지도 카메라 위치입니다.
    var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: defaultCenter,
            span: defaultSpan
        )
    )
    /// 사용자가 마지막으로 탭한 좌표입니다.
    var selectedCoordinate: CLLocationCoordinate2D?
    /// 선택 좌표를 역지오코딩한 결과입니다.
    var selectedPlace: PlaceSearchInfo?
    /// 역지오코딩 진행 여부입니다.
    var isResolvingPlace: Bool = false
    private var hasInitializedState: Bool = false

    // MARK: - Initializer

    /// 기존 선택 위치를 바탕으로 지도 선택 상태를 생성합니다.
    ///
    /// - Parameter initialPlace: 이미 확정된 장소가 있다면 카메라와 핀의 초기값으로 사용합니다.
    init(initialPlace: PlaceSearchInfo? = nil) {
        guard let initialPlace, Self.isValid(place: initialPlace) else {
            return
        }

        let coordinate = CLLocationCoordinate2D(
            latitude: initialPlace.coordinate.latitude,
            longitude: initialPlace.coordinate.longitude
        )

        selectedCoordinate = coordinate
        selectedPlace = initialPlace
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: Self.defaultSpan
            )
        )
        hasInitializedState = true
    }

    // MARK: - Function

    /// 최초 진입 시 현재 위치 권한을 요청하고 카메라 중심을 맞춥니다.
    @MainActor
    func configureInitialStateIfNeeded() async {
        guard !hasInitializedState else { return }
        hasInitializedState = true

        LocationManager.shared.requestAuthorization()
        if let currentLocation = try? await LocationManager.shared.getCurrentLocation() {
            moveCamera(to: currentLocation)
        }
    }

    /// 사용자의 현재 위치를 다시 조회해 지도와 선택 핀을 갱신합니다.
    @MainActor
    func moveToCurrentLocation() async {
        do {
            let coordinate = try await LocationManager.shared.getCurrentLocation()
            await selectCoordinate(coordinate)
        } catch {
            LocationManager.shared.requestAuthorization()
        }
    }

    /// 전달된 좌표를 임시 선택 좌표로 저장하고 역지오코딩을 수행합니다.
    ///
    /// - Parameter coordinate: 사용자가 지도에서 탭한 좌표입니다.
    @MainActor
    func selectCoordinate(_ coordinate: CLLocationCoordinate2D) async {
        selectedCoordinate = coordinate
        isResolvingPlace = true
        selectedPlace = await reverseGeocodePlaceInfo(for: coordinate)
        isResolvingPlace = false
    }

    // MARK: - Private Function

    @MainActor
    private func moveCamera(to coordinate: CLLocationCoordinate2D) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: Self.defaultSpan
            )
        )
    }

    /// 선택 좌표를 `PlaceSearchInfo`로 변환합니다.
    ///
    /// - Parameter coordinate: 주소 정보를 조회할 좌표입니다.
    /// - Returns: 역지오코딩 성공 시 실제 장소명과 주소를, 실패 시 좌표 기반 대체 정보를 반환합니다.
    private func reverseGeocodePlaceInfo(
        for coordinate: CLLocationCoordinate2D
    ) async -> PlaceSearchInfo {
        let location = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        guard let request = MKReverseGeocodingRequest(location: location) else {
            return fallbackPlaceInfo(for: coordinate)
        }

        do {
            let mapItems = try await request.mapItems
            guard let first = mapItems.first else {
                return fallbackPlaceInfo(for: coordinate)
            }

            let address =
                first.address?.shortAddress
                ?? first.address?.fullAddress
                ?? first.addressRepresentations?.fullAddress(
                    includingRegion: false,
                    singleLine: true
                )
                ?? fallbackAddress(for: coordinate)

            return PlaceSearchInfo(
                name: first.name ?? address,
                address: address,
                coordinate: Coordinate(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            )
        } catch {
            return fallbackPlaceInfo(for: coordinate)
        }
    }

    /// 역지오코딩 실패 시 좌표 문자열 기반의 임시 장소 정보를 생성합니다.
    private func fallbackPlaceInfo(
        for coordinate: CLLocationCoordinate2D
    ) -> PlaceSearchInfo {
        let address = fallbackAddress(for: coordinate)
        return PlaceSearchInfo(
            name: "지도에서 선택한 위치",
            address: address,
            coordinate: Coordinate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        )
    }

    /// 좌표를 사용자가 읽을 수 있는 기본 문자열로 포맷합니다.
    private func fallbackAddress(
        for coordinate: CLLocationCoordinate2D
    ) -> String {
        String(
            format: "%.5f, %.5f",
            coordinate.latitude,
            coordinate.longitude
        )
    }

    /// 전달된 장소가 지도 초기값으로 사용 가능한지 검증합니다.
    private static func isValid(place: PlaceSearchInfo) -> Bool {
        let name = place.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let latitude = place.coordinate.latitude
        let longitude = place.coordinate.longitude

        guard !name.isEmpty else { return false }
        guard latitude.isFinite, longitude.isFinite else { return false }
        guard (-90.0...90.0).contains(latitude) else { return false }
        guard (-180.0...180.0).contains(longitude) else { return false }
        return !(latitude == 0 && longitude == 0)
    }
}
