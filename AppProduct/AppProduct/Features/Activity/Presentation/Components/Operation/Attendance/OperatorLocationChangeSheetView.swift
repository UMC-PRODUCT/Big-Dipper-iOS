//
//  OperatorLocationChangeSheetView.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/6/26.
//

import SwiftUI

/// 세션 위치 변경 시트
///
/// 세션 정보를 표시하고 새 위치를 검색하여 선택할 수 있는 시트입니다.
struct OperatorLocationChangeSheetView: View {

    // MARK: - Property

    @Bindable private var viewModel: AttendanceDetailViewModel
    private let errorHandler: ErrorHandler

    @State private var selectedPlace: PlaceSearchInfo = .init(
        name: "",
        address: "",
        coordinate: .init(latitude: 0, longitude: 0)
    )
    @State private var showSearchPlaceSheet: Bool = false
    @State private var isSubmitting = false

    // MARK: - Constant

    private enum Constants {
        static let rootHorizontalPadding: CGFloat = 14
        static let rootTopPadding: CGFloat = 6
        static let rootBottomPadding: CGFloat = 16
    }

    // MARK: - Init

    init(
        viewModel: AttendanceDetailViewModel,
        errorHandler: ErrorHandler,
    ) {
        self.viewModel = viewModel
        self.errorHandler = errorHandler
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
                if let session = viewModel.selectedSession {
                    sessionInfoCard(session: session)
                    placeSelectionCard
                } else {
                    Text("세션 정보를 불러올 수 없습니다.")
                        .appFont(.subheadline, color: .grey500)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, DefaultSpacing.spacing8)
                }
            }
            .padding(.horizontal, Constants.rootHorizontalPadding)
            .padding(.top, Constants.rootTopPadding)
            .padding(.bottom, Constants.rootBottomPadding)
            .navigationTitle("위치 변경")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolBarCollection.CancelBtn {
                    viewModel.showLocationSheet = false
                }

                ToolBarCollection.ConfirmBtn(
                    action: submitChange,
                    disable: selectedPlace.name.isEmpty,
                    isLoading: isSubmitting,
                    dismissOnTap: false
                )
            }
            .sheet(isPresented: $showSearchPlaceSheet) {
                SearchMapView(errorHandler: errorHandler) { place in
                    selectedPlace = place
                    showSearchPlaceSheet = false
                }
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func submitChange() {
        guard !isSubmitting else { return }
        isSubmitting = true
        let placeSnapshot = selectedPlace
        Task { @MainActor in
            let isSuccess = await viewModel.confirmLocationChange(to: placeSnapshot)
            isSubmitting = false

            if isSuccess {
                viewModel.showLocationSheet = false
            }
        }
    }

    // MARK: - Session Info Card

    private func sessionInfoCard(session: Session) -> some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
            Text("세션")
                .appFont(.caption1, color: .grey500)

            Text(session.info.title)
                .appFont(.calloutEmphasis)

            Text(session.info.startTime.timeRange(to: session.info.endTime))
                .appFont(.footnote, color: .grey500)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius))
        .glass()
    }

    // MARK: - Place Selection Card

    private var placeSelectionCard: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
            Text("새 위치")
                .appFont(.caption1, color: .grey500)

            Group {
                if selectedPlace.name == "" {
                    placeholderPlaceInfo
                } else {
                    selectedPlaceInfo
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                showSearchPlaceSheet = true
            }
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius))
        .glass()
    }

    private var placeholderPlaceInfo: some View {
        HStack {
            Image(systemName: "location.circle")
                .foregroundStyle(.grey400)
            Text("위치 선택하기")
                .appFont(.callout, color: .grey500)
        }
        .padding(.vertical, 2)
    }

    private var selectedPlaceInfo: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
            Text(selectedPlace.name)
                .appFont(.calloutEmphasis)

            Text(selectedPlace.address)
                .appFont(.footnote, color: .grey500)
        }
    }
}
