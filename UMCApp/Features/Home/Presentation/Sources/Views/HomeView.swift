//
//  HomeView.swift
//  HomePresentation
//
//  Created by euijjang97 on 7/9/26.
//

import CoreDesignSystem
import CoreDI
import CoreDomain
import CoreRouting
import CoreUIComponents
import HomeDomain
import NoticeDomain
import StoreKit
import SwiftUI
import UMCFoundation

/// 홈 대시보드 메인 화면.
///
/// 슬라이스 1(#913) 범위: 진입 시 프로필을 로드해 시즌 카드와 세대별 상벌점 카드를 표시한다.
/// 슬라이스 2(#914) 범위: 이번 달 일정 캘린더와 선택 날짜의 일정 리스트를 표시한다.
/// 슬라이스 3(#915) 범위: 최신 기수의 최근 공지 5건을 표시하고, 탭 시 상세 화면으로 이동한다.
/// 슬라이스 4(#982) 범위: 툴바(로고/알림 보관함)와 일정 카드 → 일정 상세 진입, 상벌점 변경
/// 알림 수신 시 프로필 재조회, 4주 간격 앱스토어 리뷰 요청을 복구한다.
/// `NavigationStack`은 루트 탭 셸이 소유하므로 이 뷰는 콘텐츠만 구성한다.
struct HomeView: View {

    // MARK: - Property

    @Environment(\.requestReview) private var requestReview
    /// 홈 탭 스택의 공유 경로. 루트 복귀 감지에만 쓰므로, 경로 저장소를 주입하지 않는
    /// 프리뷰/테스트 호출부가 깨지지 않도록 옵셔널로 받는다.
    @Environment(PathStore.self) private var pathStore: PathStore?
    @State private var viewModel: HomeViewModel
    @State private var selectedDate: Date = .now
    @State private var currentMonth: Date = .now
    @State private var isRetryingProfile = false
    @State private var isRetryingRecentNotice = false
    private let onNoticeSelected: (NoticeDetail) -> Void
    private let onScheduleSelected: (String) -> Void
    private let onAlarmHistoryTapped: () -> Void
    private let onScheduleRegistrationTapped: () -> Void
    private let reviewRequestPolicy: ReviewRequestPolicy

    // MARK: - Constants

    fileprivate enum Constants {
        static let schedulePlaceholderHeight: CGFloat = 120
    }

    // MARK: - Init

