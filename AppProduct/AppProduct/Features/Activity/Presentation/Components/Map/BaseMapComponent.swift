//
//  BaseMapComponent.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/12/26.
//

import SwiftUI
import MapKit

/// 세션 위치와 지오펜스를 표시하는 기본 지도 컴포넌트
///
/// - 세션 마커: 스터디/세미나 장소 표시
/// - 지오펜스 오버레이: 출석 가능 영역 시각화
/// - 사용자 위치: UserAnnotation으로 현재 위치 표시
struct BaseMapComponent: View, Equatable {

    // MARK: - Property

    @Bindable private var viewModel: BaseMapViewModel

    // MARK: - Init

    init(viewModel: BaseMapViewModel) {
        self.viewModel = viewModel
    }

    fileprivate enum Constants {
        static let iconSize: CGFloat = 24
    }

    static func == (lsh: Self, rhs: Self) -> Bool {
        return lsh.viewModel === rhs.viewModel
    }

    // MARK: - Body

    var body: some View {
        Map(position: $viewModel.cameraPosition) {
            geofenceOverlay
            sessionMaker
            UserAnnotation()
        }
        .mapStyle(.standard)
        .mapControls {
            MapCompass()
        }
    }

    // MARK: - View Component

    /// 세션 위치를 나타내는 핀 마커
    @MapContentBuilder
    private var sessionMaker: some MapContent {
        Annotation(
            viewModel.sessionInfo.title,
            coordinate: viewModel.sessionLocation,
            anchor: .bottom
        ) {
            Image(.Map.mapPin)
                .resizable()
                .scaledToFit()
                .frame(width: Constants.iconSize, height: Constants.iconSize)
        }
    }

    /// 지오펜스 영역 오버레이 (출석 가능 범위)
    @MapContentBuilder
    private var geofenceOverlay: some MapContent {
        if let geofenceCenter = viewModel.geofenceCenter {
            MapCircle(
                center: geofenceCenter,
                radius: AttendancePolicy.geofenceRadius)
            .foregroundStyle(
                viewModel.isUserInsideGeofence
                ? .indigo300.opacity(0.3)
                : .red300.opacity(0.3))
            .stroke(
                viewModel.isUserInsideGeofence ? .indigo300 : .red300,
                style: .init(
                    lineWidth: 2,
                    lineCap: .round,
                    dash: [8, 6]
                )
            )
        }
    }
}

#if DEBUG
#Preview {
    BaseMapComponent(viewModel: .init(
        container: AttendancePreviewData.container,
        info: AttendancePreviewData.sessionInfo,
        errorHandler: AttendancePreviewData.errorHandler))
}
#endif
