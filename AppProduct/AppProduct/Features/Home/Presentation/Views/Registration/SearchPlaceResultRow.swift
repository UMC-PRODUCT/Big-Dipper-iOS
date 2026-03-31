//
//  SearchPlaceResultRow.swift
//  AppProduct
//
//  Created by euijjang97 on 3/13/26.
//

import MapKit
import SwiftUI

/// 장소 검색 결과 한 줄을 렌더링하는 재사용 셀입니다.
///
/// 검색 결과 탭 시 외부에서 주입한 액션을 실행하며,
/// 지도 카테고리에 맞는 아이콘과 기본 주소 정보를 함께 표시합니다.
struct SearchContent: View, Equatable {
    // MARK: - Property

    /// 렌더링할 장소 검색 결과입니다.
    let place: PlaceSearchResult
    /// 셀 탭 시 실행할 액션입니다.
    let tapAction: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.place == rhs.place
    }

    // MARK: - Body

    var body: some View {
        Button(action: {
            tapAction()
        }, label: {
            HStack(spacing: DefaultSpacing.spacing8, content: {
                MapMarkerIcon(category: place.category)
                    .equatable()

                VStack(alignment: .leading, spacing: DefaultSpacing.spacing4, content: {
                    Text(place.name)
                        .appFont(.calloutEmphasis, color: .black)
                    Text(place.address ?? "주소 정보 없음")
                        .appFont(.subheadline, color: .grey600)
                })
            })
        })
    }
}

/// 장소 카테고리를 원형 아이콘으로 표현하는 보조 뷰입니다.
struct MapMarkerIcon: View, Equatable {
    // MARK: - Property

    /// MapKit이 제공하는 POI 카테고리입니다.
    let category: MKPointOfInterestCategory?

    // MARK: - Constant

    enum Constants {
        static let circleSize: CGFloat = 40
        static let circleIcon: String = "mappin"
    }

    // MARK: - Body

    var body: some View {
        Circle()
            .fill(category?.backgroundColor ?? .gray)
            .frame(width: Constants.circleSize, height: Constants.circleSize)
            .overlay {
                Image(systemName: category?.systemIconName ?? Constants.circleIcon)
                    .renderingMode(.template)
                    .font(.default)
                    .foregroundStyle(.white)
            }
            .glassEffect(.clear, in: .circle)
    }
}
