//
//  MapPlacePickerSubviews.swift
//  CoreUIComponents
//
//  Created by JEONG EUI CHAN on 7/27/26.
//

import CoreDesignSystem
import SwiftUI

// MARK: - SelectionPinView

/// 선택한 좌표를 나타내는 기본 핀 아이콘
struct SelectionPinView: View {

    let pinSize: CGFloat

    var body: some View {
        Image("MapPin", bundle: .module)
            .resizable()
            .scaledToFit()
            .frame(width: pinSize, height: pinSize)
    }
}

// MARK: - CurrentLocationIcon

/// 현재 위치 이동 버튼에 사용하는 아이콘 뷰
struct CurrentLocationIcon: View {

    var body: some View {
        Image(systemName: "location.fill")
            .foregroundStyle(Color.indigo500)
    }
}

// MARK: - SelectionCardView

/// 선택 상태, 로딩 상태, 확정 버튼을 조합한 하단 카드
struct SelectionCardView: View {

    let selectedPlace: PlaceSelection?
    let isResolvingPlace: Bool
    let confirmSelection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            content
            confirmButton
        }
        .padding(DefaultSpacing.spacing16)
        .glassEffect(
            .regular,
            in: ConcentricRectangle(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
        )
    }

    // MARK: - Private View

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

    private func selectedPlaceContent(_ selectedPlace: PlaceSelection) -> some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            Text(selectedPlace.name)
                .appFont(.callout, weight: .semibold, color: .grey900)

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