    /// - Parameters:
    ///   - container: UseCase를 resolve할 DI 컨테이너
    ///   - viewModel: 프리뷰/테스트용 주입 지점 (기본값: container로 생성)
    ///   - onNoticeSelected: 최근 공지 카드 탭 시 상세 화면 이동을 위임하는 콜백
    ///   - onScheduleSelected: 일정 카드 탭 시 일정 상세 이동을 위임하는 콜백
    ///   - onAlarmHistoryTapped: 툴바 알림 버튼 탭 시 알림 보관함 이동을 위임하는 콜백
    ///   - onScheduleRegistrationTapped: 툴바 일정 등록 버튼 탭 시 등록 화면 이동을 위임하는 콜백
    ///   - reviewRequestPolicy: 리뷰 요청 간격 정책 (프리뷰/테스트용 주입 지점)
    init(
        container: DIContainer,
        viewModel: HomeViewModel? = nil,
        onNoticeSelected: @escaping (NoticeDetail) -> Void = { _ in },
        onScheduleSelected: @escaping (String) -> Void = { _ in },
        onAlarmHistoryTapped: @escaping () -> Void = {},
        onScheduleRegistrationTapped: @escaping () -> Void = {},
        reviewRequestPolicy: ReviewRequestPolicy = ReviewRequestPolicy()
    ) {
        _viewModel = State(initialValue: viewModel ?? HomeViewModel(container: container))
        self.onNoticeSelected = onNoticeSelected
        self.onScheduleSelected = onScheduleSelected
        self.onAlarmHistoryTapped = onAlarmHistoryTapped
        self.onScheduleRegistrationTapped = onScheduleRegistrationTapped
        self.reviewRequestPolicy = reviewRequestPolicy
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: DefaultSpacing.spacing24) {
                seasonSection
                generationSection
                scheduleSection
                recentNoticeSection
            }
            .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
        }
        .contentMargins(.bottom, DefaultConstant.defaultContentBottomMargins, for: .scrollContent)
        .refreshable {
            await viewModel.fetchProfile(forceRefresh: true)
        }
        .umcDefaultBackground()
        .toolbar {
            ToolBarCollection.Logo()
            // ponytail: 임시 진입점 — 하단 탭 액세서리(#1057) 결선 후 제거.
            ToolBarCollection.AddBtn(action: onScheduleRegistrationTapped)
            ToolBarCollection.BellBtn(action: onAlarmHistoryTapped)
        }
        .task {
            await viewModel.fetchProfileIfNeeded()
            requestReviewIfDue()
        }
        // 최초 진입(depth 0)과 홈 루트 복귀를 한 트리거로 처리한다. 별도 `.task`를 두면
        // 최초 진입에서 같은 달을 두 번 조회하게 된다.
        .task(id: pathStore?.depth(of: .home) ?? 0) {
            guard pathStore?.isAtRoot(.home) ?? true else { return }
            await fetchSchedules(of: currentMonth)
        }
        .onChange(of: currentMonth) { _, newMonth in
            Task { await fetchSchedules(of: newMonth) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .memberPenaltyUpdated)) { _ in
            // 상벌점이 방금 변경됐으므로 세션 프로필 캐시를 우회해 서버 최신값으로 갱신한다.
            Task { await viewModel.fetchProfile(forceRefresh: true) }
        }
    }

    // MARK: - Season Section

    /// 시즌 카드(소속 기수/누적 활동일) 섹션.
    ///
    /// 프로필 단일 호출이 시즌/세대 상태를 함께 채우므로, 실패 안내와 재시도는
    /// 이 섹션에서 한 번만 표시한다 (`generationSection`은 실패 시 숨김).
    @ViewBuilder
    private var seasonSection: some View {
        switch viewModel.seasonState {
        case .idle, .loading:
            LoadingView(.home(.seasonLoading))
        case .loaded(let seasonTypes):
            seasonLoaded(seasonTypes)
        case .failed:
            RetryContentUnavailableView(
                title: "홈 정보를 불러오지 못했어요",
                systemImage: "exclamationmark.triangle",
                description: "네트워크 상태를 확인한 뒤 다시 시도해주세요.",
                isRetrying: isRetryingProfile,
                retryAction: { await retryProfile() }
            )
        }
    }

    private func seasonLoaded(_ seasonTypes: [SeasonType]) -> some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            ForEach(Array(seasonTypes.enumerated()), id: \.offset) { _, seasonType in
                SeasonCard(seasonType: seasonType)
                    .equatable()
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Generation Section

    /// 세대별 상벌점 카드 섹션. 실패 상태는 `seasonSection`의 재시도 카드가 대표한다.
    @ViewBuilder
    private var generationSection: some View {
        switch viewModel.generationState {
        case .idle, .loading:
            LoadingView(.home(.penaltyLoading))
        case .loaded(let generations):
            generationLoaded(generations)
        case .failed:
            EmptyView()
        }
    }

    @ViewBuilder
    private func generationLoaded(_ generations: [HomeGeneration]) -> some View {
        if generations.isEmpty {
            ContentUnavailableView(
                "활동 기록이 없습니다.",
                systemImage: "chart.pie",
                description: Text("아직 기수별 상벌점 내역이 없습니다.")
            )
            .glassEffect(
                .regular,
                in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius), isUniform: true)
            )
        } else {
            PenaltyCard(generations: generations)
                .equatable()
        }
    }

    // MARK: - Schedule Section

    /// 이번 달 일정 캘린더와 선택 날짜의 일정 리스트 섹션.
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing24) {
            ScheduleCard(
                selectedDate: $selectedDate,
                currentMonth: $currentMonth,
                scheduledDates: viewModel.scheduleDates
            )
            .equatable()

            scheduleList
        }
    }

    // MARK: - Recent Notice Section

    /// 최근 공지 섹션.
    ///
    /// 헤더는 상태와 무관하게 항상 보여준다 — 실패 시 섹션이 통째로 사라지면 사용자는
    /// 공지가 없는 것인지 못 불러온 것인지 구분할 수 없다.
    private var recentNoticeSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            Text("최근 공지")
                .appFont(.title3, weight: .semibold, color: .grey900)

            switch viewModel.recentNoticeState {
            case .idle, .loading:
                LoadingView(.home(.recentNoticeLoading))
            case .loaded(let notices):
                recentNoticeLoaded(notices)
            case .failed:
                RetryContentUnavailableView(
                    title: "최근 공지를 불러오지 못했어요",
                    systemImage: "exclamationmark.triangle",
                    description: "네트워크 상태를 확인한 뒤 다시 시도해주세요.",
                    isRetrying: isRetryingRecentNotice,
                    retryAction: { await retryRecentNotices() }
                )
            }
        }
    }

    @ViewBuilder
    private var scheduleList: some View {
        let schedules = viewModel.getSchedules(selectedDate)
        if schedules.isEmpty {
            ContentUnavailableView(
                "일정이 없습니다.",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("선택한 날짜에 등록된 일정이 없습니다.")
            )
            .glassEffect(
                .regular,
                in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius), isUniform: true)
            )
        } else if !viewModel.areCategoriesReady(for: schedules) {
            // 분류 전에는 전부 기본 아이콘으로 그려졌다가 뒤늦게 바뀌므로, 보이는 일정만 게이트한다.
            loadingPlaceholder(height: Constants.schedulePlaceholderHeight)
        } else {
            ForEach(schedules) { schedule in
                Button {
                    onScheduleSelected(schedule.scheduleId)
                } label: {
                    ScheduleListCard(
                        data: schedule,
                        category: viewModel.category(for: schedule.scheduleId)
                    )
                    .equatable()
                }
                .buttonStyle(ScheduleCardPressStyle())
            }
        }
    }

    @ViewBuilder
    private func recentNoticeLoaded(_ notices: [NoticeItemModel]) -> some View {
        if notices.isEmpty {
            ContentUnavailableView(
                "최근 공지가 없습니다.",
                systemImage: "bell.slash",
                description: Text("아직 등록된 공지사항이 없습니다.")
            )
            .glassEffect(
                .regular,
                in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius), isUniform: true)
            )
        } else {
            VStack(spacing: DefaultSpacing.spacing12) {
                ForEach(notices) { notice in
                    Button {
                        onNoticeSelected(notice.toNoticeDetail())
                    } label: {
                        RecentNoticeCard(notice: notice)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Component

    private func loadingPlaceholder(height: CGFloat) -> some View {
        ProgressView()
            .frame(maxWidth: .infinity, minHeight: height)
            .glassEffect(
                .regular,
                in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius), isUniform: true)
            )
    }

    // MARK: - Function

    /// 지정한 달(KST 기준 연/월)의 일정을 조회한다.
    private func fetchSchedules(of month: Date) async {
        let calendar = Calendar.kstGregorian
        await viewModel.fetchSchedules(
            year: calendar.component(.year, from: month),
            month: calendar.component(.month, from: month)
        )
    }

    private func retryProfile() async {
        guard !isRetryingProfile else { return }
        isRetryingProfile = true
        defer { isRetryingProfile = false }
        await viewModel.fetchProfile()
    }

    private func retryRecentNotices() async {
        guard !isRetryingRecentNotice else { return }
        isRetryingRecentNotice = true
        defer { isRetryingRecentNotice = false }
        await viewModel.retryRecentNotices()
    }

    /// 마지막 요청 이후 4주가 지났으면 앱스토어 리뷰를 요청한다.
    private func requestReviewIfDue() {
        guard reviewRequestPolicy.markRequestedIfDue() else { return }
        requestReview()
    }
}

// MARK: - Style

/// 일정 카드 탭 시 눌림 효과를 제공하는 ButtonStyle
private struct ScheduleCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(
                .spring(response: 0.22, dampingFraction: 0.8),
                value: configuration.isPressed
            )
    }
}

