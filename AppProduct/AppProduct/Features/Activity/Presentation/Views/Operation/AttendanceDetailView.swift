//
//  AttendanceDetailView.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import SwiftUI

/// 단일 일정 출석 현황 상세 화면 (Schedule V2 #658)
///
/// `GET /api/v2/schedules/{id}/attendance` 응답을 헤더 + 참여자 리스트로 표시합니다.
/// 진입 경로:
/// - 출석 현황 목록 (`AttendanceListView`) → 행 탭
/// - 일정 상세 화면 → "출석 현황" 버튼 (cross-tab 라우팅 정책 후속, AC-Q1)
struct AttendanceDetailView: View {

    // MARK: - Property

    @Environment(\.di) private var di
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: AttendanceDetailViewModel
    @State private var showPendingSheet: Bool = false

    private let errorHandler: ErrorHandler

    // MARK: - Init

    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        scheduleId: Int
    ) {
        self.errorHandler = errorHandler
        let useCase = container.resolve(ActivityUseCaseProviding.self)
            .operatorAttendanceUseCase
        _viewModel = State(initialValue: AttendanceDetailViewModel(
            container: container,
            errorHandler: errorHandler,
            useCase: useCase,
            scheduleId: scheduleId
        ))
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch viewModel.detailState {
            case .idle, .loading:
                loadingView
            case .loaded(let info):
                content(info: info)
            case .failed(let error):
                errorView(error: error)
            }
        }
        .navigationTitle("출석 현황")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $viewModel.showLocationSheet) {
            OperatorLocationChangeSheetView(
                viewModel: viewModel,
                errorHandler: errorHandler
            )
        }
        .sheet(isPresented: $showPendingSheet) {
            pendingSheet
        }
        .alertPrompt(item: $viewModel.alertPrompt)
        .task {
            if case .idle = viewModel.detailState {
                await viewModel.fetch()
            }
        }
        .task(id: viewModel.detailState.isComplete) {
            await viewModel.startPollingIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.refreshDetail() }
            }
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

    // MARK: - View Components

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func errorView(error: AppError) -> some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            Spacer()
            Image(systemName: viewModel.isScheduleDeleted ? "trash.slash" : "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(viewModel.isScheduleDeleted ? "삭제된 일정입니다" : error.userMessage)
                .appFont(.subheadline, color: .grey600)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DefaultConstant.defaultSafeHorizon)

            if viewModel.isScheduleDeleted {
                Button("이전으로") {
                    di.resolve(PathStore.self).activityPath.removeLast()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("다시 시도") {
                    Task { await viewModel.fetch() }
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(info: ScheduleAttendanceInfo) -> some View {
        ScrollView {
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
                        .appFont(.title3Emphasis, color: .grey700)
                        .lineLimit(2)

                    if !info.description.isEmpty {
                        Text(info.description)
                            .appFont(.subheadline, color: .grey600)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isBeforeStart(info: info) {
                    Button {
                        viewModel.locationButtonTapped()
                    } label: {
                        Label("위치 변경", systemImage: "map.fill")
                            .appFont(.caption1, color: .indigo500)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: DefaultSpacing.spacing8) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundStyle(.grey500)
                Text(dateRangeText(info: info))
                    .appFont(.footnote, color: .grey500)
            }

            if let location = info.location {
                HStack(spacing: DefaultSpacing.spacing8) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12))
                        .foregroundStyle(.grey500)
                    Text(location.locationName)
                        .appFont(.footnote, color: .grey500)
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
            showPendingSheet = true
        } label: {
            HStack(spacing: DefaultSpacing.spacing8) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 14))
                Text("승인 대기 \(count)건")
                    .appFont(.calloutEmphasis)
                Spacer()
                Image(systemName: DefaultConstant.chevronForwardImage)
                    .font(.system(size: 12))
            }
            .foregroundStyle(.orange)
            .padding(DefaultSpacing.spacing12)
            .frame(maxWidth: .infinity)
            .glassEffect(
                .regular.tint(.orange).interactive(),
                in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius))
            )
        }
        .buttonStyle(.plain)
    }

    private func statsRow(info: ScheduleAttendanceInfo) -> some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            statBlock(label: "출석", value: "\(info.presentCount) / \(info.totalCount)")
            statBlock(label: "대기", value: "\(info.pendingCount)")
            statBlock(label: "출석률", value: rateText(info: info))
        }
    }

    private func statBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
            Text(label)
                .appFont(.caption1, color: .grey500)
            Text(value)
                .appFont(.calloutEmphasis, color: .grey700)
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
                ChipButton(
                    "전체",
                    isSelected: viewModel.selectedFilter == nil
                ) {
                    if let current = viewModel.selectedFilter {
                        viewModel.filterButtonTapped(current)
                    }
                }
                .buttonSize(.small)

                ForEach(viewModel.filterableStatuses, id: \.self) { status in
                    ChipButton(
                        status.displayText,
                        isSelected: viewModel.selectedFilter == status
                    ) {
                        viewModel.filterButtonTapped(status)
                    }
                    .buttonSize(.small)
                }
            }
        }
        // 칩 행이 좌우 가장자리까지 자연스럽게 스크롤되도록: 부모 16pt 패딩 상쇄 + 콘텐츠 16pt 인셋.
        .contentMargins(.horizontal, DefaultConstant.defaultSafeHorizon, for: .scrollContent)
        .padding(.horizontal, -DefaultConstant.defaultSafeHorizon)
    }

    @ViewBuilder
    private var participantList: some View {
        let participants = viewModel.filteredParticipants
        if participants.isEmpty {
            VStack(spacing: DefaultSpacing.spacing12) {
                Image(systemName: "person.2.slash")
                    .font(.system(size: 28))
                    .foregroundStyle(.grey400)
                Text("표시할 참여자가 없습니다")
                    .appFont(.subheadline, color: .grey500)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DefaultSpacing.spacing24)
        } else {
            LazyVStack(spacing: DefaultSpacing.spacing8) {
                ForEach(participants) { participant in
                    ParticipantAttendanceRow(
                        participant: participant,
                        isProcessing: viewModel.processingMemberIds.contains(participant.memberId)
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        participantSwipeActions(participant: participant)
                    }
                }
            }
        }
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
            .tint(.green)
            .disabled(isProcessing)

            Button {
                viewModel.rejectButtonTapped(participant: participant)
            } label: {
                Label("거절", systemImage: "xmark")
            }
            .tint(.red)
            .disabled(isProcessing)

            if let reason = participant.excuseReason, !reason.isEmpty {
                Button {
                    viewModel.alertPrompt = AlertPrompt(
                        title: "출석 사유 확인",
                        message: "\(participant.name)님이 작성한 사유입니다.\n\n\"\(reason)\"",
                        positiveBtnTitle: "반려",
                        positiveBtnAction: {
                            viewModel.rejectDirectly(participant: participant)
                        },
                        secondaryBtnTitle: "승인",
                        secondaryBtnAction: {
                            viewModel.approveDirectly(participant: participant)
                        },
                        negativeBtnTitle: "닫기",
                        isPositiveBtnDestructive: true
                    )
                } label: {
                    Label("사유", systemImage: "text.bubble")
                }
                .tint(.orange)
            }
        }
    }

    // MARK: - Pending Sheet

    @ViewBuilder
    private var pendingSheet: some View {
        if case .loaded(let info) = viewModel.detailState {
            PendingApprovalSheetView(
                participants: info.participants.filter(\.attendanceStatus.isPending),
                processingMemberIds: viewModel.processingMemberIds,
                onApprove: { viewModel.approveButtonTapped(participant: $0) },
                onReject: { viewModel.rejectButtonTapped(participant: $0) },
                onApproveDirectly: { viewModel.approveDirectly(participant: $0) },
                onRejectDirectly: { viewModel.rejectDirectly(participant: $0) },
                onApproveSelected: { viewModel.approveSelectedButtonTapped(participants: $0) },
                onRejectSelected: { viewModel.rejectSelectedButtonTapped(participants: $0) },
                onApproveAll: { viewModel.approveAllButtonTapped() },
                onRejectAll: { viewModel.rejectAllButtonTapped() }
            )
        }
    }

    // MARK: - Helper

    private var pendingCount: Int {
        guard case .loaded(let info) = viewModel.detailState else { return 0 }
        return info.pendingCount
    }

    private func isBeforeStart(info: ScheduleAttendanceInfo) -> Bool {
        Date() < info.startsAt
    }

    private func dateRangeText(info: ScheduleAttendanceInfo) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.M.d (E) HH:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        let start = formatter.string(from: info.startsAt)

        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "HH:mm"
        endFormatter.locale = Locale(identifier: "ko_KR")
        endFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        let end = endFormatter.string(from: info.endsAt)
        return "\(start) ~ \(end)"
    }

    private func rateText(info: ScheduleAttendanceInfo) -> String {
        guard info.totalCount > 0 else { return "—" }
        let percent = Int((info.attendanceRate * 100).rounded())
        return "\(percent)%"
    }
}

