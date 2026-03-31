//
//  SelectedPlaceAnnotation.swift
//  AppProduct
//
//  Created by euijjang97 on 3/13/26.
//

import SwiftUI

/// 지도 위 선택 핀에 부착되는 말풍선 형태의 주석 뷰입니다.
struct SelectedPlaceAnnotation: View {
    // MARK: - Property

    /// 현재 선택된 장소 정보입니다.
    let place: PlaceSearchInfo?

    /// 말풍선 등장 애니메이션에 사용할 스프링 값입니다.
    private let bubbleAnimation: Animation = .spring(
        response: 0.32,
        dampingFraction: 0.82
    )

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing8) {
            bubbleContent

            Image(.Map.mapPin)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
        }
        .animation(bubbleAnimation, value: bubbleIdentity)
    }

    // MARK: - Helper

    /// 선택 장소가 있을 때 주소 말풍선을 자연스럽게 표시합니다.
    @ViewBuilder
    private var bubbleContent: some View {
        if let place {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                Text(place.name)
                    .appFont(.caption1Emphasis, color: .black)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                Text(place.address)
                    .appFont(.caption2, color: .grey600)
                    .lineLimit(2)
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, DefaultSpacing.spacing12)
            .padding(.vertical, DefaultSpacing.spacing8)
            .background(
                Capsule(style: .continuous)
                    .fill(.white)
                    .glass()
            )
            .transition(
                .asymmetric(
                    insertion: .scale(scale: 0.88, anchor: .bottom)
                        .combined(with: .opacity),
                    removal: .scale(scale: 0.92, anchor: .bottom)
                        .combined(with: .opacity)
                )
            )
        }
    }

    /// 선택 장소 변경 시 말풍선 애니메이션을 다시 트리거하기 위한 식별 값입니다.
    private var bubbleIdentity: String {
        guard let place else { return "empty" }
        return "\(place.name)|\(place.address)"
    }
}
