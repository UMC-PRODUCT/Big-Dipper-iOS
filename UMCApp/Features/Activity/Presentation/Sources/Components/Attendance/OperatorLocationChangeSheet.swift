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

// MARK: - OperatorLocationChangeSheet

/// 일정 출석 위치 변경 시트
///
/// 대상 일정 정보를 보여주고, 공용 장소 선택기(``PlaceSelectView``)에서 고른 좌표로
/// 위치 변경을 요청합니다. 장소 선택 모델도 Core canonical(``PlaceSelection``)을 그대로 씁니다.
struct OperatorLocationChangeSheet: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlace: PlaceSelection = .empty
    @State private var isSubmitting: Bool = false

    private let scheduleName: String
    private let startsAt: Date
    private let endsAt: Date
    private let onSubmit: (PlaceSelection) async -> Bool

    // MARK: - Init

    /// - Parameters:
    ///   - scheduleName: 대상 일정 제목
    ///   - startsAt: 일정 시작 시각
    ///   - endsAt: 일정 종료 시각
    ///   - onSubmit: 선택한 장소로 위치 변경을 수행하고 성공 여부를 반환한다.
    init(
        scheduleName: String,
        startsAt: Date,
        endsAt: Date,
        onSubmit: @escaping (PlaceSelection) async -> Bool
    ) {
        self.scheduleName = scheduleName
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.onSubmit = onSubmit
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
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolBarCollection.CancelBtn { }

        ToolBarCollection.ConfirmBtn(
            action: submit,
            disable: selectedPlace.isEmpty,
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

            PlaceSelectView(place: $selectedPlace, placeholder: Constants.placePlaceholder)
        }
        .padding(Constants.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            .regular,
            in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius))
        )
    }

    // MARK: - Function

    /// 선택한 장소로 변경을 요청한다. 성공했을 때만 시트를 닫아 실패 사유(Alert)를 유지한다.
    private func submit() {
        guard !isSubmitting, !selectedPlace.isEmpty else { return }
        isSubmitting = true
        let place = selectedPlace
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
    static let detentHeight: CGFloat = 320
    static let placePlaceholder: String = "변경할 위치를 선택해 주세요"
}
