//
//  ChallengerAttendanceSessionView.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/2/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreDI
import CoreUIComponents
import HomeDomain
import SwiftUI
import UMCFoundation

// MARK: - MapViewModelCache

/// Session별 `BaseMapViewModel` 인스턴스를 캐싱합니다.
///
/// 지도 모델은 지오펜스 모니터링을 소유하므로 body 가 재평가될 때마다 새로 만들면
/// 등록이 반복됩니다. Reference type 으로 두어 body 평가 중 mutation 을 안전하게 처리합니다.
@MainActor
private final class MapViewModelCache {
    private var cache: [Session.ID: BaseMapViewModel] = [:]

    func get(for sessionId: Session.ID) -> BaseMapViewModel? {
        cache[sessionId]
    }

    func set(_ viewModel: BaseMapViewModel, for sessionId: Session.ID) {
        cache[sessionId] = viewModel
    }
}

// MARK: - ChallengerAttendanceSessionView

/// 챌린저 출석 진입 화면
///
/// 출석 가능한 세션 목록과 나의 출석 현황을 한 화면에 세로로 배치합니다.
/// 세션 카드를 탭하면 지도·출석 버튼이 있는 상세가 펼쳐집니다.
struct ChallengerAttendanceSessionView: View {

    // MARK: - Property

    @State private var attendanceViewModel: ChallengerAttendanceViewModel
    @State private var mapViewModelCache = MapViewModelCache()
    @State private var expandedSessionId: Session.ID?

    private let errorHandler: ErrorHandler
    private let sessions: [Session]
    private let schedules: [ScheduleDetailData]
    private let userId: UserID

    // MARK: - Init

