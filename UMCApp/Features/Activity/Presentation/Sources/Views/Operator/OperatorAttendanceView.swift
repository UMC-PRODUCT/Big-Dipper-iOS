//
//  OperatorAttendanceView.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/25/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import SwiftUI
import UMCFoundation

// MARK: - OperatorAttendanceView

/// 운영진 출석 관리 화면 (단일 통합 진입점)
///
/// 출석 현황 목록을 루트로 두고, 행을 탭하면 상세 목적지 push 를 상위에 요청합니다. 상세와
/// 같은 ViewModel 인스턴스를 공유하도록 소유는 탭 루트(``ActivityView``)가 맡습니다.
/// 상태·기간 필터는 우상단 툴바의 단일 메뉴로, 승인 대기 인박스는 상단 배너로 노출합니다.
///
/// - Important: 자체 `NavigationStack` 을 만들지 않습니다. 활동 탭의 스택 안에서 섹션 루트로
///   렌더되는 화면이라, 스택은 상위가 제공합니다(중첩 스택 방지).
/// - Note: 위치 변경 시트는 공용 장소 선택기(`CoreUIComponents.PlaceSelectView`)를 그대로
///   사용합니다 — 별도 주입 seam 없이 시트 안에서 완결됩니다.
struct OperatorAttendanceView: View {

    // MARK: - Property

    @Environment(\.scenePhase) private var scenePhase

    @Bindable private var viewModel: OperatorAttendanceViewModel

    /// "직접 입력" 기간 편집 시트 표시 플래그 (View 전용 일시 상태)
    @State private var isCustomDatePresented: Bool = false

    /// 상세 화면 push 요청 — 목적지 등록을 소유한 탭 루트가 처리한다.
    private let onScheduleSelected: (String) -> Void

    // MARK: - Init

    /// - Parameters:
    ///   - viewModel: 상세와 공유하는 출석 ViewModel (탭 루트 소유)
    ///   - onScheduleSelected: 상세로 이동할 일정 식별자 전달
    init(
        viewModel: OperatorAttendanceViewModel,
        onScheduleSelected: @escaping (String) -> Void
    ) {
        self.viewModel = viewModel
        self.onScheduleSelected = onScheduleSelected
    }

    // MARK: - Body

