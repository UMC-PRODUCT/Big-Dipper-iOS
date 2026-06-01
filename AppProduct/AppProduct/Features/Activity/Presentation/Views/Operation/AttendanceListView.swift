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

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
            // 필터 칩·기간 필터·승인 대기 배너는 권한 보유자에게만 노출 (권한 거부 시 폴백 안내만 표시)
            if !viewModel.isPermissionDenied {
                filterChipRow

                if viewModel.isFilterExpanded {
                    periodFilterExpandedRow
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if viewModel.totalPendingCount > 0 {
                    pendingInboxBanner
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

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
        .animation(.easeInOut(duration: 0.2), value: viewModel.isFilterExpanded)
        .animation(.easeInOut(duration: 0.2), value: viewModel.totalPendingCount > 0)
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .padding(.top, DefaultConstant.defaultSafeTop)
        .navigationTitle("출석 현황")
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - View Components

    private var filterChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DefaultSpacing.spacing8) {
                ChipButton(
                    "전체",
                    isSelected: viewModel.selectedFilter == nil
                ) {
                    Task { await viewModel.filterButtonTapped(viewModel.selectedFilter ?? .present) }
                }
                .buttonSize(.small)

                ForEach(viewModel.filterableStatuses, id: \.self) { status in
                    ChipButton(
                        status.displayText,
                        isSelected: viewModel.selectedFilter == status
                    ) {
                        Task { await viewModel.filterButtonTapped(status) }
                    }
                    .buttonSize(.small)
                    .accessibilityAddTraits(viewModel.selectedFilter == status ? .isSelected : [])
                }

                periodFilterToggleButton
            }
        }
    }

    private var periodFilterToggleButton: some View {
        ChipButton(
            viewModel.periodPreset.label,
            isSelected: viewModel.isFilterExpanded,
            trailingIcon: true,
            action: { viewModel.isFilterExpanded.toggle() }
        )
        .buttonSize(.small)
        .accessibilityLabel("기간 필터")
        .accessibilityHint(viewModel.isFilterExpanded ? "필터 접기" : "필터 펼치기")
    }

    private var periodFilterExpandedRow: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DefaultSpacing.spacing8) {
                    ForEach(AttendancePeriodPreset.allCases) { preset in
                        ChipButton(
                            preset.label,
                            isSelected: viewModel.periodPreset == preset
                        ) {
                            Task { await viewModel.presetSelected(preset) }
                        }
                        .buttonSize(.small)
                        .accessibilityAddTraits(viewModel.periodPreset == preset ? .isSelected : [])
                    }
                }
            }

            if viewModel.periodPreset == .custom {
                customDatePickerRow
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.2), value: viewModel.periodPreset == .custom)
            }
        }
    }

    private var customDatePickerRow: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            DatePicker(
                "시작",
                selection: $viewModel.fromDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .font(.app(.footnote))
            .onChange(of: viewModel.fromDate) {
                if viewModel.toDate < viewModel.fromDate {
                    viewModel.toDate = viewModel.fromDate.addingTimeInterval(24 * 60 * 60)
                }
                Task { await viewModel.fetch() }
            }

            DatePicker(
                "종료",
                selection: $viewModel.toDate,
                in: viewModel.fromDate...,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .font(.app(.footnote))
            .onChange(of: viewModel.toDate) {
                Task { await viewModel.fetch() }
            }
        }
        .padding(.horizontal, DefaultSpacing.spacing4)
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
                .regular.interactive(),
                in: ConcentricRectangle(
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
