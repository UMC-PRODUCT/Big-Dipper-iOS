//
//  OperatorLocationChangeSheet.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/25/26.
//

import CoreDesignSystem
import CoreUIComponents
import SwiftUI
import UMCFoundation

// MARK: - PlaceSelection

/// 위치 변경 시트가 요구하는 장소 선택 결과.
///
/// 장소 검색 화면(주입)이 사용자의 선택을 이 값으로 돌려주면, 시트가 좌표 검증을 포함한
/// 변경 요청으로 이어갑니다.
public struct PlaceSelection: Equatable, Sendable {

    /// 장소명 (예: "한성대학교 상상관")
    public let name: String

    /// 주소 (없으면 빈 문자열)
    public let address: String

    public let latitude: Double
    public let longitude: Double

    public init(name: String, address: String, latitude: Double, longitude: Double) {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: - OperatorLocationChangeSheet

/// 일정 출석 위치 변경 시트
///
/// 대상 일정 정보를 보여주고, 주입된 장소 검색 화면에서 고른 좌표로 위치 변경을 요청합니다.
///
/// > Note: 장소 검색 UI 는 주입 seam(`placeSearch`)으로 분리했습니다. 레거시 시트는 Home
///   피처의 `SearchMapView` 를 직접 임베드했지만, 장소 선택기(`PlaceSelectView` 계열)의 이식
///   목적지는 `CoreUIComponents` 이고 아직 이식 전입니다. ActivityPresentation 이 MapKit·Home
///   모듈에 의존하지 않도록 검색 화면은 상위(구성 루트)가 주입하고, 시트는 선택 결과만 받습니다.
struct OperatorLocationChangeSheet<PlaceSearch: View>: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlace: PlaceSelection?
    @State private var isPlaceSearchPresented: Bool = false
    @State private var isSubmitting: Bool = false

    private let scheduleName: String
    private let startsAt: Date
    private let endsAt: Date
    private let onSubmit: (PlaceSelection) async -> Bool
    private let placeSearch: (@escaping (PlaceSelection) -> Void) -> PlaceSearch

    // MARK: - Init

    /// - Parameters:
    ///   - scheduleName: 대상 일정 제목
    ///   - startsAt: 일정 시작 시각
    ///   - endsAt: 일정 종료 시각
    ///   - onSubmit: 선택한 장소로 위치 변경을 수행하고 성공 여부를 반환한다.
    ///   - placeSearch: 장소 검색 화면 빌더. 인자로 받은 콜백에 선택 결과를 전달한다.
    init(
        scheduleName: String,
        startsAt: Date,
        endsAt: Date,
        onSubmit: @escaping (PlaceSelection) async -> Bool,
        @ViewBuilder placeSearch: @escaping (@escaping (PlaceSelection) -> Void) -> PlaceSearch
    ) {
        self.scheduleName = scheduleName
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.onSubmit = onSubmit
        self.placeSearch = placeSearch
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
                scheduleInfoCard
                placeSelectionCard
            }
            .padding(.horizontal, Constants.rootHorizontalPadding)
            .padding(.top, Constants.rootTopPadding)
            .padding(.bottom, DefaultSpacing.spacing16)
            .frame(maxHeight: .infinity, alignment: .top)
            .navigation(naviTitle: NavigationTitle.Activity.locationChange, displayMode: .inline)
            .presentationDetents([.height(Constants.detentHeight)])
            .presentationDragIndicator(.visible)
            .toolbar { toolbarContent }
            .sheet(isPresented: $isPlaceSearchPresented) {
                placeSearch { place in
                    selectedPlace = place
                    isPlaceSearchPresented = false
                }
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolBarCollection.CancelBtn { }

        ToolBarCollection.ConfirmBtn(
            action: submit,
            disable: selectedPlace == nil,
            isLoading: isSubmitting,
            dismissOnTap: false
        )
    }

    // MARK: - View Components

    private var scheduleInfoCard: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
            Text("일정")
                .appFont(.caption1, color: .grey500)

            Text(scheduleName)
                .appFont(.callout, weight: .semibold)
                .lineLimit(2)

            Text(startsAt.timeRange(to: endsAt))
                .appFont(.footnote, color: .grey500)
        }
        .padding(Constants.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            .regular,
            in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius))
        )
    }

    private var placeSelectionCard: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
            Text("새 위치")
                .appFont(.caption1, color: .grey500)

            Group {
                if let place = selectedPlace {
                    selectedPlaceInfo(place: place)
                } else {
                    placeholderPlaceInfo
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                isPlaceSearchPresented = true
            }
        }
        .padding(Constants.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            .regular,
            in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius))
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint("탭하면 장소를 검색합니다")
    }

    private var placeholderPlaceInfo: some View {
        HStack {
            Image(systemName: "location.circle")
                .foregroundStyle(Color.grey400)
            Text("위치 선택하기")
                .appFont(.callout, color: .grey500)
        }
        .padding(.vertical, Constants.placeholderVerticalPadding)
    }

    private func selectedPlaceInfo(place: PlaceSelection) -> some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
            Text(place.name)
                .appFont(.callout, weight: .semibold)

            if !place.address.isEmpty {
                Text(place.address)
                    .appFont(.footnote, color: .grey500)
            }
        }
    }

    // MARK: - Function

    /// 선택한 장소로 변경을 요청한다. 성공했을 때만 시트를 닫아 실패 사유(Alert)를 유지한다.
    private func submit() {
        guard !isSubmitting, let place = selectedPlace else { return }
        isSubmitting = true
        Task {
            let isSuccess = await onSubmit(place)
            isSubmitting = false
            if isSuccess {
                dismiss()
            }
        }
    }
}

// MARK: - Constants

private enum Constants {
    static let rootHorizontalPadding: CGFloat = 14
    static let rootTopPadding: CGFloat = 6
    static let cardPadding: CGFloat = 14
    static let placeholderVerticalPadding: CGFloat = 2
    static let detentHeight: CGFloat = 320
}
