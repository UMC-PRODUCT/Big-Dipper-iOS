//
//  MapPlacePickerView.swift
//  AppProduct
//
//  Created by euijjang97 on 3/11/26.
//

import CoreLocation
import MapKit
import SwiftUI
import TipKit

/// Apple 지도에서 핀을 찍어 장소를 선택하는 뷰
///
/// 선택한 좌표를 역지오코딩해 `PlaceSearchInfo`로 변환하고,
/// 확정 시 상위 화면에 선택 결과를 전달합니다.
struct MapPlacePickerView: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss

    /// 편집 모드에서 전달되는 기존 장소 정보입니다.
    private let initialPlace: PlaceSearchInfo
    /// 장소 선택 완료 시 상위 화면에 결과를 전달하는 콜백입니다.
    private let placeSelected: (PlaceSearchInfo) -> Void

    /// 현재 지도 카메라 위치입니다.
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: Constants.defaultCenter,
            span: Constants.defaultSpan
        )
    )
    /// 지도에 표시 중인 선택 좌표입니다.
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    /// 선택 좌표를 장소 정보로 변환한 결과입니다.
    @State private var selectedPlace: PlaceSearchInfo?
    /// 역지오코딩 진행 상태입니다.
    @State private var isResolvingPlace: Bool = false
    /// 초기 카메라/선택 상태를 한 번만 구성하기 위한 플래그입니다.
    @State private var hasInitializedState: Bool = false
    /// 애플 맵 기본 POI 말풍선 표시를 위한 선택된 지도 피처입니다.
    @State private var selectedMapFeature: MapFeature?

    /// POI 길게 누르기 안내 팁입니다.
    private let poiTip = POILongPressTip()

    /// 레이아웃과 지도 기본값을 모아둔 상수입니다.
    private enum Constants {
        static let defaultCenter = CLLocationCoordinate2D(
            latitude: 37.5665,
            longitude: 126.9780
        )
        static let defaultSpan = MKCoordinateSpan(
            latitudeDelta: 0.02,
            longitudeDelta: 0.02
        )
        static let pinSize: CGFloat = 28
        static let bottomPadding: CGFloat = 16
    }

    // MARK: - Initializer

    /// 지도 선택 화면을 초기화합니다.
    ///
    /// - Parameters:
    ///   - initialPlace: 기존 선택값이 있는 경우 초기 핀 위치로 사용할 장소 정보입니다.
    ///   - placeSelected: 사용자가 위치 선택을 확정했을 때 호출되는 클로저입니다.
    init(
        initialPlace: PlaceSearchInfo,
        placeSelected: @escaping (PlaceSearchInfo) -> Void
    ) {
        self.initialPlace = initialPlace
        self.placeSelected = placeSelected
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                mapContent
                selectionCard
            }
            .navigationTitle("지도에서 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    currentLocationButton
                }
            }
            .task {
                await configureInitialStateIfNeeded()
            }
        }
    }

    // MARK: - Private View

    /// 핀 선택과 사용자 위치를 표시하는 지도 본문입니다.
    private var mapContent: some View {
        MapReader { proxy in
            Map(position: $cameraPosition, selection: $selectedMapFeature) {
                // POI가 선택된 경우 커스텀 핀을 숨기고 애플 맵 기본 말풍선을 표시합니다.
                if let selectedCoordinate, selectedMapFeature == nil {
                    Annotation(
                        "선택한 위치",
                        coordinate: selectedCoordinate,
                        anchor: .bottom
                    ) {
                        SelectionPinView(pinSize: Constants.pinSize)
                    }
                }
                UserAnnotation()
            }
            .mapStyle(.standard)
            .mapControls {
                MapCompass()
            }
            .overlay(alignment: .top) {
                TipView(poiTip, arrowEdge: .none)
                    .glassEffect()
                    .padding(.horizontal, DefaultSpacing.spacing16)
            }
            .onChange(of: selectedMapFeature) { _, feature in
                guard let feature else { return }
                // POI 탭: 애플 맵 기본 말풍선 유지, 하단 카드 정보만 갱신
                poiTip.invalidate(reason: .actionPerformed)
                Task {
                    await selectPOICoordinate(feature.coordinate, poiName: feature.title)
                }
            }
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        let location = value.location
                        Task { @MainActor in
                            // Map의 selectedMapFeature 상태 업데이트를 기다린 후 POI 여부를 판단합니다.
                            await Task.yield()
                            guard selectedMapFeature == nil else { return }
                            guard let coordinate = proxy.convert(location, from: .local) else { return }
                            Task { await selectCoordinate(coordinate) }
                        }
                    }
            )
        }
    }

    /// 선택한 장소 정보와 확정 액션을 제공하는 하단 카드입니다.
    private var selectionCard: some View {
        SelectionCardView(
            selectedPlace: selectedPlace,
            isResolvingPlace: isResolvingPlace,
            confirmSelection: confirmSelection
        )
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .padding(.bottom, Constants.bottomPadding)
    }

    /// 현재 위치로 카메라를 이동하고 핀을 갱신하는 툴바 버튼입니다.
    private var currentLocationButton: some View {
        Button(action: {
            Task {
                await moveToCurrentLocation()
            }
        }) {
            CurrentLocationIcon()
        }
        .accessibilityLabel("현재 위치로 이동")
    }

    // MARK: - Private Function

    /// 지도 탭 위치를 좌표로 변환한 뒤 선택 상태를 갱신합니다.
    ///
    /// - Parameters:
    ///   - value: 사용자의 탭 위치 정보입니다.
    ///   - proxy: 화면 좌표를 지도 좌표로 변환하는 `MapProxy`입니다.
    private func handleMapTap(_ value: SpatialTapGesture.Value, proxy: MapProxy) {
        guard let coordinate = proxy.convert(
            value.location,
            from: .local
        ) else {
            return
        }

        Task {
            await selectCoordinate(coordinate)
        }
    }

    /// 초기 진입 시 기존 선택값 또는 현재 위치를 기준으로 지도를 설정합니다.
    ///
    /// 기존 장소가 있으면 해당 좌표에 핀과 카메라를 맞추고,
    /// 없으면 현재 위치 권한을 요청한 뒤 가능한 경우 현재 위치로 카메라를 이동합니다.
    @MainActor
    private func configureInitialStateIfNeeded() async {
        guard !hasInitializedState else { return }
        hasInitializedState = true

        if initialPlace.coordinate.latitude != 0
            || initialPlace.coordinate.longitude != 0 {
            let coordinate = CLLocationCoordinate2D(
                latitude: initialPlace.coordinate.latitude,
                longitude: initialPlace.coordinate.longitude
            )
            selectedCoordinate = coordinate
            selectedPlace = initialPlace
            moveCamera(to: coordinate)
            return
        }

        LocationManager.shared.requestAuthorization()
        if let currentLocation = try? await LocationManager.shared
            .getCurrentLocation() {
            moveCamera(to: currentLocation)
        }
    }

    /// 현재 위치를 조회한 뒤 해당 좌표를 선택 상태로 반영합니다.
    @MainActor
    private func moveToCurrentLocation() async {
        do {
            let coordinate = try await LocationManager.shared.getCurrentLocation()
            await selectCoordinate(coordinate)
        } catch {
            LocationManager.shared.requestAuthorization()
        }
    }

    /// 사용자가 선택한 좌표를 핀과 장소 정보 상태에 반영합니다.
    ///
    /// - Parameter coordinate: 지도에서 선택한 좌표입니다.
    @MainActor
    private func selectCoordinate(_ coordinate: CLLocationCoordinate2D) async {
        selectedCoordinate = coordinate
        moveCamera(to: coordinate)
        isResolvingPlace = true
        selectedPlace = await reverseGeocodePlaceInfo(for: coordinate)
        isResolvingPlace = false
    }

    /// POI 탭 시 커스텀 핀 없이 장소 정보만 역지오코딩합니다.
    ///
    /// 애플 맵 기본 POI 말풍선을 유지하기 위해 `selectedCoordinate`를 nil로 초기화하며,
    /// 역지오코딩 결과로 하단 카드의 장소 정보를 갱신합니다.
    /// POI 이름이 제공된 경우 역지오코딩 결과의 이름 대신 POI 이름을 우선 사용합니다.
    ///
    /// - Parameters:
    ///   - coordinate: POI의 좌표입니다.
    ///   - poiName: 애플 맵에서 제공하는 POI 이름입니다.
    @MainActor
    private func selectPOICoordinate(
        _ coordinate: CLLocationCoordinate2D,
        poiName: String? = nil
    ) async {
        selectedCoordinate = nil
        isResolvingPlace = true
        var place = await reverseGeocodePlaceInfo(for: coordinate)
        if let poiName {
            place = PlaceSearchInfo(
                name: poiName,
                address: place.address,
                coordinate: place.coordinate
            )
        }
        selectedPlace = place
        isResolvingPlace = false
    }

    /// 지정한 좌표가 화면 중심에 오도록 카메라를 갱신합니다.
    ///
    /// - Parameter coordinate: 카메라 중심으로 이동할 좌표입니다.
    @MainActor
    private func moveCamera(to coordinate: CLLocationCoordinate2D) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: Constants.defaultSpan
            )
        )
    }

    /// 현재 선택된 장소를 상위 화면에 전달하고 시트를 닫습니다.
    private func confirmSelection() {
        guard let selectedPlace else { return }
        placeSelected(selectedPlace)
        dismiss()
    }

    /// 좌표를 `PlaceSearchInfo`로 역지오코딩합니다.
    ///
    /// Apple Maps의 역지오코딩 결과를 우선 사용하고,
    /// 실패하면 좌표 문자열 기반의 폴백 장소 정보를 반환합니다.
    ///
    /// - Parameter coordinate: 역지오코딩할 좌표입니다.
    /// - Returns: 화면에서 바로 사용할 수 있는 `PlaceSearchInfo`입니다.
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

    /// 역지오코딩에 실패했을 때 사용할 기본 장소 정보를 생성합니다.
    ///
    /// - Parameter coordinate: 표시용 좌표입니다.
    /// - Returns: 좌표 문자열을 포함한 기본 `PlaceSearchInfo`입니다.
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

    /// 좌표를 짧은 주소 문자열 형태로 변환합니다.
    ///
    /// - Parameter coordinate: 문자열로 표시할 좌표입니다.
    /// - Returns: 위도/경도를 소수점 다섯 자리까지 표현한 문자열입니다.
    private func fallbackAddress(for coordinate: CLLocationCoordinate2D) -> String {
        String(
            format: "%.5f, %.5f",
            coordinate.latitude,
            coordinate.longitude
        )
    }
}

