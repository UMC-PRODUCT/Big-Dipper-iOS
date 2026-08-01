//
//  BaseMapComponent.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/30/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import MapKit
import SwiftUI

/// 세션 위치와 지오펜스를 표시하는 기본 지도 컴포넌트
///
/// - 세션 마커: 스터디/세미나 장소 표시
/// - 지오펜스 오버레이: 출석 가능 영역 시각화
/// - 사용자 위치: `UserAnnotation` 으로 현재 위치 표시
struct BaseMapComponent: View, Equatable {

    // MARK: - Property

    @Bindable private var viewModel: BaseMapViewModel

    fileprivate enum Constants {
        static let iconSize: CGFloat = 24
        static let geofenceLineWidth: CGFloat = 2
        static let geofenceDashPattern: [CGFloat] = [8, 6]
        static let geofenceFillOpacity: CGFloat = 0.3
    }

    // MARK: - Init

    init(viewModel: BaseMapViewModel) {
        self.viewModel = viewModel
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.viewModel === rhs.viewModel
    }

    // MARK: - Body

    var body: some View {
        Map(position: $viewModel.cameraPosition) {
            geofenceOverlay
            sessionMarker
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
    private var sessionMarker: some MapContent {
        Annotation(
            viewModel.sessionInfo.title,
            coordinate: viewModel.sessionLocation,
            anchor: .bottom
        ) {
            Image.umcMapPin
                .resizable()
                .scaledToFit()
                .frame(width: Constants.iconSize, height: Constants.iconSize)
        }
    }

    /// 지오펜스 영역 오버레이 (출석 가능 범위)
    @MapContentBuilder
    private var geofenceOverlay: some MapContent {
        if let geofenceCenter = viewModel.geofenceCenter {
            let accentColor: Color = viewModel.isUserInsideGeofence ? .indigo300 : .red300

            MapCircle(
                center: geofenceCenter,
                radius: AttendancePolicy.geofenceRadius
            )
            .foregroundStyle(accentColor.opacity(Constants.geofenceFillOpacity))
            .stroke(
                accentColor,
                style: StrokeStyle(
                    lineWidth: Constants.geofenceLineWidth,
                    lineCap: .round,
                    dash: Constants.geofenceDashPattern
                )
            )
        }
    }
}
