//
//  OperatorAttendanceSectionView.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/23/26.
//

import SwiftUI

/// Admin 모드의 출석 관리 섹션
///
/// 운영진이 출석을 관리하고 승인하는 화면입니다.
/// 세션별 출석 현황을 확인하고, 승인 대기 중인 요청을 처리할 수 있습니다.
struct OperatorAttendanceSectionView: View {

    // MARK: - Property

    @State private var viewModel: OperatorAttendanceViewModel
    @State private var selectedPendingSessionId: UUID?
    @Environment(\.scenePhase) private var scenePhase

    private let container: DIContainer
    private let errorHandler: ErrorHandler

    // MARK: - Init

    init(container: DIContainer, errorHandler: ErrorHandler) {
        self.container = container
        self.errorHandler = errorHandler

        let useCase = container.resolve(ActivityUseCaseProviding.self)
        let attendanceViewModel = OperatorAttendanceViewModel(
            container: container,
            errorHandler: errorHandler,
            useCase: useCase.operatorAttendanceUseCase
        )
        _viewModel = State(initialValue: attendanceViewModel)
    }
    
    private var selectedPendingSession: OperatorSessionAttendance? {
        guard let id = selectedPendingSessionId,
              case .loaded(let sessions) = viewModel.sessionsState
        else { return nil }
        return sessions.first(where: { $0.id == id })
    }

    // MARK: - Constants
    
    private enum Constants {
        static let loadingMessage: String = "출석 관리 데이터를 불러오는 중..."
    }

    // MARK: - Body

    var body: some View {
        content
        .task {
            // 상위 컨테이너에서 한 번만 호출 (View 교체로 인한 Task 취소 방지)
            if viewModel.sessionsState.isIdle {
                await viewModel.fetchSessions()
            }
        }
        .task(id: viewModel.sessionsState.isComplete) {
            guard viewModel.sessionsState.isComplete else { return }
            await viewModel.startPollingIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await viewModel.refreshSessions()
                }
            }
        }
        .alertPrompt(item: $viewModel.alertPrompt)
        .sheet(isPresented: $viewModel.showLocationSheet) {
            OperatorLocationChangeSheetView(
                viewModel: viewModel,
                errorHandler: errorHandler,
            )
        }
        .sheet(isPresented: Binding(
            get: { selectedPendingSessionId != nil },
            set: { if !$0 { selectedPendingSessionId = nil } }
        )) {
            if let session = selectedPendingSession {
                OperatorPendingSheetView(
                    sessionAttendance: session,
                    actions: pendingSheetActions(for: session)
                )
            }
        }
        .onChange(of: viewModel.sessionsState) { _, newState in
            guard let id = selectedPendingSessionId else { return }

            guard case .loaded(let sessions) = newState,
                  let updated = sessions.first(where: {
                      $0.id == id
                  })
            else {
                selectedPendingSessionId = nil
                return
            }

            if updated.pendingMembers.isEmpty {
                selectedPendingSessionId = nil
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.sessionsState {
        case .idle, .loading:
            loadingView

        case .loaded(let sessions):
            if sessions.isEmpty {
                emptyView
            } else {
                ScrollView {
                    sessionListView(sessions: sessions)
                        .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
                }
                .contentMargins(
                    .bottom, DefaultConstant.defaultContentBottomMargins,
                    for: .scrollContent
                )
            }

        case .failed(let error):
            ScrollView {
                errorView(error: error)
                    .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            ProgressView()
                .controlSize(.large)
                .tint(.grey500)

            Text(Constants.loadingMessage)
                .appFont(.subheadline, color: .grey500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        ContentUnavailableView {
            Label("출석 관리", systemImage: "checkmark.circle.badge.questionmark")
        } description: {
            Text("관리할 세션이 없습니다")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }

    // MARK: - Session List View

    private func sessionListView(
        sessions: [OperatorSessionAttendance]) -> some View {
        LazyVStack(spacing: DefaultSpacing.spacing16) {
            ForEach(sessions) { sessionAttendance in
                OperatorSessionCard(
                    sessionAttendance: sessionAttendance,
                    actions: sessionCardActions(for: sessionAttendance)
                )
                .equatable()
            }
        }
        .padding(.top, DefaultSpacing.spacing16)
    }

    // MARK: - Action Factories

    private func pendingSheetActions(
        for session: OperatorSessionAttendance
    ) -> OperatorPendingSheetView.Actions {
        .init(
            onApprove: {
                viewModel.approveButtonTapped(
                    member: $0, sessionId: session.id)
            },
            onReject: {
                viewModel.rejectButtonTapped(
                    member: $0, sessionId: session.id)
            },
            onApproveDirectly: {
                viewModel.approveDirectly(
                    member: $0, sessionId: session.id)
            },
            onRejectDirectly: {
                viewModel.rejectDirectly(
                    member: $0, sessionId: session.id)
            },
            onApproveSelected: {
                viewModel.approveSelectedButtonTapped(
                    members: $0, sessionId: session.id)
            },
            onRejectSelected: {
                viewModel.rejectSelectedButtonTapped(
                    members: $0, sessionId: session.id)
            },
            onApproveAll: {
                viewModel.approveAllButtonTapped(sessionId: session.id)
            },
            onRejectAll: {
                viewModel.rejectAllButtonTapped(sessionId: session.id)
            }
        )
    }

    private func sessionCardActions(
        for sessionAttendance: OperatorSessionAttendance
    ) -> OperatorSessionCard.Actions {
        .init(
            onLocationTap: { viewModel.locationButtonTapped(session: sessionAttendance.session) },
            onPendingListTap: {
                Task {
                    let result = await viewModel.loadPendingMembers(
                        for: sessionAttendance.id
                    )
                    switch result {
                    case .loaded:
                        selectedPendingSessionId = sessionAttendance.id
                    case .empty:
                        viewModel.alertPrompt = AlertPrompt(
                            title: "승인 대기 명단",
                            message: "승인 대기 중인 멤버가 없습니다.",
                            positiveBtnTitle: "확인"
                        )
                    case .failed:
                        break
                    }
                }
            },
            onReasonTap: { viewModel.reasonButtonTapped(member: $0) },
            onRejectTap: { viewModel.rejectButtonTapped(member: $0, sessionId: sessionAttendance.id) },
            onApproveTap: { viewModel.approveButtonTapped(member: $0, sessionId: sessionAttendance.id) }
        )
    }

    // MARK: - Error View

    private func errorView(error: AppError) -> some View {
        RetryContentUnavailableView(
            title: "로딩 실패",
            systemImage: "exclamationmark.triangle",
            description: error.userMessage,
            isRetrying: false,
            topPadding: DefaultSpacing.spacing32
        ) {
            await viewModel.fetchSessions()
        }
    }

}

// MARK: - Preview

#if DEBUG
#Preview {
    OperatorAttendanceSectionView(
        container: AttendancePreviewData.container,
        errorHandler: AttendancePreviewData.errorHandler
    )
}
#endif
