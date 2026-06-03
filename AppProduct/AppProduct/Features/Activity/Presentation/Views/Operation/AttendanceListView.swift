//
//  AttendanceListView.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import SwiftUI

/// 운영진 출석 현황 목록 화면 (Schedule V2 #658)
///
/// `GET /api/v2/schedules/attendance` 의 응답을 카드 리스트로 표시하고,
/// 상태 필터 칩 + 기간 필터(AC#7)를 통해 서버 측 필터링을 트리거합니다.
///
/// 행 탭 시 `Activity.attendanceDetail(scheduleId:)` 로 stack push.
struct AttendanceListView: View {

    // MARK: - Property

    @Environment(\.di) private var di
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: AttendanceListViewModel

    /// "직접 입력" 기간 편집 시트 표시 플래그 (View 전용 일시 상태)
    @State private var isCustomDatePresented: Bool = false

    // MARK: - Init

    init(
        container: DIContainer,
        errorHandler: ErrorHandler
    ) {
        let useCase = container.resolve(ActivityUseCaseProviding.self)
            .operatorAttendanceUseCase
        _viewModel = State(initialValue: AttendanceListViewModel(
            container: container,
            errorHandler: errorHandler,
            useCase: useCase
        ))
    }

    #if DEBUG
    /// 프리뷰 전용 init — 더미 데이터가 주입된 ViewModel 을 직접 받는다.
    init(viewModel: AttendanceListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    #endif

    // MARK: - Body

    var body: some View {
        listStateContent
            .animation(.easeInOut(duration: 0.2), value: viewModel.totalPendingCount > 0)
            // 상태/기간 필터는 우상단 툴바의 단일 메뉴 버튼으로 올린다.
            // 승인 대기 배너만 상단 safeAreaBar 에 고정한다. (권한 거부 시에는 모두 숨김)
            .safeAreaBar(edge: .top) {
                if !viewModel.isPermissionDenied, viewModel.totalPendingCount > 0 {
                    pendingInboxBanner
                        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
                        .padding(.vertical, DefaultSpacing.spacing8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.isPermissionDenied {
                        filterMenu
                    }
                }
            }
            .navigationTitle("출석 현황")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isCustomDatePresented) {
                customDateSheet
                    .presentationDragIndicator(.visible)
            }
            .task {
                if case .idle = viewModel.listState {
                    await viewModel.fetch()
                }
            }
            .task(id: viewModel.listState.isComplete) {
                guard viewModel.listState.isComplete else { return }
                await viewModel.startPollingIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await viewModel.refreshList() }
                }
            }
            #if DEBUG
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("-mockShowDateSheet") {
                    isCustomDatePresented = true
                }
            }
            #endif
    }

    /// listState 에 따른 본문(목록/로딩/빈/에러/권한). 상단 safeAreaBar 아래의 스크롤 영역이다.
    @ViewBuilder
    private var listStateContent: some View {
        switch viewModel.listState {
        case .idle, .loading:
            loadingView
        case .loaded(let infos):
            if infos.isEmpty {
                emptyView
            } else {
                listContent(infos: infos)
            }
        case .failed(let error):
            if error.isPermissionDenied {
                permissionDeniedView
            } else {
                errorView(error: error)
            }
        }
    }

    // MARK: - Constants

    private enum Constants {
        static let permissionTitle: String = "접근 권한이 없어요"
        static let permissionDescription: String = "운영진 활동 이력이 있는 사용자만\n출석 현황을 조회할 수 있어요"
        static let permissionGuideTitle: String = "출석 관리가 가능한 역할"
        static let roleChapterLeader: String = "지부장"
        static let roleSchoolLeader: String = "학교 대표"
        static let roleOperator: String = "운영진"
        static let roleChapterLeaderDescription: String = "지부 내 전체 학교의 출석을 관리할 수 있어요"
        static let roleSchoolLeaderDescription: String = "소속 학교의 출석을 관리할 수 있어요"
        static let roleOperatorDescription: String = "담당 파트의 출석을 관리할 수 있어요"
        static let permissionGuideFooter: String = "권한이 필요하다면 지부장에게 역할 부여를 요청하세요"
    }

    // MARK: - Filter Toolbar Menu

    /// 우상단 툴바의 단일 필터 버튼. 버튼 하나 안에서 상태/기간을 각각 중첩 `Menu`(서브메뉴)로 제공한다.
    ///
    /// - Note: 라벨이 폭이 변하지 않는 고정 아이콘이라, `.glassEffect` 칩을 `Menu` 라벨로 쓸 때
    ///   발생하던 라벨 폭 변경 클립 문제가 없다. 옵션은 시스템 렌더링(Picker 체크마크)으로 표시된다.
    private var filterMenu: some View {
        Menu {
            Menu {
                Picker("출석 상태", selection: statusFilterBinding) {
                    Label("전체", systemImage: "square.grid.2x2")
                        .tag(nil as AttendanceStatusV2?)
                    ForEach(viewModel.filterableStatuses, id: \.self) { status in
                        Label(status.displayText, systemImage: status.iconName)
                            .tag(Optional(status))
                    }
                }
            } label: {
                Label("출석 상태", systemImage: "person.crop.circle.badge.checkmark")
            }

            Menu {
                Picker("조회 기간", selection: periodFilterBinding) {
                    ForEach(AttendancePeriodPreset.allCases) { preset in
                        Label(preset.label, systemImage: preset.iconName)
                            .tag(preset)
                    }
                }

                if viewModel.periodPreset == .custom {
                    Button {
                        isCustomDatePresented = true
                    } label: {
                        Label("입력 기간 수정", systemImage: "calendar.badge.clock")
                    }
                }
            } label: {
                Label("조회 기간", systemImage: "calendar")
            }
        } label: {
            Label(
                "필터",
                systemImage: isFilterActive
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
        }
        .accessibilityLabel("필터")
        .accessibilityValue(filterAccessibilityValue)
    }

    /// 기본값(전체 상태 + 최근 1개월)에서 벗어난 필터가 하나라도 적용됐는지.
    private var isFilterActive: Bool {
        viewModel.selectedFilter != nil || viewModel.periodPreset != .oneMonth
    }

    private var filterAccessibilityValue: String {
        "상태 \(viewModel.selectedFilter?.displayText ?? "전체"), 기간 \(viewModel.periodPreset.label)"
    }

    /// 상태 필터 Picker 바인딩 — 선택 즉시 재조회. nil("전체")은 `clearFilter` 로 분기한다.
    private var statusFilterBinding: Binding<AttendanceStatusV2?> {
        Binding(
            get: { viewModel.selectedFilter },
            set: { newValue in
                Task {
                    if let newValue {
                        await viewModel.filterButtonTapped(newValue)
                    } else {
                        await viewModel.clearFilter()
                    }
                }
            }
        )
    }

    /// 기간 프리셋 Picker 바인딩 — 선택 즉시 재조회. "직접 입력" 선택 시 날짜 시트를 띄운다.
    private var periodFilterBinding: Binding<AttendancePeriodPreset> {
        Binding(
            get: { viewModel.periodPreset },
            set: { newValue in
                Task { await viewModel.presetSelected(newValue) }
                if newValue == .custom {
                    isCustomDatePresented = true
                }
            }
        )
    }

    /// "직접 입력" 기간 편집 시트 — 시작/종료 날짜. 변경 즉시 재조회한다.
    private var customDateSheet: some View {
        NavigationStack {
            Form {
                DatePicker(
                    "시작일",
                    selection: $viewModel.fromDate,
                    displayedComponents: .date
                )
                .onChange(of: viewModel.fromDate) {
                    if viewModel.toDate < viewModel.fromDate {
                        viewModel.toDate = viewModel.fromDate.addingTimeInterval(24 * 60 * 60)
                    }
                    Task { await viewModel.fetch() }
                }
                .tint(Color.indigo)

                DatePicker(
                    "종료일",
                    selection: $viewModel.toDate,
                    in: viewModel.fromDate...,
                    displayedComponents: .date
                )
                .onChange(of: viewModel.toDate) {
                    Task { await viewModel.fetch() }
                }
                .tint(Color.indigo)
            }
            .navigationTitle("기간")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolBarCollection.ConfirmBtn(action: {})
            }
        }
        .presentationDetents([.medium])
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(.grey400)
            Text("출석 관리 일정이 아직 없어요")
                .appFont(.calloutEmphasis, color: .grey700)
            Text("출석이 필요한 일정을 생성하면\n이곳에 출석 현황이 모입니다.")
                .appFont(.footnote, color: .grey500)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(error: AppError) -> some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text(error.userMessage)
                .appFont(.subheadline, color: .grey600)
                .multilineTextAlignment(.center)
            Button("다시 시도") {
                Task { await viewModel.fetch() }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var pendingInboxBanner: some View {
        Button {
            guard let scheduleId = viewModel.firstPendingScheduleId else { return }
            di.resolve(PathStore.self).activityPath.append(
                .activity(.attendanceDetail(scheduleId: scheduleId))
            )
        } label: {
            HStack(spacing: DefaultSpacing.spacing12) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)

                Text("승인 대기 \(viewModel.totalPendingCount)건")
                    .appFont(.calloutEmphasis, color: .grey700)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.grey400)
            }
            .padding(DefaultSpacing.spacing16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                .regular,
                in: ConcentricRectangle(
                    corners: .concentric(minimum: DefaultConstant.concentricRadius),
                    isUniform: true
                )
            )
            .contentShape(
                ConcentricRectangle(
                    corners: .concentric(minimum: DefaultConstant.concentricRadius),
                    isUniform: true
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("승인 대기 \(viewModel.totalPendingCount)건")
        .accessibilityHint("탭하면 첫 번째 대기 일정으로 이동합니다")
    }

    private var permissionDeniedView: some View {
        ScrollView {
            VStack(spacing: DefaultSpacing.spacing32) {
                ContentUnavailableView {
                    Label(Constants.permissionTitle, systemImage: "lock.fill")
                } description: {
                    Text(Constants.permissionDescription)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
                    Text(Constants.permissionGuideTitle)
                        .appFont(.calloutEmphasis)

                    permissionRoleRow(
                        icon: "building.columns.fill",
                        role: Constants.roleChapterLeader,
                        description: Constants.roleChapterLeaderDescription
                    )

                    permissionRoleRow(
                        icon: "graduationcap.fill",
                        role: Constants.roleSchoolLeader,
                        description: Constants.roleSchoolLeaderDescription
                    )

                    permissionRoleRow(
                        icon: "person.badge.key.fill",
                        role: Constants.roleOperator,
                        description: Constants.roleOperatorDescription
                    )
                }
                .padding(DefaultSpacing.spacing16)
                .background(
                    .regularMaterial,
                    in: .rect(cornerRadius: DefaultConstant.defaultCornerRadius)
                )

                Text(Constants.permissionGuideFooter)
                    .appFont(.footnote)
                    .foregroundStyle(.grey500)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, DefaultSpacing.spacing32)
        }
    }

    private func permissionRoleRow(icon: String, role: String, description: String) -> some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            Image(systemName: icon)
                .font(.app(.title3))
                .foregroundStyle(.grey600)
                .frame(width: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(role)
                    .appFont(.subheadline)
                Text(description)
                    .appFont(.footnote)
                    .foregroundStyle(.grey500)
            }
        }
    }

    @ViewBuilder
    private func listContent(infos: [ScheduleAttendanceInfo]) -> some View {
        ScrollView {
            LazyVStack(spacing: DefaultSpacing.spacing12) {
                ForEach(infos) { info in
                    Button {
                        di.resolve(PathStore.self).activityPath.append(.activity(.attendanceDetail(scheduleId: info.scheduleId)))
                    } label: {
                        AttendanceListRow(info: info)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentMargins(.horizontal, DefaultConstant.defaultSafeHorizon, for: .scrollContent)
    }
}

// MARK: - Row

private struct AttendanceListRow: View, Equatable {

    let info: ScheduleAttendanceInfo

    static func == (lhs: AttendanceListRow, rhs: AttendanceListRow) -> Bool {
        lhs.info.scheduleId == rhs.info.scheduleId
            && lhs.info.totalCount == rhs.info.totalCount
            && lhs.info.presentCount == rhs.info.presentCount
            && lhs.info.pendingCount == rhs.info.pendingCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            HStack(alignment: .firstTextBaseline) {
                Text(info.name)
                    .appFont(.calloutEmphasis, color: .grey700)
                    .lineLimit(1)
                Spacer()
                Text(rateText)
                    .appFont(.footnote, color: .grey500)
            }

            HStack(spacing: DefaultSpacing.spacing8) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundStyle(.grey500)
                Text(dateRangeText)
                    .appFont(.footnote, color: .grey500)
            }

            if let location = info.location {
                HStack(spacing: DefaultSpacing.spacing8) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12))
                        .foregroundStyle(.grey500)
                    Text(location.locationName)
                        .appFont(.footnote, color: .grey500)
                        .lineLimit(1)
                }
            } else if info.isOnline {
                HStack(spacing: DefaultSpacing.spacing8) {
                    Image(systemName: "video")
                        .font(.system(size: 12))
                        .foregroundStyle(.grey500)
                    Text("비대면")
                        .appFont(.footnote, color: .grey500)
                }
            }

            HStack(spacing: DefaultSpacing.spacing8) {
                Text("출석 \(info.presentCount) / \(info.totalCount)")
                    .appFont(.footnote, color: .grey600)
                if info.pendingCount > 0 {
                    InfoBadge(
                        "대기 \(info.pendingCount)",
                        textColor: .orange,
                        tintColor: .yellow,
                        glassVariant: .clear
                    )
                }
            }
        }
        .padding(DefaultSpacing.spacing16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            .regular.interactive(),
            in: ConcentricRectangle(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
        )
    }

    private var rateText: String {
        guard info.totalCount > 0 else { return "—" }
        let percent = Int((info.attendanceRate * 100).rounded())
        return "\(percent)%"
    }

    private var dateRangeText: String {
        guard info.startsAt <= info.endsAt else {
            return AttendanceListRow.kstDetailFormatter.string(from: info.startsAt)
        }
        let start = AttendanceListRow.kstDetailFormatter.string(from: info.startsAt)
        let end = AttendanceListRow.kstHourMinuteFormatter.string(from: info.endsAt)
        return "\(start) ~ \(end)"
    }

    private static let kstDetailFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M월 d일 (E) HH:mm"
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = .kst
        return f
    }()

    private static let kstHourMinuteFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = .kst
        return f
    }()
}

// MARK: - Preview

#if DEBUG
#Preview("출석 현황 - 더미 데이터") {
    AttendanceListPreviewView()
}

/// 더미 출석 현황을 표시하는 프리뷰 래퍼
///
/// 빈 `DIContainer` 에 행 탭 시 필요한 `PathStore` 만 등록하고,
/// `.loaded` 상태가 주입된 ViewModel 을 주입한다.
private struct AttendanceListPreviewView: View {

    private let container: DIContainer
    private let viewModel: AttendanceListViewModel

    init() {
        let container = DIContainer()
        container.register(PathStore.self) { PathStore() }
        self.container = container
        self.viewModel = AttendanceListViewModel.preview(container: container)
    }

    var body: some View {
        NavigationStack {
            AttendanceListView(viewModel: viewModel)
        }
        .environment(\.di, container)
        .environment(ErrorHandler())
    }
}
#endif
