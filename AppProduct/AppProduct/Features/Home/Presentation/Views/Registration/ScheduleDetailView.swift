//
//  ScheduleDetailView.swift
//  AppProduct
//
//  Created by euijjang97 on 2/13/26.
//

import SwiftUI

/// 일정 상세 화면
struct ScheduleDetailView: View {

    // MARK: - Property

    @State var viewModel: ScheduleDetailViewModel
    @Environment(\.di) private var di
    @Environment(\.dismiss) private var dismiss
    @Environment(ErrorHandler.self) private var errorHandler

    private enum Constants {
        static let loadingMessage: String = "일정 정보를 가져오는 중입니다."
        static let editLoadingMessage: String = "일정 정보를 불러오는 중입니다."
        static let detailTitle: String = "상세 안내"
        static let mapButtonTitle: String = "지도 보기"
        static let failedTitle: String = "일정을 불러오지 못했어요"
        static let failedSystemImage: String = "exclamationmark.triangle"
        static let retryTitle: String = "다시 시도"
        static let retryMinButtonWidth: CGFloat = 72
        static let retryMinButtonHeight: CGFloat = 20
    }

    // MARK: - Init

    init(scheduleId: Int) {
        self._viewModel = .init(initialValue: .init(
            scheduleId: scheduleId
        ))
    }

    // MARK: - Body