// MARK: - Preview

#if DEBUG
/// 네트워크 없이 화면을 확인하기 위한 프리뷰 전용 UseCase (절대규칙 #5)
private struct PreviewFetchHomeProfileUseCase: FetchHomeProfileUseCaseProtocol {
    func execute(forceRefresh: Bool) async throws -> HomeProfileResult {
        HomeProfileResult(
            memberId: "1",
            seasonTypes: [.gens(["11", "12"]), .days(128)],
            generations: [
                HomeGeneration(
                    gisuId: "10",
                    gen: "12",
                    penaltyPoint: 6,
                    rewardPoint: 5,
                    pointLogs: [
                        PointLog(id: "1", reason: "스터디 지각", date: "03.26", point: -2, isReward: false),
                        PointLog(id: "2", reason: "우수 워크북", date: "03.28", point: 2, isReward: true),
                    ]
                ),
                HomeGeneration(gisuId: "9", gen: "11", penaltyPoint: 0, rewardPoint: 0, pointLogs: []),
            ]
        )
    }
}

/// 네트워크 없이 최근 공지 화면을 확인하기 위한 프리뷰 전용 UseCase (절대규칙 #5)
private struct PreviewFetchRecentNoticesUseCase: FetchRecentNoticesUseCaseProtocol {
    func execute(gisuId: String) async throws -> [NoticeItemModel] {
        [
            NoticeItemModel(
                generation: "12",
                scope: .central,
                category: .general,
                mustRead: true,
                isAlert: false,
                date: Date(timeIntervalSinceNow: -3600),
                title: "12기 중앙 해커톤 일정 안내",
                content: "",
                writer: "운영진",
                links: [],
                images: [],
                vote: nil,
                viewCount: "32"
            ),
            NoticeItemModel(
                generation: "12",
                scope: .branch,
                category: .general,
                mustRead: false,
                isAlert: false,
                date: Date(timeIntervalSinceNow: -86400),
                title: "서울 지부 스터디 모집 공지",
                content: "",
                writer: "지부장",
                links: [],
                images: [],
                vote: nil,
                viewCount: "12",
                scopeDisplayName: "서울"
            ),
        ]
    }
}