// MARK: - ParticipantAttendanceRow

private struct ParticipantAttendanceRow: View, Equatable {

    let participant: ParticipantAttendance
    let isProcessing: Bool

    static func == (lhs: ParticipantAttendanceRow, rhs: ParticipantAttendanceRow) -> Bool {
        lhs.participant.memberId == rhs.participant.memberId
            && lhs.participant.attendanceStatus == rhs.participant.attendanceStatus
            && lhs.participant.isLocationVerified == rhs.participant.isLocationVerified
            && lhs.participant.excuseReason == rhs.participant.excuseReason
            && lhs.isProcessing == rhs.isProcessing
    }

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            avatar

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                HStack(spacing: DefaultSpacing.spacing8) {
                    Text(participant.name)
                        .appFont(.calloutEmphasis, color: .grey700)
                        .lineLimit(1)
                    Text(participant.nickname)
                        .appFont(.footnote, color: .grey500)
                        .lineLimit(1)
                }
                HStack(spacing: DefaultSpacing.spacing8) {
                    Text(participant.schoolName)
                        .appFont(.caption1, color: .grey500)
                        .lineLimit(1)

                    if participant.isLocationVerified {
                        HStack(spacing: 2) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                            Text("GPS 인증")
                                .appFont(.caption2, color: .green)
                        }
                        .foregroundStyle(.green)
                    }
                }

                if let reason = participant.excuseReason {
                    Text("사유: \(reason)")
                        .appFont(.caption1, color: .grey600)
                        .lineLimit(2)
                }
            }

            Spacer()

            if isProcessing {
                ProgressView()
                    .frame(width: 32, height: 32)
            } else {
                AttendanceStatusBadge(status: participant.attendanceStatus)
            }
        }
        .padding(DefaultSpacing.spacing12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            .regular,
            in: ConcentricRectangle(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
        )
    }

    private var avatar: some View {
        RemoteImage(
            urlString: participant.profileImageUrl,
            size: CGSize(width: 40, height: 40),
            cornerRadius: 20
        )
    }
}

