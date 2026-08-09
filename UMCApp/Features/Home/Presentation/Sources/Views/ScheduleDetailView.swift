//
//  ScheduleDetailView.swift
//  HomePresentation
//
//  Created by euijjang97 on 8/6/26.
//

import CoreDesignSystem
import CoreDI
import CoreDomain
import CoreUIComponents
import HomeDomain
import SwiftUI
import UMCFoundation

/// 일정 상세 화면.
///
/// 장소는 역지오코딩 없이 좌표 그대로 Apple Maps 로 넘긴다. 툴바 액션(수정/삭제)은 각각의
/// 리소스 권한에 따라 독립적으로 노출하고, 수정은 편집 모드 등록 화면을 시트로 띄운다.
///
/// 출석 진입은 활동 모드로 갈린다. Admin 모드면 출석 현황 화면으로 이동하는 버튼을, 그 외에는
/// 내 출석 상태를 read-only 로 보여 준다. 출석 비필수 일정은 두 경우 모두 표시하지 않는다.
public struct ScheduleDetailView: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ScheduleDetailViewModel

    /// 편집 시트에 실을 일정. `nil` 이면 시트가 닫힌 상태다.
    @State private var editingSchedule: ScheduleDetailData?

    private let container: DIContainer
    private let onAttendanceStatusTapped: () -> Void

    // MARK: - Constants

    fileprivate enum Constants {
        static let loadingMessage: String = "일정 정보를 가져오는 중입니다."
        static let detailTitle: String = "상세 안내"
        static let attendanceTitle: String = "출석"
        static let attendanceStatusButtonTitle: String = "출석 현황"
        static let myAttendanceStatusTitle: String = "내 출석 상태"
        static let editActionTitle: String = "수정하기"
        static let editIcon: String = "pencil"
        static let deleteActionTitle: String = "삭제하기"
        static let deleteIcon: String = "trash"
        static let failedTitle: String = "일정을 불러오지 못했어요"
        static let failedSystemImage: String = "exclamationmark.triangle"
    }

    // MARK: - Init

    /// - Parameters:
    ///   - container: UseCase·세션을 resolve할 DI 컨테이너
    ///   - errorHandler: 삭제·강제 삭제 실패를 전역 Alert 로 올릴 핸들러
    ///   - scheduleId: 조회할 일정 식별자
    ///   - onAttendanceStatusTapped: 출석 현황 버튼 탭 시 화면 이동을 위임하는 콜백
    ///
    /// - Note: 조회 실패는 인라인(`Loadable`)으로 남고, 흐름을 끊는 삭제 실패만 `ErrorHandler` 로 간다.
    public init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        scheduleId: String,
        onAttendanceStatusTapped: @escaping () -> Void
    ) {
        _viewModel = State(
            initialValue: ScheduleDetailViewModel(
                container: container,
                scheduleId: scheduleId,
                errorHandler: errorHandler
            )
        )
        self.container = container
        self.onAttendanceStatusTapped = onAttendanceStatusTapped
    }

    // MARK: - Body

    public var body: some View {
        stateContent
            .umcDefaultBackground()
            .navigation(
                naviTitle: NavigationTitle.Activity.scheduleDetail,
                displayMode: .inline
            )
            .toolbar { toolbarContent }
            .alertPrompt(item: $viewModel.alertPrompt)
            .sheet(
                item: $editingSchedule,
                // 저장 여부를 시트에서 돌려받는 배관 대신, 닫힐 때 항상 재조회해 최신 값을 맞춘다.
                onDismiss: { Task { await viewModel.load() } }
            ) { detail in
                // 편집 화면 툴바가 `.toolbar` 기반이라 시트 안에서도 네비게이션 컨테이너가 필요하다.
                NavigationStack {
                    ScheduleRegistrationView(container: container, mode: .edit, prefill: detail)
                }
            }
            .onChange(of: viewModel.isDeleted) { _, isDeleted in
                if isDeleted { dismiss() }
            }
            .task {
                async let detail: Void = viewModel.load()
                async let permission: Void = viewModel.fetchSchedulePermission()
                await detail
                await permission
            }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !toolbarActions.isEmpty {
            ToolBarCollection.ToolbarTrailingMenu(actions: toolbarActions)
        }
    }

    /// 권한별로 구성되는 툴바 액션 목록. 삭제 중에는 비워 중복 요청을 막는다.
    private var toolbarActions: [ToolBarCollection.ToolbarTrailingMenu.ActionItem] {
        guard let detail = viewModel.data.value, !viewModel.isDeleting else { return [] }

        var actions: [ToolBarCollection.ToolbarTrailingMenu.ActionItem] = []

        if viewModel.canEditSchedule {
            actions.append(
                .init(
                    title: Constants.editActionTitle,
                    icon: Constants.editIcon,
                    action: { editingSchedule = detail }
                )
            )
        }

        if viewModel.canDeleteSchedule {
            actions.append(
                .init(
                    title: Constants.deleteActionTitle,
                    icon: Constants.deleteIcon,
                    role: .destructive,
                    action: viewModel.showDeleteConfirmation
                )
            )
        }

        return actions
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
        case .failed(let error):
            RetryContentUnavailableView(
                title: Constants.failedTitle,
                systemImage: Constants.failedSystemImage,
                description: error.userMessage,
                isRetrying: viewModel.data.isLoading,
                retryAction: { await viewModel.load() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func content(_ data: ScheduleDetailData) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing24) {
                topContent(data)

                if let policy = data.attendancePolicy {
                    AttendancePolicyDisplaySection(policy: policy)
                        .equatable()
                }

                attendanceSection

                detailDescription(data)
            }
        }
        .contentMargins(.horizontal, DefaultConstant.defaultSafeHorizon, for: .scrollContent)
        .contentMargins(.bottom, DefaultConstant.defaultContentBottomMargins, for: .scrollContent)
    }

    private func topContent(_ data: ScheduleDetailData) -> some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            Text(data.name)
                .appFont(.title2, weight: .semibold, color: .grey900)

            SchedulePlaceDateInfo(data: data, onMapLinkTapped: viewModel.openInMaps)
                .equatable()
        }
    }

    // MARK: - Attendance Section

    @ViewBuilder
    private var attendanceSection: some View {
        if viewModel.canViewAttendanceStatus {
            MainButton(Constants.attendanceStatusButtonTitle, action: onAttendanceStatusTapped)
                .buttonSize(.large)
                .buttonStyle(.glassProminent)
        } else if let statusText = viewModel.myAttendanceStatusText {
            myAttendanceStatus(statusText)
        }
    }

    private func myAttendanceStatus(_ statusText: String) -> some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            Text(Constants.attendanceTitle)
                .appFont(.title3, weight: .semibold, color: .grey900)

            HStack {
                Text(Constants.myAttendanceStatusTitle)
                    .appFont(.callout, color: .grey600)

                Spacer()

                Text(statusText)
                    .appFont(.callout, weight: .semibold, color: .grey900)
            }
            .padding(DefaultSpacing.spacing16)
            .glassEffect(
                .regular,
                in: .rect(
                    corners: .concentric(minimum: DefaultConstant.concentricRadius),
                    isUniform: true
                )
            )
        }
    }

    private func detailDescription(_ data: ScheduleDetailData) -> some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            Text(Constants.detailTitle)
                .appFont(.title3, weight: .semibold, color: .grey900)

            Text(data.description)
                .appFont(.callout, color: .grey600)
                .multilineTextAlignment(.leading)
        }
    }
}