    /// - Parameters:
    ///   - container: 출석 UseCase 를 resolve 할 DI 컨테이너
    ///   - errorHandler: 흐름 중단형 전역 에러 처리기
    ///   - sessions: 상위(일정 화면)가 소유한 세션 목록
    ///   - schedules: 세션과 같은 조회에서 나온 일정 원본 (출석 정책·일정 ID 조회용)
    ///   - userId: 출석 주체
    ///   - viewModel: 프리뷰/테스트용 주입 지점 (기본값: container 로 생성)
    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        sessions: [Session],
        schedules: [ScheduleDetailData],
        userId: UserID,
        viewModel: ChallengerAttendanceViewModel? = nil
    ) {
        self.errorHandler = errorHandler
        self.sessions = sessions
        self.schedules = schedules
        self.userId = userId
        _attendanceViewModel = State(
            initialValue: viewModel ?? ChallengerAttendanceViewModel(
                errorHandler: errorHandler,
                challengerAttendanceUseCase: container.resolve(
                    ChallengerAttendanceUseCaseProtocol.self
                )
            )
        )
    }

    // MARK: - Constants

    fileprivate enum Constants {
        static let animationResponse: Double = 0.35
        static let animationDamping: Double = 0.8
        static let emptyStateVerticalPadding: CGFloat = 32
    }

    // MARK: - Computed Properties

    /// 출석 가능한 세션만 필터링 (beforeAttendance, pendingApproval)
    private var availableSessions: [Session] {
        sessions.filter(\.isAttendanceAvailable)
    }

    /// 출석이 확정된 세션만 이력 표시 모델로 변환
    ///
    /// 출석 전(`beforeAttendance`) 세션은 변환되지 않으므로, 빈 상태 판단은 원본 세션
    /// 개수가 아니라 변환 결과 개수로 해야 가이드가 정상 표시됩니다.
    private var attendanceHistoryItems: [MyAttendanceItemModel] {
        sessions.compactMap { session in
            MyAttendanceItemModel(
                from: session,
                category: session.info.category,
                attendancePolicy: attendanceViewModel
                    .attendancePolicy(for: session.info.sessionId)
            )
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: DefaultSpacing.spacing48) {
                attendanceSessionSection
                myAttendanceStatusSection
            }
            .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
            .safeAreaPadding(.bottom, DefaultConstant.defaultSafeBottom)
        }
        .contentMargins(
            .trailing,
            DefaultConstant.defaultContentTrailingMargins,
            for: .scrollContent
        )
        .contentMargins(
            .bottom,
            DefaultConstant.defaultContentBottomMargins,
            for: .scrollContent
        )
        .onChange(of: schedules, initial: true) { _, latest in
            attendanceViewModel.apply(schedules: latest)
        }
        .onDisappear {
            Task { await attendanceViewModel.geofenceCleanup() }
        }
    }

    // MARK: - Attendance Session Section

    @ViewBuilder
    private var attendanceSessionSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
            sectionHeader("출석 가능한 세션")

            // 조회 로딩·실패 UI 는 목록을 소유한 상위(`ActivityView`)가 그린다.
            if availableSessions.isEmpty {
                emptySessionView
            } else {
                ChallengerAttendanceSessionList(
                    sessions: availableSessions,
                    expandedSessionId: expandedSessionId,
                    attendanceViewModel: attendanceViewModel,
                    userId: userId,
                    mapViewModelProvider: mapViewModel(for:)
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
        }
    }

    private var emptySessionView: some View {
        emptyStateCard(
            systemImage: "checkmark.circle.fill",
            tint: .green500,
            title: "모든 세션 출석을 완료했어요",
            description: "지금은 출석할 수 있는 세션이 없어요.\n새로운 세션이 열리면 이곳에 표시됩니다."
        )
    }

    // MARK: - My Attendance Status Section

    @ViewBuilder
    private var myAttendanceStatusSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
            sectionHeader("나의 출석 현황")

            // 이력은 상위가 넘긴 `sessions` 창에서 파생하므로 그 창(출석 가능 일정 조회
            // 구간) 밖의 과거 기록은 보이지 않는다 — 빈 상태 가이드가 뜰 수 있다.
            let items = attendanceHistoryItems
            if items.isEmpty {
                emptyHistoryView
            } else {
                ChallengerMyAttendanceStatusView(models: items)
            }
        }
    }

    private var emptyHistoryView: some View {
        emptyStateCard(
            systemImage: "clock.badge.checkmark",
            tint: .indigo400,
            title: "아직 출석 기록이 없어요",
            description: "출석 가능한 세션에서 출석을 완료하면\n이곳에 나의 출석 현황이 표시됩니다."
        )
    }

    // MARK: - Shared View Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .appFont(.body, weight: .semibold, color: .grey900)
            .padding(.leading, DefaultConstant.sectionLeadingHeader)
    }

    private func emptyStateCard(
        systemImage: String,
        tint: Color,
        title: String,
        description: String
    ) -> some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            // 빈 상태는 전환이 아니라 처음부터 표시되는 화면이므로
            // 전환 효과(symbolDrawOn)는 심볼이 그려지지 않아 정적 렌더로 표시합니다.
            Image(systemName: systemImage)
                .font(.app(.largeTitle))
                .foregroundStyle(tint)

            VStack(spacing: DefaultSpacing.spacing4) {
                Text(title)
                    .appFont(.callout, weight: .semibold, color: .grey700)

                Text(description)
                    .appFont(.footnote, color: .grey500)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Constants.emptyStateVerticalPadding)
        .padding(.horizontal, DefaultSpacing.spacing16)
        .background {
            ConcentricRectangle(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
            .fill(Color.grey000)
            .glass()
        }
    }

    // MARK: - Function

    /// Session별 지도 모델을 캐시에서 가져오거나 새로 생성합니다.
    ///
    /// 지오펜스는 서버 일정 ID 로 등록해야 출석 판정과 같은 대상을 가리킵니다.
    /// 아직 일정 ID 가 해석되지 않았다면 `nil` 을 돌려주고, 상세는 지도 대신
    /// 플레이스홀더를 표시합니다 — `sessionId` 를 대신 넘기면 컴파일은 되지만
    /// 지오펜스가 항상 어긋나 출석이 거부됩니다.
    private func mapViewModel(for session: Session) -> BaseMapViewModel? {
        if let cached = mapViewModelCache.get(for: session.id) {
            return cached
        }

        guard let scheduleId = attendanceViewModel.scheduleId(for: session.info.sessionId) else {
            return nil
        }

        let newViewModel = BaseMapViewModel(
            info: session.info,
            scheduleId: scheduleId,
            errorHandler: errorHandler
        )
        mapViewModelCache.set(newViewModel, for: session.id)
        return newViewModel
    }
}

#if DEBUG
// MARK: - Preview

#Preview("출석 가능 세션 + 이력") {
    ZStack {
        Color.grey100.ignoresSafeArea()

        AttendancePreviewData.sessionScreen(sessions: AttendancePreviewData.mixedSessions)
    }
}

#Preview("모든 세션 완료 (빈 상태)") {
    ZStack {
        Color.grey100.ignoresSafeArea()

        AttendancePreviewData.sessionScreen(sessions: AttendancePreviewData.completedSessions)
    }
}

#Preview("기록 없음 (빈 상태)") {
    ZStack {
        Color.grey100.ignoresSafeArea()

        AttendancePreviewData.sessionScreen(sessions: AttendancePreviewData.upcomingSessions)
    }
}
#endif