// MARK: - PendingApprovalSheetView

private struct PendingApprovalSheetView: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss
    @State private var isSelecting: Bool = false
    @State private var selectedMemberIds: Set<Int> = []
    @State private var localAlertPrompt: AlertPrompt?

    let participants: [ParticipantAttendance]
    let processingMemberIds: Set<Int>
    let onApprove: (ParticipantAttendance) -> Void
    let onReject: (ParticipantAttendance) -> Void
    let onApproveDirectly: (ParticipantAttendance) -> Void
    let onRejectDirectly: (ParticipantAttendance) -> Void
    let onApproveSelected: ([ParticipantAttendance]) -> Void
    let onRejectSelected: ([ParticipantAttendance]) -> Void
    let onApproveAll: () -> Void
    let onRejectAll: () -> Void

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if participants.isEmpty {
                    ContentUnavailableView(
                        "승인 대기 멤버 없음",
                        systemImage: "person.crop.circle.badge.checkmark",
                        description: Text("현재 승인 대기 중인 멤버가 없습니다.")
                    )
                } else {
                    List {
                        ForEach(participants) { participant in
                            pendingRow(participant: participant)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    pendingRowSwipeActions(participant: participant)
                                }
                        }
                    }
                    .listRowSpacing(DefaultSpacing.spacing12)
                }
            }
            .navigationTitle("승인 대기 명단")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium, .large])
            .toolbar {
                ToolBarCollection.CancelBtn { dismiss() }

                ToolBarCollection.OperationApprovalMenu(
                    isSelecting: $isSelecting,
                    selectedCount: selectedMemberIds.count,
                    onApproveSelected: {
                        let selected = participants.filter { selectedMemberIds.contains($0.memberId) }
                        onApproveSelected(selected)
                        selectedMemberIds.removeAll()
                        dismiss()
                    },
                    onRejectSelected: {
                        let selected = participants.filter { selectedMemberIds.contains($0.memberId) }
                        onRejectSelected(selected)
                        selectedMemberIds.removeAll()
                        dismiss()
                    },
                    onApproveAll: {
                        onApproveAll()
                        dismiss()
                    },
                    onRejectAll: {
                        onRejectAll()
                        dismiss()
                    }
                )
            }
            .onChange(of: isSelecting) { _, newValue in
                if !newValue { selectedMemberIds.removeAll() }
            }
        }
        .alertPrompt(item: $localAlertPrompt)
    }

    // MARK: - Row

    private func pendingRow(participant: ParticipantAttendance) -> some View {
        HStack(spacing: DefaultSpacing.spacing16) {
            if isSelecting {
                Button {
                    toggleSelection(for: participant.memberId)
                } label: {
                    Image(
                        systemName: selectedMemberIds.contains(participant.memberId)
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                    .font(.system(size: 22))
                    .foregroundStyle(
                        selectedMemberIds.contains(participant.memberId) ? .indigo500 : .grey400
                    )
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            RemoteImage(
                urlString: participant.profileImageUrl,
                size: CGSize(width: DefaultConstant.iconSize, height: DefaultConstant.iconSize),
                cornerRadius: 0,
                placeholderImage: "person.fill"
            )

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                let displayName = participant.nickname.isEmpty
                    ? participant.name
                    : "\(participant.nickname)/\(participant.name)"
                Text(displayName)
                    .appFont(.calloutEmphasis, color: .black)
                Text(participant.schoolName)
                    .appFont(.footnote, color: .grey600)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.snappy(duration: DefaultConstant.animationTime), value: isSelecting)
    }

    @ViewBuilder
    private func pendingRowSwipeActions(participant: ParticipantAttendance) -> some View {
        let isProcessing = processingMemberIds.contains(participant.memberId)

        Button {
            onApprove(participant)
        } label: {
            Label("승인", systemImage: "checkmark")
        }
        .tint(.green)
        .disabled(isProcessing)

        Button {
            onReject(participant)
        } label: {
            Label("거절", systemImage: "xmark")
        }
        .tint(.red)
        .disabled(isProcessing)

        if let reason = participant.excuseReason, !reason.isEmpty {
            let displayName = participant.nickname.isEmpty
                ? participant.name
                : "\(participant.nickname)/\(participant.name)"
            Button {
                localAlertPrompt = AlertPrompt(
                    title: "출석 사유 확인",
                    message: "\(displayName)님이 작성한 사유입니다.\n\n\"\(reason)\"",
                    positiveBtnTitle: "반려",
                    positiveBtnAction: { onRejectDirectly(participant) },
                    secondaryBtnTitle: "승인",
                    secondaryBtnAction: { onApproveDirectly(participant) },
                    negativeBtnTitle: "닫기",
                    isPositiveBtnDestructive: true
                )
            } label: {
                Label("사유", systemImage: "text.bubble")
            }
            .tint(.orange)
        }
    }

    // MARK: - Helper

    private func toggleSelection(for memberId: Int) {
        if selectedMemberIds.contains(memberId) {
            selectedMemberIds.remove(memberId)
        } else {
            selectedMemberIds.insert(memberId)
        }
    }
}