/// 네트워크 없이 일정 캘린더를 확인하기 위한 프리뷰 전용 UseCase (절대규칙 #5)
private struct PreviewFetchSchedulesUseCase: FetchSchedulesUseCaseProtocol {
    func execute(from: Date, to: Date, isAttendanceRequired: Bool) async throws -> [Date: [ScheduleDetailData]] {
        let calendar = Calendar.kstGregorian
        let today = calendar.startOfDay(for: .now)
        let schedule = ScheduleDetailData(
            scheduleId: "1",
            name: "정기 세미나",
            description: "",
            tags: [],
            startsAt: today,
            endsAt: today.addingTimeInterval(3600),
            isParticipant: true
        )
        return [today: [schedule]]
    }
}

/// CoreML 로드 없이 카드 아이콘을 확인하기 위한 프리뷰 전용 UseCase (절대규칙 #5)
private struct PreviewClassifyScheduleUseCase: ClassifyScheduleUseCaseProtocol {
    func execute(title: String) async -> ScheduleIconCategory {
        .study
    }
}

/// 네트워크 없이 정본 프로필을 제공하는 프리뷰 전용 UseCase (절대규칙 #5)
private struct PreviewFetchMemberProfileUseCase: FetchMemberProfileUseCaseProtocol {
    func execute() async throws -> Profile {
        Profile(
            memberId: "1",
            name: "김유엠",
            nickname: "umc",
            generations: ["11", "12"],
            latestGisuId: "10"
        )
    }
}

/// 실제 `UserDefaults`를 건드리지 않기 위한 프리뷰 전용 no-op 동기화 UseCase (절대규칙 #5)
private struct PreviewSyncProfileStorageUseCase: SyncProfileStorageUseCaseProtocol {
    func execute(profile: Profile) {}
}

/// SwiftData 저장소 없이 화면을 그리기 위한 프리뷰 전용 기수 매핑 저장소 (절대규칙 #5)
private struct PreviewChallengerGenRepository: ChallengerGenRepositoryProtocol {
    func replaceMappings(_ pairs: [(gen: String, gisuId: String)]) throws {}

    func fetchGenGisuIdPairs() throws -> [(gen: String, gisuId: String)] { [] }
}

#Preview {
    let container = DIContainer()
    container.register(FetchHomeProfileUseCaseProtocol.self) { PreviewFetchHomeProfileUseCase() }
    container.register(FetchRecentNoticesUseCaseProtocol.self) { PreviewFetchRecentNoticesUseCase() }
    container.register(FetchSchedulesUseCaseProtocol.self) { PreviewFetchSchedulesUseCase() }
    container.register(ClassifyScheduleUseCaseProtocol.self) { PreviewClassifyScheduleUseCase() }
    container.register(ChallengerGenRepositoryProtocol.self) { PreviewChallengerGenRepository() }
    container.register(FetchMemberProfileUseCaseProtocol.self) {
        PreviewFetchMemberProfileUseCase()
    }
    container.register(SyncProfileStorageUseCaseProtocol.self) {
        PreviewSyncProfileStorageUseCase()
    }
    return NavigationStack {
        HomeView(container: container)
    }
}
#endif