    var body: some View {
        listStateContent
            .animation(
                .easeInOut(duration: Constants.bannerAnimationDuration),
                value: viewModel.totalPendingCount > 0
            )
            // 상태/기간 필터는 우상단 툴바의 단일 메뉴로 올리고, 상단 safeAreaBar 에는
            // 승인 대기 배너만 고정한다. (권한 거부 시에는 둘 다 숨김)
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
            .navigation(
                naviTitle: NavigationTitle.Activity.attendanceStatus,
                displayMode: .inline
            )
            .sheet(isPresented: $isCustomDatePresented) {
                customDateSheet
                    .presentationDragIndicator(.visible)
            }
            .task {
                // 탭 루트가 VM 을 소유해 섹션을 오갈 때 상태가 남는다. 최초 1회는 스피너 조회,
                // 재진입은 기존 목록을 유지한 채 배경 갱신한다.
                if viewModel.listState.isIdle {
                    await viewModel.fetchList()
                } else {
                    await viewModel.refreshList()
                }
            }
            .task(id: viewModel.listState.isComplete) {
                await viewModel.startListPollingIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await viewModel.refreshList() }
            }
    }

    /// listState 에 따른 본문(목록/로딩/빈/에러/권한). 상단 safeAreaBar 아래 스크롤 영역이다.
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
            if viewModel.isPermissionDenied {
                permissionDeniedView
            } else {
                errorView(error: error)
            }
        }
    }

    // MARK: - Filter Toolbar Menu

    /// 우상단 툴바의 단일 필터 버튼. 버튼 하나 안에서 상태/기간을 각각 중첩 `Menu` 로 제공한다.
    ///
    /// - Note: 라벨이 폭 변화가 없는 고정 아이콘이라, 글래스 칩을 `Menu` 라벨로 쓸 때 생기던
    ///   라벨 폭 변경 클립 문제가 없다. 옵션은 시스템 렌더링(Picker 체크마크)으로 표시된다.
    private var filterMenu: some View {
        Menu {
            Menu {
                Picker("출석 상태", selection: statusFilterBinding) {
                    Label("전체", systemImage: "square.grid.2x2")
                        .tag(nil as ParticipantAttendanceStatus?)
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
        viewModel.selectedListFilter != nil || viewModel.periodPreset != .oneMonth
    }

    private var filterAccessibilityValue: String {
        let status = viewModel.selectedListFilter?.displayText ?? "전체"
        return "상태 \(status), 기간 \(viewModel.periodPreset.label)"
    }

    /// 상태 필터 Picker 바인딩 — 선택 즉시 재조회. nil("전체")은 `clearListFilter` 로 분기한다.
    ///
    /// `listFilterButtonTapped` 는 칩 UI 용 **토글**(같은 값 재선택 시 해제)이라, 이미 선택된
    /// 행을 다시 탭해도 setter 가 불리는 Picker 에 그대로 연결하면 필터가 조용히 풀린다.
    /// 바인딩 단계에서 같은 값 쓰기를 걸러 멱등하게 만든다.
    private var statusFilterBinding: Binding<ParticipantAttendanceStatus?> {
        Binding(
            get: { viewModel.selectedListFilter },
            set: { newValue in
                guard newValue != viewModel.selectedListFilter else { return }
                Task {
                    if let newValue {
                        await viewModel.listFilterButtonTapped(newValue)
                    } else {
                        await viewModel.clearListFilter()
                    }
                }
            }
        )
    }

    /// 기간 프리셋 Picker 바인딩 — 선택 즉시 재조회. "직접 입력" 은 날짜 시트를 띄운다.
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
    @ViewBuilder
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
                        viewModel.toDate = viewModel.fromDate
                            .addingTimeInterval(Constants.oneDayInSeconds)
                    }
                    Task { await viewModel.fetchList() }
                }
                .tint(.indigo500)

                DatePicker(
                    "종료일",
                    selection: $viewModel.toDate,
                    in: viewModel.fromDate...,
                    displayedComponents: .date
                )
                .onChange(of: viewModel.toDate) {
                    Task { await viewModel.fetchList() }
                }
                .tint(.indigo500)
            }
            .navigation(
                naviTitle: NavigationTitle.Activity.attendancePeriod,
                displayMode: .inline
            )
            .toolbar {
                ToolBarCollection.ConfirmBtn(action: {})
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("출석 관리 일정이 아직 없어요", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text("출석이 필요한 일정을 생성하면\n이곳에 출석 현황이 모입니다.")
                .multilineTextAlignment(.center)
        }
    }

    private func errorView(error: AppError) -> some View {
        RetryContentUnavailableView(
            title: "불러오지 못했어요",
            systemImage: "exclamationmark.triangle",
            description: error.userMessage,
            isRetrying: viewModel.listState.isLoading,
            retryAction: { await viewModel.fetchList() }
        )
    }

    // MARK: - Pending Inbox Banner

    private var pendingInboxBanner: some View {
        Button {
            guard let scheduleId = viewModel.firstPendingScheduleId else { return }
            onScheduleSelected(scheduleId)
        } label: {
            HStack(spacing: DefaultSpacing.spacing12) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.app(.body))
                    .foregroundStyle(Color.orange500)

                Text("승인 대기 \(viewModel.totalPendingCount)건")
                    .appFont(.callout, weight: .semibold, color: .grey700)

                Spacer()

                Image(systemName: DefaultConstant.chevronForwardImage)
                    .font(.app(.footnote, weight: .semibold))
                    .foregroundStyle(Color.grey400)
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

    // MARK: - Permission Denied

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
                        .appFont(.callout, weight: .semibold)

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
                    .appFont(.footnote, color: .grey500)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, DefaultSpacing.spacing32)
        }
        .contentMargins(.horizontal, DefaultConstant.defaultSafeHorizon, for: .scrollContent)
    }

    private func permissionRoleRow(
        icon: String,
        role: String,
        description: String
    ) -> some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            Image(systemName: icon)
                .font(.app(.title3))
                .foregroundStyle(Color.grey600)
                .frame(width: Constants.permissionIconWidth, alignment: .center)

            VStack(alignment: .leading, spacing: Constants.permissionRowSpacing) {
                Text(role)
                    .appFont(.subheadline)
                Text(description)
                    .appFont(.footnote, color: .grey500)
            }
        }
    }

    // MARK: - List

    private func listContent(infos: [ScheduleAttendanceInfo]) -> some View {
        ScrollView {
            // 주의: GlassEffectContainer 로 감싸지 않는다. 카드 배경이 `ConcentricRectangle`
            // (적응형 코너)을 쓰는데, 컨테이너 내부에서는 코너 상속이 끊겨 `.interactive()`
            // 글래스의 눌림(liquid) 효과가 카드와 다른 크기로 morphing 된다.
            // → 카드별 glassEffect 를 독립적으로 둔다.
            LazyVStack(spacing: DefaultSpacing.spacing12) {
                ForEach(infos) { info in
                    Button {
                        onScheduleSelected(info.scheduleId)
                    } label: {
                        AttendanceScheduleRow(info: info)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentMargins(.horizontal, DefaultConstant.defaultSafeHorizon, for: .scrollContent)
    }
}

// MARK: - Constants

private enum Constants {
    static let bannerAnimationDuration: TimeInterval = 0.2
    static let oneDayInSeconds: TimeInterval = 24 * 60 * 60
    static let permissionIconWidth: CGFloat = 32
    static let permissionRowSpacing: CGFloat = 2

    static let permissionTitle: String = "접근 권한이 없어요"
    static let permissionDescription: String =
        "운영진 활동 이력이 있는 사용자만\n출석 현황을 조회할 수 있어요"
    static let permissionGuideTitle: String = "출석 관리가 가능한 역할"
    static let roleChapterLeader: String = "지부장"
    static let roleSchoolLeader: String = "학교 대표"
    static let roleOperator: String = "운영진"
    static let roleChapterLeaderDescription: String = "지부 내 전체 학교의 출석을 관리할 수 있어요"
    static let roleSchoolLeaderDescription: String = "소속 학교의 출석을 관리할 수 있어요"
    static let roleOperatorDescription: String = "담당 파트의 출석을 관리할 수 있어요"
    static let permissionGuideFooter: String = "권한이 필요하다면 지부장에게 역할 부여를 요청하세요"
}
