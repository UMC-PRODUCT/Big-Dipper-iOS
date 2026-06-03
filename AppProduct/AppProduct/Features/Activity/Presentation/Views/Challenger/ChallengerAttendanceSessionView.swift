//
//  ChallengerAttendanceSessionView.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/22/26.
//

import SwiftUI

/// Session별 MapViewModel 인스턴스를 캐싱합니다.
///
/// View body 평가 중 Reference type을 통해 mutation을 안전하게 처리합니다.
private final class MapViewModelCache {
    private var cache: [Session.ID: BaseMapViewModel] = [:]

    func get(for sessionId: Session.ID) -> BaseMapViewModel? {
        cache[sessionId]
    }

    func set(_ viewModel: BaseMapViewModel, for sessionId: Session.ID) {
        cache[sessionId] = viewModel
    }
}

struct ChallengerAttendanceSessionView: View {
    @State private var expandedSessionId: Session.ID?
    @Environment(\.scenePhase) private var scenePhase
    @State private var attendanceViewModel: ChallengerAttendanceViewModel
    @State private var mapViewModelCache = MapViewModelCache()

    private let container: DIContainer
    private let errorHandler: ErrorHandler
    private let sessions: [Session]
    private let userId: UserID
    private let categoryFor: (String) -> ScheduleIconCategory

    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        sessions: [Session],
        userId: UserID,
        categoryFor: @escaping (String) -> ScheduleIconCategory
    ) {
        self.container = container
        self.errorHandler = errorHandler
        self.sessions = sessions
        self.userId = userId
        self.categoryFor = categoryFor
        
        let activityProvider = container.resolve(ActivityUseCaseProviding.self)

        let attendanceViewModel = ChallengerAttendanceViewModel(
            container: container,
            errorHandler: errorHandler,
            challengeAttendanceUseCase: activityProvider.challengerAttendanceUseCase
        )
        self._attendanceViewModel = .init(wrappedValue: attendanceViewModel)
    }

    private enum Constants {
        static let animationResponse: Double = 0.35
        static let animationDamping: Double = 0.8
    }

    // MARK: - Computed Properties

    /// 출석 가능한 세션만 필터링 (beforeAttendance, pendingApproval)
    private var availableSessions: [Session] {
        sessions.filter(\.isAttendanceAvailable)
    }

    /// Session별 MapViewModel 캐시에서 가져오거나 새로 생성
    /// - Note: Reference type cache 사용으로 body 평가 중 mutation 안전
    private func mapViewModel(for session: Session) -> BaseMapViewModel {
        if let cached = mapViewModelCache.get(for: session.id) {
            return cached
        }
        let newViewModel = BaseMapViewModel(
            container: container,
            info: session.info,
            errorHandler: errorHandler
        )
        mapViewModelCache.set(newViewModel, for: session.id)
        return newViewModel
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: DefaultSpacing.spacing48) {
                attendanceSessionSection
                
                myAttendanceStatusView
            }
            .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
            .safeAreaPadding(.bottom, DefaultConstant.defaultSafeBottom)
        }
        .contentMargins(
            .trailing,
            DefaultConstant.defaultContentTrailingMargins,
            for: .scrollContent)
        .contentMargins(
            .bottom,
            DefaultConstant.defaultContentBottomMargins,
            for: .scrollContent)
        .task {
            // configurePollingSessions는 반드시 fetch보다 먼저 호출
            // syncSessionStates()가 pollingSessions에 의존
            attendanceViewModel.configurePollingSessions(
                sessions,
                userId: userId
            )
            await attendanceViewModel.fetchAvailableSchedules()
            await attendanceViewModel.fetchMyHistory()
        }
        .task {
            await attendanceViewModel.startPollingIfNeeded(
                sessions: sessions
            )
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await attendanceViewModel.refreshAfterForeground()
                }
            }
        }
        .onDisappear {
            Task {
                await attendanceViewModel.geofenceCleanup()
            }
        }
    }
    
    @ViewBuilder
    private var attendanceSessionSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
            attendanceSectionHeader

            switch attendanceViewModel.availableSchedules {
            case .idle:
                Color.clear

            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DefaultSpacing.spacing32)

            case .loaded:
                if availableSessions.isEmpty {
                    emptySessionView
                } else {
                    ChallengerAttendanceSessionList(
                        container: container,
                        errorHandler: errorHandler,
                        sessions: availableSessions,
                        expandedSessionId: expandedSessionId,
                        attendanceViewModel: attendanceViewModel,
                        userId: userId,
                        mapViewModelProvider: { session in mapViewModel(for: session) }
                    ) { sessionId in
                        withAnimation(.spring(Spring(
                            response: Constants.animationResponse,
                            dampingRatio: Constants.animationDamping
                        ))) {
                            expandedSessionId = expandedSessionId == sessionId ? nil : sessionId
                        }
                    }
                    .equatable()
                }

            case .failed(let error):
                RetryContentUnavailableView(
                    title: "불러오지 못했어요",
                    systemImage: "exclamationmark.triangle",
                    description: error.userMessage,
                    isRetrying: attendanceViewModel.isRetrying
                ) {
                    await attendanceViewModel.fetchAvailableSchedules()
                }
            }
        }
    }

    private var emptySessionView: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: DefaultConstant.iconSize))
                .foregroundStyle(.green.opacity(0.7))
                .symbolDrawOn(isActive: true)

            Text("모든 세션 출석을 완료했습니다")
                .appFont(.body, color: .grey600)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DefaultSpacing.spacing32)
        .background(.white, in: RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius))
        .glass()
    }
    
    private var attendanceSectionHeader: some View {
        Text("출석 가능한 세션")
            .appFont(.bodyEmphasis, color: .black)
            .padding(.leading, DefaultConstant.sectionLeadingHeader)
    }
    
    @ViewBuilder
    private var myAttendanceStatusView: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
            sectionHeader

            switch attendanceViewModel.myHistory {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DefaultSpacing.spacing32)
            case .loaded(let items):
                if items.isEmpty {
                    emptyHistoryView
                } else {
                    ChallengerMyAttendanceStatusView(
                        historyItems: items
                    )
                }
            case .failed(let error):
                RetryContentUnavailableView(
                    title: "불러오지 못했어요",
                    systemImage: "exclamationmark.triangle",
                    description: error.userMessage,
                    isRetrying: attendanceViewModel.isRetrying
                ) {
                    await attendanceViewModel.fetchMyHistory()
                }
            }
        }
    }

    private var emptyHistoryView: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: DefaultConstant.iconSize))
                .foregroundStyle(.indigo400)

            VStack(spacing: DefaultSpacing.spacing4) {
                Text("아직 출석 기록이 없어요")
                    .appFont(.calloutEmphasis, color: .grey700)

                Text("출석 가능한 세션에서 출석을 완료하면\n이곳에 나의 출석 현황이 표시됩니다.")
                    .appFont(.footnote, color: .grey500)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DefaultSpacing.spacing32)
        .padding(.horizontal, DefaultSpacing.spacing16)
        .background(
            .white,
            in: RoundedRectangle(
                cornerRadius: DefaultConstant.defaultCornerRadius
            )
        )
        .glass()
    }
    
    private var sectionHeader: some View {
        Text("나의 출석 현황")
            .appFont(.bodyEmphasis, color: .black)
            .padding(.leading, DefaultConstant.sectionLeadingHeader)
    }
}