    var body: some View {
        stateContent
        .navigation(naviTitle: .detailSchedule, displayMode: .inline)
        .toolbar { toolbarContent }
        .alertPrompt(item: $viewModel.alertPromprt)
        .fullScreenCover(
            isPresented: $viewModel.isShowModify,
            onDismiss: {
                Task { @MainActor in
                    let provider = di.resolve(HomeUseCaseProviding.self)
                    await viewModel.fetchScheduleDetail(
                        fetchScheduleDetailUseCase: provider.fetchScheduleDetailUseCase
                    )
                }
            },
            content: editCoverContent
        )
        .task {
            let provider = di.resolve(HomeUseCaseProviding.self)
            let authorizationUseCase = di.resolve(AuthorizationUseCaseProtocol.self)
            async let detailTask: () = viewModel.fetchScheduleDetail(
                fetchScheduleDetailUseCase: provider.fetchScheduleDetailUseCase
            )
            async let permissionTask: () = viewModel.fetchSchedulePermission(
                authorizationUseCase: authorizationUseCase
            )
            _ = await (detailTask, permissionTask)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var stateContent: some View {
        switch viewModel.data {
        case .idle, .loading:
            Progress(message: Constants.loadingMessage, size: .regular)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let data):
            content(data)
                .task {
                    if let location = data.location {
                        await viewModel.fetchRoadAddress(
                            latitude: location.latitude,
                            longitude: location.longitude
                        )
                    }
                }
        case .failed(let error):
            RetryContentUnavailableView(
                title: Constants.failedTitle,
                systemImage: Constants.failedSystemImage,
                description: error.userMessage,
                retryTitle: Constants.retryTitle,
                isRetrying: viewModel.data.isLoading,
                minRetryButtonWidth: Constants.retryMinButtonWidth,
                minRetryButtonHeight: Constants.retryMinButtonHeight
            ) {
                let provider = di.resolve(HomeUseCaseProviding.self)
                await viewModel.fetchScheduleDetail(
                    fetchScheduleDetailUseCase: provider.fetchScheduleDetailUseCase
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if let loadedData, viewModel.canEditSchedule || viewModel.canDeleteSchedule {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if viewModel.canEditSchedule {
                    Button(action: {
                        Task { @MainActor in
                            await openModifySheetIfPossible(with: loadedData)
                        }
                    }) {
                        Image(systemName: "pencil")
                    }
                    .disabled(viewModel.isScheduleStarted)
                    .accessibilityLabel(
                        viewModel.isScheduleStarted ? "일정 수정 불가" : "일정 수정"
                    )
                    .accessibilityHint(
                        viewModel.isScheduleStarted ? "이미 시작된 일정은 수정할 수 없습니다" : ""
                    )
                }

                if viewModel.canDeleteSchedule {
                    if viewModel.isDeleting {
                        ProgressView()
                            .tint(.red)
                    } else {
                        Button(role: .destructive, action: {
                            viewModel.deleteAlertAction {
                                Task { @MainActor in
                                    let success = await deleteSchedule(
                                        scheduleId: loadedData.scheduleId
                                    )
                                    if success { dismiss() }
                                }
                            }
                        }) {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func editCoverContent() -> some View {
        if case .loaded(let data) = viewModel.data {
            NavigationStack {
                ScheduleRegistrationView(
                    container: di,
                    errorHandler: errorHandler,
                    mode: .edit,
                    prefill: data,
                    prefillRoadAddress: viewModel.roadAddress
                )
            }
        } else {
            Progress(message: Constants.editLoadingMessage, size: .regular)
        }
    }

    // MARK: - Helper

    /// 역지오코딩이 완료된 후 수정 시트를 표시합니다.
    ///
    /// 도로명 주소가 아직 조회되지 않은 경우 먼저 조회 후 수정 화면을 엽니다.
    @MainActor
    private func openModifySheetIfPossible(with data: ScheduleDetailData) async {
        if viewModel.roadAddress == nil, let location = data.location {
            await viewModel.fetchRoadAddress(
                latitude: location.latitude,
                longitude: location.longitude
            )
        }
        viewModel.isShowModify = true
    }

    /// Loadable 상태에서 로드된 데이터를 추출합니다.
    private var loadedData: ScheduleDetailData? {
        switch viewModel.data {
        case .loaded(let data):
            return data
        case .idle, .loading, .failed:
            return nil
        }
    }

    /// 일정과 출석부를 함께 삭제합니다.
    ///
    /// 서버가 출석 기록 존재로 인해 일반 삭제를 거부(``DomainError/scheduleHasAttendanceRecords``)하면,
    /// FORCE_DELETE 권한 보유자(일정 기수의 SUPER_ADMIN)에게는 2차 확인 후 강제 삭제 플로우를 제공하고,
    /// 그 외 사용자에게는 기존 에러 핸들러 경로를 그대로 사용합니다.
    ///
    /// - Parameter scheduleId: 삭제할 일정 ID
    /// - Returns: 삭제 성공 여부
    @MainActor
    @discardableResult
    private func deleteSchedule(scheduleId: Int) async -> Bool {
        viewModel.isDeleting = true
        defer { viewModel.isDeleting = false }

        do {
            let provider = di.resolve(HomeUseCaseProviding.self)
            try await provider.deleteScheduleUseCase.execute(
                scheduleId: scheduleId
            )
            return true
        } catch DomainError.scheduleHasAttendanceRecords where viewModel.canForceDeleteSchedule {
            viewModel.forceDeleteAlertAction {
                Task { @MainActor in
                    let success = await forceDeleteSchedule(scheduleId: scheduleId)
                    if success { dismiss() }
                }
            }
            return false
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Home",
                action: "deleteScheduleWithAttendance",
                retryAction: { [weak di] in
                    guard let di else { return }
                    let provider = di.resolve(HomeUseCaseProviding.self)
                    try? await provider.deleteScheduleUseCase.execute(
                        scheduleId: scheduleId
                    )
                }
            ))
            return false
        }
    }

    /// 출석 기록을 포함한 일정을 강제 삭제합니다 (SUPER_ADMIN 전용).
    ///
    /// - Parameter scheduleId: 강제 삭제할 일정 ID
    /// - Returns: 삭제 성공 여부
    @MainActor
    @discardableResult
    private func forceDeleteSchedule(scheduleId: Int) async -> Bool {
        viewModel.isDeleting = true
        defer { viewModel.isDeleting = false }

        do {
            let provider = di.resolve(HomeUseCaseProviding.self)
            try await provider.forceDeleteScheduleUseCase.execute(
                scheduleId: scheduleId
            )
            return true
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Home",
                action: "forceDeleteSchedule",
                retryAction: { [weak di] in
                    guard let di else { return }
                    let provider = di.resolve(HomeUseCaseProviding.self)
                    try? await provider.forceDeleteScheduleUseCase.execute(
                        scheduleId: scheduleId
                    )
                }
            ))
            return false
        }
    }

    private func content(_ data: ScheduleDetailData) -> some View {
        ScrollView(content: {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing24, content: {
                topContent(data)
                if let policy = data.attendancePolicy {
                    AttendancePolicyDisplaySection(policy: policy)
                        .equatable()
                }
                detailDescription(data)
            })
        })
        .contentMargins(.horizontal, DefaultConstant.defaultSafeHorizon, for: .scrollContent)
    }

    private func topContent(_ data: ScheduleDetailData) -> some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12, content: {
            Text(data.name)
                .appFont(.title2Emphasis, color: .black)

            SchedulePlaceDateInfo(
                data: data,
                roadAddress: viewModel.roadAddress,
                onMapLinkTapped: {
                    guard let location = data.location else { return }
                    viewModel.mapLinkTapped(
                        latitude: location.latitude,
                        longitude: location.longitude,
                        locationName: location.locationName
                    )
                }
            )
            .equatable()

            if viewModel.isScheduleStarted {
                HStack(spacing: DefaultSpacing.spacing8) {
                    Image(systemName: "lock.fill")
                    Text("이미 시작된 일정은 수정할 수 없습니다")
                }
                .appFont(.caption1, color: .grey500)
            }
        })
    }

    private func detailDescription(_ data: ScheduleDetailData) -> some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12, content: {
            Text(Constants.detailTitle)
                .appFont(.title2Emphasis, color: .black)

            Text(data.description)
                .appFont(.callout, color: .grey600)
                .multilineTextAlignment(.leading)
        })
    }
}