// MARK: - Private Subviews

/// 선택한 좌표를 나타내는 기본 핀 아이콘입니다.
private struct SelectionPinView: View {
    let pinSize: CGFloat

    var body: some View {
        Image(.Map.mapPin)
            .resizable()
            .scaledToFit()
            .frame(width: pinSize, height: pinSize)
    }
}

/// 현재 위치 이동 버튼에 사용하는 아이콘 뷰입니다.
private struct CurrentLocationIcon: View {
    var body: some View {
        Image(systemName: "location.fill")
            .foregroundStyle(.indigo500)
    }
}

/// 선택 상태, 로딩 상태, 확정 버튼을 조합한 하단 카드입니다.
private struct SelectionCardView: View {

    let selectedPlace: PlaceSearchInfo?
    let isResolvingPlace: Bool
    let confirmSelection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            content
            confirmButton
        }
        .padding(DefaultSpacing.spacing16)
        .background(
            ConcentricRectangle(
                corners: .concentric(
                    minimum: DefaultConstant.concentricRadius
                ),
                isUniform: true
            )
            .fill(.white)
            .glass()
        )
    }

    @ViewBuilder
    private var content: some View {
        if let selectedPlace {
            selectedPlaceContent(selectedPlace)
        } else if isResolvingPlace {
            resolvingContent
        } else {
            Text("탭으로 주소를 선택하거나, POI를 길게 눌러 장소를 선택하세요.")
                .appFont(.subheadline, color: .grey600)
        }
    }

    private func selectedPlaceContent(_ selectedPlace: PlaceSearchInfo) -> some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            Text(selectedPlace.name)
                .appFont(.calloutEmphasis, color: .black)

            Text(selectedPlace.address)
                .appFont(.subheadline, color: .grey600)
                .multilineTextAlignment(.leading)
        }
    }

    private var resolvingContent: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            ProgressView()
                .controlSize(.small)
            Text("선택한 위치를 확인하는 중입니다.")
                .appFont(.subheadline, color: .grey600)
        }
    }

    private var confirmButton: some View {
        Button(action: confirmSelection) {
            Text("이 위치 사용")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .disabled(selectedPlace == nil || isResolvingPlace)
    }
}