// MARK: - SchedulePlaceDateInfo

/// 일정의 날짜/시간과 장소를 한 카드로 묶어 보여주는 컴포넌트.
private struct SchedulePlaceDateInfo: View, Equatable {

    // MARK: - Property

    let data: ScheduleDetailData
    let onMapLinkTapped: () -> Void

    fileprivate enum Constants {
        static let mapButtonTitle: String = "지도 보기"
        static let offlineFallbackTitle: String = "비대면"
        static let calendarImage: String = "calendar"
        static let locationImage: String = "mappin.and.ellipse"
        static let iconSize: CGFloat = 20
        static let iconBackgroundOpacity: CGFloat = 0.4
    }

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.data == rhs.data
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: .zero) {
            dateTimeSection
            Divider()
            locationSection
        }
        .glassEffect(
            .regular,
            in: .rect(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
        )
    }

    // MARK: - Section

    private var dateTimeSection: some View {
        infoSection(iconName: Constants.calendarImage, tintColor: .orange) {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                Text(dateText)
                    .appFont(.callout, weight: .semibold, color: .grey900)

                Text(timeText)
                    .appFont(.subheadline, color: .grey600)
            }
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        infoSection(iconName: Constants.locationImage, tintColor: .blue) {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                if let location = data.location {
                    Text(location.locationName)
                        .appFont(.callout, weight: .semibold, color: .grey900)

                    Button(Constants.mapButtonTitle, action: onMapLinkTapped)
                        .appFont(.footnote, color: .blue)
                } else {
                    Text(Constants.offlineFallbackTitle)
                        .appFont(.callout, weight: .semibold, color: .grey900)
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
            .font(.system(size: Constants.iconSize))
            .padding()
            .background(tintColor.opacity(Constants.iconBackgroundOpacity), in: .circle)
            .glassEffect(.clear, in: .circle)
    }

    // MARK: - Function

    /// 하루 안에서 끝나는 일정은 요일까지, 여러 날에 걸치면 시작~종료 날짜 범위를 보여준다.
    private var dateText: String {
        if Calendar.kstGregorian.isDate(data.startsAt, inSameDayAs: data.endsAt) {
            return data.startsAt.toYearMonthDayWithWeekday()
        }
        return data.startsAt.dateRange(to: data.endsAt)
    }

    /// 서버가 종료 시각을 시작보다 앞서 내려주는 비정상 데이터에서는 범위 대신 시작 시각만 쓴다.
    private var timeText: String {
        guard data.startsAt <= data.endsAt else { return data.startsAt.toHourMinutes() }
        return data.startsAt.timeRange(to: data.endsAt)
    }
}

// MARK: - Preview

#if DEBUG
/// 네트워크 없이 화면을 확인하기 위한 프리뷰 전용 UseCase (절대규칙 #5)
private struct PreviewFetchScheduleDetailUseCase: FetchScheduleDetailUseCaseProtocol {
    func execute(scheduleId: String) async throws -> ScheduleDetailData {
        let startsAt = Date.now
        return ScheduleDetailData(
            scheduleId: scheduleId,
            name: "iOS 파트 정기 스터디",
            description: "워크북 6주차 발표와 코드 리뷰를 진행합니다.",
            tags: ["스터디"],
            startsAt: startsAt,
            endsAt: startsAt.addingTimeInterval(7_200),
            isParticipant: true,
            location: ScheduleLocation(
                latitude: 37.582_86,
                longitude: 127.010_39,
                locationName: "한성대학교 상상관"
            ),
            attendancePolicy: ScheduleAttendancePolicy(
                checkInStartAt: startsAt.addingTimeInterval(-1_800),
                onTimeEndAt: startsAt.addingTimeInterval(600),
                lateEndAt: startsAt.addingTimeInterval(1_800)
            ),
            attendanceStatus: .present
        )
    }
}

/// 삭제 액션을 노출하기 위한 프리뷰 전용 권한 스텁 (절대규칙 #5)
private struct PreviewAuthorizationUseCase: AuthorizationUseCaseProtocol {
    func getResourcePermission(
        resourceType: AuthorizationResourceType,
        resourceId: String
    ) async throws -> ResourcePermission {
        ResourcePermission(
            resourceType: resourceType,
            resourceId: resourceId,
            grantedPermissions: [.delete]
        )
    }
}

private struct PreviewDeleteScheduleUseCase: DeleteScheduleUseCaseProtocol,
                                             ForceDeleteScheduleUseCaseProtocol {
    func execute(scheduleId: String) async throws {}
}

#Preview {
    let container = DIContainer()
    container.register(FetchScheduleDetailUseCaseProtocol.self) {
        PreviewFetchScheduleDetailUseCase()
    }
    container.register(DeleteScheduleUseCaseProtocol.self) { PreviewDeleteScheduleUseCase() }
    container.register(ForceDeleteScheduleUseCaseProtocol.self) {
        PreviewDeleteScheduleUseCase()
    }
    container.register(AuthorizationUseCaseProtocol.self) { PreviewAuthorizationUseCase() }
    container.register(UserSessionManager.self) { UserSessionManager() }
    return NavigationStack {
        ScheduleDetailView(
            container: container,
            errorHandler: ErrorHandler(),
            scheduleId: "1",
            onAttendanceStatusTapped: {}
        )
    }
}
#endif