/// 일정 상세의 날짜/시간 및 장소 정보 표시 컴포넌트
///
/// Container-Presenter 패턴으로 Equatable을 준수하여 불필요한 리렌더링을 방지합니다.
private struct SchedulePlaceDateInfo: View, Equatable {

    // MARK: - Property

    let data: ScheduleDetailData
    let roadAddress: String?
    let onMapLinkTapped: () -> Void

    private enum Constants {
        static let mapButtonTitle: String = "지도 보기"
    }

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.data == rhs.data
        && lhs.roadAddress == rhs.roadAddress
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: .zero) {
            dateTimeSection
            Divider()
            locationSection
        }
        .background {
            ConcentricRectangle(corners: .concentric(minimum: DefaultConstant.concentricRadius), isUniform: true)
                .fill(Color.white)
                .glass()
        }
    }

    // MARK: - Section

    private var dateTimeSection: some View {
        infoSection(iconName: "calendar", tintColor: .orange) {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                Text(dateText)
                    .appFont(.calloutEmphasis)
                    .foregroundStyle(.black)

                Text(timeText)
                    .appFont(.subheadline)
                    .foregroundStyle(.grey600)
            }
        }
    }

    private var locationSection: some View {
        infoSection(iconName: "mappin.and.ellipse", tintColor: .blue) {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                if let location = data.location {
                    Text(location.locationName)
                        .appFont(.calloutEmphasis)
                        .foregroundStyle(.black)

                    if let roadAddress {
                        Text(roadAddress)
                            .appFont(.subheadline)
                            .foregroundStyle(.grey600)
                    }

                    Button(Constants.mapButtonTitle, action: onMapLinkTapped)
                        .appFont(.footnote)
                        .foregroundStyle(.blue)
                } else {
                    Text("비대면")
                        .appFont(.calloutEmphasis)
                        .foregroundStyle(.black)
                }
            }
        }
    }

    // MARK: - Component

    private func infoSection<Content: View>(
        iconName: String,
        tintColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: DefaultSpacing.spacing16) {
            infoIcon(systemName: iconName, tintColor: tintColor)
            content()
            Spacer()
        }
        .padding(DefaultSpacing.spacing16)
    }

    private func infoIcon(systemName: String, tintColor: Color) -> some View {
        Image(systemName: systemName)
            .foregroundStyle(tintColor)
            .font(.system(size: 20))
            .padding()
            .background(tintColor.opacity(0.4), in: .circle)
            .glassEffect(.clear, in: .circle)
    }

    private var dateText: String {
        guard data.startsAt <= data.endsAt else {
            return data.startsAt.toYearMonthDayWithWeekday()
        }
        return (data.startsAt...data.endsAt).scheduleDateRangeText
    }

    private var timeText: String {
        guard data.startsAt <= data.endsAt else {
            return data.startsAt.toHourMinutes()
        }
        return (data.startsAt...data.endsAt).scheduleTimeRangeText
    }
}
