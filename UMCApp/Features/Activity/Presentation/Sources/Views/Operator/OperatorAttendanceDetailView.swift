//
//  OperatorAttendanceDetailView.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/25/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import SwiftUI
import UMCFoundation

// MARK: - OperatorAttendanceDetailView

/// 단일 일정 출석 현황 상세 화면
///
/// 헤더(일정 정보 + 승인 대기 배너) · 통계 · 상태 필터 칩 · 참여자 목록으로 구성되며,
/// 승인/반려는 스와이프 액션과 승인 대기 시트에서 처리합니다.
/// 목록 화면(``OperatorAttendanceView``)과 **같은 ViewModel 인스턴스**를 공유해
/// 결정 결과가 목록 배지에도 즉시 반영됩니다.
struct OperatorAttendanceDetailView: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @Bindable private var viewModel: OperatorAttendanceViewModel

    /// 진입 대상 일정 (목록에서 push 된 값 — 화면 진입 시 ViewModel 선택으로 연결)
    private let scheduleId: String

    @State private var isPendingSheetPresented: Bool = false

    /// 위치 변경 대상 — 버튼 탭 시점의 일정 정보를 스냅샷으로 캡처한다.
    ///
    /// 시트가 떠 있는 동안 배경 갱신으로 `detailState` 가 바뀌어도(예: 일정 삭제 감지)
    /// 시트 내용이 비지 않도록, 상태를 다시 읽지 않고 캡처본을 쓴다.
    @State private var locationChangeTarget: LocationChangeTarget?

    // MARK: - Init

    init(viewModel: OperatorAttendanceViewModel, scheduleId: String) {
        self.viewModel = viewModel
        self.scheduleId = scheduleId
    }

    // MARK: - Body

    var body: some View {
        stateContent
            .navigation(
                naviTitle: NavigationTitle.Activity.attendanceStatus,
                displayMode: .inline
            )
            .toolbar { toolbarContent }
            .sheet(item: $locationChangeTarget) { locationChangeSheet(target: $0) }
            .sheet(isPresented: $isPendingSheetPresented) { pendingSheet }
            .alertPrompt(item: $viewModel.alertPrompt)
            .task {
                await viewModel.selectSchedule(scheduleId)
            }
            .task(id: viewModel.detailState.isComplete) {
                await viewModel.startDetailPollingIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task { await viewModel.refreshDetail() }
            }
    }

    /// detailState 에 따른 본문(로딩/상세/실패·삭제).
    ///
    /// ViewModel 을 목록과 공유하므로 push 직후 `.task` 의 ``selectSchedule(_:)`` 가 돌기 전까지
    /// 이전 일정의 `detailState` 가 남아 있다. 대상이 일치할 때만 본문을 그려 다른 일정 화면이
    /// 한 프레임 스쳐 보이는 것을 막는다.
    @ViewBuilder
    private var stateContent: some View {
        if viewModel.selectedScheduleId != scheduleId {
            loadingView
        } else {
            loadedStateContent
        }
    }

    @ViewBuilder
    private var loadedStateContent: some View {
        switch viewModel.detailState {
        case .idle, .loading:
            loadingView
        case .loaded(let info):
            content(info: info)
        case .failed(let error):
            errorView(error: error)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    viewModel.approveAllButtonTapped()
                } label: {
                    Label("전체 승인", systemImage: "checkmark.circle")
                }

                Button(role: .destructive) {
                    viewModel.rejectAllButtonTapped()
                } label: {
                    Label("전체 거절", systemImage: "xmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .disabled(pendingCount == 0)
        }
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 실패 상태. 진입 후 일정이 삭제된 경우(SCHEDULE-0009)는 재시도해도 복구되지 않으므로
    /// 재시도 대신 뒤로 가기를 제공한다.
    @ViewBuilder
    private func errorView(error: AppError) -> some View {
        if viewModel.isScheduleDeleted {
            ContentUnavailableView {
                Label("삭제된 일정입니다", systemImage: "trash.slash")
            } description: {
                Text("이 일정이 삭제되어 출석 현황을 볼 수 없어요.")
                    .multilineTextAlignment(.center)
            } actions: {
                Button("이전으로") { dismiss() }
                    .buttonStyle(.glassProminent)
            }
        } else {
            RetryContentUnavailableView(
                title: "불러오지 못했어요",
                systemImage: "exclamationmark.triangle",
                description: error.userMessage,
                isRetrying: viewModel.detailState.isLoading,
                retryAction: { await viewModel.fetchDetail() }
            )
        }
    }

    // MARK: - Content

    private func content(info: ScheduleAttendanceInfo) -> some View {
        ScrollView {
            // 주의: GlassEffectContainer 로 감싸지 않는다. 헤더/스탯/참여자 카드가
            // `ConcentricRectangle`(적응형 코너)을 쓰는데, 컨테이너 내부에서는 코너 상속이
            // 끊겨 `.interactive()` 글래스(승인 대기 배너)의 눌림 효과가 카드와 다른 크기로
            // morphing 된다.
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
                headerCard(info: info)
                statsRow(info: info)
                filterChipRow
                participantList
            }
            .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
            .padding(.top, DefaultConstant.defaultSafeTop)
            .padding(.bottom, DefaultConstant.defaultSafeBottom)
        }
    }

    private func headerCard(info: ScheduleAttendanceInfo) -> some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                    Text(info.name)
                        .appFont(.title3, weight: .semibold, color: .grey700)
                        .lineLimit(2)

                    if !info.description.isEmpty {
                        Text(info.description)
                            .appFont(.subheadline, color: .grey600)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isBeforeStart(info: info) {
                    Button {
                        locationChangeTarget = LocationChangeTarget(info: info)
                    } label: {
                        Label("위치 변경", systemImage: "map.fill")
                            .appFont(.caption1, color: .indigo500)
                            // 라벨을 프레임 상단에 고정해 제목과의 정렬을 유지한 채
                            // 히트 영역만 아래로 넓힌다.
                            .frame(
                                minWidth: DefaultConstant.minimumTouchTarget,
                                minHeight: DefaultConstant.minimumTouchTarget,
                                alignment: .top
                            )
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }

            AttendanceMetaLabel(systemImage: "calendar") {
                Text(
                    AttendanceScheduleFormatter.dateRangeText(
                        from: info.startsAt,
                        to: info.endsAt,
                        style: .detail
                    )
                )
                .appFont(.footnote, color: .grey500)
            }

            if let location = info.location {
                AttendanceMetaLabel(systemImage: "mappin.and.ellipse") {
                    Text(location.locationName)
                        .appFont(.footnote, color: .grey500)
                }
            } else if info.isOnline {
                AttendanceMetaLabel(systemImage: "video") {
                    Text("비대면")
                        .appFont(.footnote, color: .grey500)
                }
            }

            if info.pendingCount > 0 {
                pendingBanner(count: info.pendingCount)
            }
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
    }

    private func pendingBanner(count: Int) -> some View {
        Button {
            isPendingSheetPresented = true
        } label: {
            HStack(spacing: DefaultSpacing.spacing8) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.app(.subheadline, weight: .semibold))
                    .foregroundStyle(Color.orange600)

                Text("승인 대기 \(count)건")
                    .appFont(.callout, weight: .semibold, color: .orange700)

                Spacer()

                Image(systemName: DefaultConstant.chevronForwardImage)
                    .font(.app(.caption1, weight: .semibold))
                    .foregroundStyle(Color.orange400)
            }
            .padding(DefaultSpacing.spacing12)
            .frame(maxWidth: .infinity)
            .glassEffect(
                .regular.tint(Color.orange500.opacity(Constants.bannerTintOpacity)).interactive(),
                in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius))
            )
        }
        .buttonStyle(.plain)
    }

    private func statsRow(info: ScheduleAttendanceInfo) -> some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            statBlock(
                icon: "person.fill.checkmark",
                tint: .indigo500,
                label: "출석",
                value: "\(info.presentCount) / \(info.totalCount)",
                valueColor: .grey700
            )
            statBlock(
                icon: "clock.badge",
                tint: .orange500,
                label: "대기",
                value: "\(info.pendingCount)",
                valueColor: info.pendingCount > 0 ? .orange600 : .grey400
            )
            statBlock(
                icon: "chart.pie.fill",
                tint: .indigo500,
                label: "출석률",
                value: AttendanceScheduleFormatter.attendanceRateText(
                    rate: info.attendanceRate,
                    totalCount: info.totalCount
                ),
                valueColor: .indigo600
            )
        }
    }

    private func statBlock(
        icon: String,
        tint: Color,
        label: String,
        value: String,
        valueColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            HStack(spacing: DefaultSpacing.spacing4) {
                Image(systemName: icon)
                    .font(.app(.caption1, weight: .semibold))
                    .foregroundStyle(tint)
                Text(label)
                    .appFont(.caption1, color: .grey500)
            }

            Text(value)
                .appFont(.title3, weight: .semibold, color: valueColor)
                .lineLimit(1)
                .minimumScaleFactor(Constants.statValueMinimumScale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DefaultSpacing.spacing12)
        .glassEffect(
            .regular,
            in: ConcentricRectangle(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
        )
    }

    private var filterChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DefaultSpacing.spacing8) {
                ChipButton("전체", isSelected: viewModel.selectedDetailFilter == nil) {
                    if let current = viewModel.selectedDetailFilter {
                        viewModel.detailFilterButtonTapped(current)
                    }
                }
                .buttonSize(.small)

                ForEach(viewModel.filterableStatuses, id: \.self) { status in
                    ChipButton(
                        status.displayText,
                        isSelected: viewModel.selectedDetailFilter == status
                    ) {
                        viewModel.detailFilterButtonTapped(status)
                    }
                    .buttonSize(.small)
                }
            }
        }
        // 칩 행이 좌우 가장자리까지 스크롤되도록: 부모 패딩 상쇄 + 콘텐츠 인셋.
        .contentMargins(.horizontal, DefaultConstant.defaultSafeHorizon, for: .scrollContent)
        .padding(.horizontal, -DefaultConstant.defaultSafeHorizon)
    }

    @ViewBuilder
    private var participantList: some View {
        let participants = viewModel.filteredParticipants
        if participants.isEmpty {
            emptyParticipantView
        } else {
            // List 대신 LazyVStack 을 쓰는 이유:
            // (1) 행이 glassEffect 를 쓰는데 List 는 GlassEffectContainer 와 호환되지 않는다.
            // (2) ScrollView 안에 List 를 중첩하면 높이가 0으로 접혀 레이아웃이 깨진다.
            // LazyVStack 행의 swipeActions 는 셀별로 제스처 상태를 관리해 List 와 동일하게 동작한다.
            LazyVStack(spacing: DefaultSpacing.spacing8) {
                ForEach(participants) { participant in
                    ParticipantAttendanceRow(
                        participant: participant,
                        isProcessing: viewModel.processingMemberIds.contains(participant.memberId)
                    )
                    .equatable()
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        participantSwipeActions(participant: participant)
                    }
                }
            }
        }
    }

    private var emptyParticipantView: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            Image(systemName: "person.2.slash")
                .font(.app(.title1))
                .foregroundStyle(Color.grey400)
            Text("표시할 참여자가 없습니다")
                .appFont(.subheadline, color: .grey500)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DefaultSpacing.spacing24)
    }

    @ViewBuilder
    private func participantSwipeActions(participant: ParticipantAttendance) -> some View {
        if participant.attendanceStatus.isPending {
            let isProcessing = viewModel.processingMemberIds.contains(participant.memberId)

            Button {
                viewModel.approveButtonTapped(participant: participant)
            } label: {
                Label("승인", systemImage: "checkmark")
            }
            .tint(Color.green500)
            .disabled(isProcessing)

            Button {
                viewModel.rejectButtonTapped(participant: participant)
            } label: {
                Label("거절", systemImage: "xmark")
            }
            .tint(Color.red500)
            .disabled(isProcessing)

            if let reason = participant.excuseReason, !reason.isEmpty {
                Button {
                    viewModel.excuseReasonButtonTapped(participant: participant)
                } label: {
                    Label("사유", systemImage: "text.bubble")
                }
                .tint(Color.orange500)
            }
        }
    }

    // MARK: - Sheets

    /// 승인 대기 시트. 결정 결과가 즉시 반영되도록 상태를 스냅샷하지 않고 계속 읽는다
    /// (대상이 사라지면 시트 자체가 "승인 대기 멤버 없음" 을 표시한다).
    private var pendingSheet: some View {
        PendingApprovalSheet(
            participants: viewModel.detailState.value?
                .participants.filter(\.attendanceStatus.isPending) ?? [],
            processingMemberIds: viewModel.processingMemberIds,
            onDecide: { participant, isApproved in
                Task {
                    await viewModel.decideAttendance(
                        participant: participant,
                        isApproved: isApproved
                    )
                }
            },
            // 확인 Alert 는 시트가 자체적으로 띄우므로, 여기서는 확정 결정 API 를 호출한다
            // (ViewModel 의 `*ButtonTapped` alert 는 시트 뒤 화면에 떠 보이지 않는다).
            onDecideSelected: { participants, isApproved in
                Task {
                    await viewModel.decideSelectedAttendances(
                        participants: participants,
                        isApproved: isApproved
                    )
                }
            },
            onDecideAll: { isApproved in
                Task { await viewModel.decideAllAttendances(isApproved: isApproved) }
            }
        )
    }

    private func locationChangeSheet(target: LocationChangeTarget) -> some View {
        OperatorLocationChangeSheet(
            scheduleName: target.name,
            startsAt: target.startsAt,
            endsAt: target.endsAt,
            onSubmit: { place in
                await viewModel.changeLocation(
                    name: place.name,
                    latitude: place.coordinate.latitude,
                    longitude: place.coordinate.longitude
                )
            }
        )
    }

    // MARK: - Helper

    private var pendingCount: Int {
        guard case .loaded(let info) = viewModel.detailState else { return 0 }
        return info.pendingCount
    }

    private func isBeforeStart(info: ScheduleAttendanceInfo) -> Bool {
        Date() < info.startsAt
    }
}

// MARK: - LocationChangeTarget

/// 위치 변경 시트에 넘길 일정 스냅샷 (버튼 탭 시점 캡처).
///
/// 시트 표시 중 `detailState` 가 바뀌어도 대상 일정 정보가 흔들리지 않도록 값으로 고정한다.
private struct LocationChangeTarget: Identifiable {

    let id: String
    let name: String
    let startsAt: Date
    let endsAt: Date

    init(info: ScheduleAttendanceInfo) {
        self.id = info.scheduleId
        self.name = info.name
        self.startsAt = info.startsAt
        self.endsAt = info.endsAt
    }
}

// MARK: - Constants

private enum Constants {
    static let bannerTintOpacity: Double = 0.16
    static let statValueMinimumScale: CGFloat = 0.8
}
