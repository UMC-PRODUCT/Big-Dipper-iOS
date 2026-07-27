//
//  PlaceSelectView.swift
//  CoreUIComponents
//
//  Created by JEONG EUI CHAN on 7/27/26.
//

import CoreDesignSystem
import SwiftUI

// MARK: - PlaceSelectView

/// 장소 선택 뷰 (지도 기반 장소 선택 포함)
///
/// 선택된 장소가 없으면 플레이스홀더를, 있으면 장소 정보를 표시한다.
/// 탭하면 `MapPlacePickerView`가 시트로 표시되며, 확정한 장소를 `place` 바인딩에 반영한다.
public struct PlaceSelectView: View {

    // MARK: - Property

    @Binding private var place: PlaceSelection
    private let placeholder: String

    @State private var isMapPickerPresented: Bool = false

    // MARK: - Initializer

    public init(place: Binding<PlaceSelection>, placeholder: String = "어디에서 열리나요?") {
        self._place = place
        self.placeholder = placeholder
    }

    // MARK: - Body

    public var body: some View {
        Button {
            isMapPickerPresented = true
        } label: {
            HStack(spacing: DefaultSpacing.spacing8) {
                if place.name.isEmpty {
                    emptyPlace
                } else {
                    selectedPlace
                }
                Spacer()

                if !place.name.isEmpty {
                    clearButton
                }
            }
        }
        .sheet(isPresented: $isMapPickerPresented) {
            MapPlacePickerView(initialPlace: place) { selected in
                place = selected
            }
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Private View

    /// 장소가 선택되지 않았을 때의 플레이스홀더 뷰
    private var emptyPlace: some View {
        Text(placeholder)
            .font(.app(.callout))
            .foregroundStyle(.placeholder)
    }

    /// 선택된 장소의 이름과 주소를 표시하는 뷰
    private var selectedPlace: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
            Text(place.name)
                .appFont(.callout, weight: .semibold, color: .grey900)

            Text(place.address)
                .appFont(.subheadline, color: .grey600)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 선택된 장소 초기화 버튼
    private var clearButton: some View {
        Button {
            place = .empty
        } label: {
            Image(systemName: "xmark.circle.fill")
                .appFont(.title3, color: .grey400)
        }
        .buttonStyle(.plain)
    }
}
