//
//  InlineMapPlacePicker.swift
//  AppProduct
//
//  Created by euijjang97 on 3/13/26.
//

import MapKit
import SwiftUI
import TipKit

/// 일정 등록 시트 안에서 사용하는 인라인 지도 선택 뷰입니다.
///
/// 지도 탭으로 임시 위치를 선택하고, 실제 확정 액션은
/// 상위 화면의 하단 toolbar 버튼에서 처리합니다.
struct InlineMapPlacePicker: View {
    // MARK: - Property

    /// 지도 선택 상태입니다.
    @Bindable var state: InlineMapPickerState

    /// 애플 맵 기본 POI 말풍선 표시를 위한 선택된 지도 피처입니다.
    @State private var selectedMapFeature: MapFeature?

    /// POI 길게 누르기 안내 팁입니다.
    private let poiTip = POILongPressTip()

    // MARK: - Initializer

    /// 인라인 지도 선택 뷰를 생성합니다.
    ///
    /// - Parameter state: 지도 카메라, 핀, 역지오코딩 상태를 관리하는 객체입니다.
    init(state: InlineMapPickerState) {
        self.state = state
    }

    // MARK: - Body

    var body: some View {
        MapReader { proxy in
            Map(position: $state.cameraPosition, selection: $selectedMapFeature) {
                // POI가 선택된 경우 커스텀 핀을 숨기고 애플 맵 기본 말풍선을 표시합니다.
                if let selectedCoordinate = state.selectedCoordinate,
                   selectedMapFeature == nil {
                    Annotation(
                        state.selectedPlace?.name ?? "선택한 위치",
                        coordinate: selectedCoordinate,
                        anchor: .bottom
                    ) {
                        SelectedPlaceAnnotation(place: state.selectedPlace)
                    }
                }
                UserAnnotation()
            }
            .mapStyle(.standard)
            .mapControls {
                MapCompass()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                TipView(poiTip, arrowEdge: .none)
                    .padding(.top, DefaultSpacing.spacing12)
                    .padding(.horizontal, DefaultSpacing.spacing16)
            }
            .onChange(of: selectedMapFeature) { _, feature in
                guard let feature else { return }
                poiTip.invalidate(reason: .actionPerformed)
                Task {
                    await state.selectPOICoordinate(feature.coordinate, poiName: feature.title)
                }
            }
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        let location = value.location
                        Task { @MainActor in
                            await Task.yield()
                            guard selectedMapFeature == nil else { return }
                            guard let coordinate = proxy.convert(location, from: .local) else { return }
                            await state.selectCoordinate(coordinate)
                        }
                    }
            )
        }
        .task {
            await state.configureInitialStateIfNeeded()
        }
    }
}