#if DEBUG
#Preview("기본 (필터링 적용)") {
    ZStack {
        Color.grey100.ignoresSafeArea()

        ChallengerAttendanceSessionView(
            container: AttendancePreviewData.container,
            errorHandler: AttendancePreviewData.errorHandler,
            sessions: AttendancePreviewData.sessions,
            userId: AttendancePreviewData.userId,
            categoryFor: { _ in .general }
        )
    }
}

#Preview("출석 가능 세션 여러 개") {
    ZStack {
        Color.grey100.ignoresSafeArea()

        ChallengerAttendanceSessionView(
            container: AttendancePreviewData.container,
            errorHandler: AttendancePreviewData.errorHandler,
            sessions: AttendancePreviewData.multipleAvailableSessions,
            userId: AttendancePreviewData.userId,
            categoryFor: { _ in .general }
        )
    }
}

#Preview("모든 세션 완료 (Empty State)") {
    ZStack {
        Color.grey100.ignoresSafeArea()

        // 모든 세션이 완료된 상태
        ChallengerAttendanceSessionView(
            container: AttendancePreviewData.container,
            errorHandler: AttendancePreviewData.errorHandler,
            sessions: Array(AttendancePreviewData.sessions.prefix(5)), // beforeAttendance 제외
            userId: AttendancePreviewData.userId,
            categoryFor: { _ in .general }
        )
    }
}
#endif
