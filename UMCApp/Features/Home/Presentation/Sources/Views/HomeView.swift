//
//  HomeView.swift
//  HomePresentation
//
//  Created by euijjang97 on 7/9/26.
//

import CoreDesignSystem
import CoreDI
import CoreUIComponents
import HomeDomain
import NoticeDomain
import SwiftUI
import UMCFoundation

/// 홈 대시보드 메인 화면.
///
/// 슬라이스 1(#913) 범위: 진입 시 프로필을 로드해 시즌 카드와 세대별 상벌점 카드를 표시한다.
/// 슬라이스 2(#914) 범위: 이번 달 일정 캘린더와 선택 날짜의 일정 리스트를 표시한다.
/// 슬라이스 3(#915) 범위: 최신 기수의 최근 공지 5건을 표시하고, 탭 시 상세 화면으로 이동한다.
/// `NavigationStack`은 루트 탭 셸이 소유하므로 이 뷰는 콘텐츠만 구성한다.
struct HomeView: View {

    // MARK: - Property

    @State private var viewModel: HomeViewModel
    @State private var selectedDate: Date = .now
    @State private var currentMonth: Date = .now
    private let onNoticeSelected: (NoticeDetail) -> Void

    // MARK: - Constants

    fileprivate enum Constants {
        static let seasonPlaceholderHeight: CGFloat = 120
        static let penaltyPlaceholderHeight: CGFloat = 240
        static let recentNoticePlaceholderHeight: CGFloat = 280
    }

    // MARK: - Init

    /// - Parameters:
    ///   - container: UseCase를 resolve할 DI 컨테이너
    ///   - viewModel: 프리뷰/테스트용 주입 지점 (기본값: container로 생성)
    ///   - onNoticeSelected: 최근 공지 카드 탭 시 상세 화면 이동을 위임하는 콜백
    init(
        container: DIContainer,
        viewModel: HomeViewModel? = nil,
        onNoticeSelected: @escaping (NoticeDetail) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel ?? HomeViewModel(container: container))
        self.onNoticeSelected = onNoticeSelected
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
        .task {
            await viewModel.fetchProfileIfNeeded()
        }
        .task {
            await viewModel.fetchSchedules()
        }
        .onChange(of: currentMonth) { _, newMonth in
            let calendar = Calendar.kstGregorian
            Task {
                await viewModel.fetchSchedules(
                    year: calendar.component(.year, from: newMonth),
                    month: calendar.component(.month, from: newMonth)
                )
            }
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
            loadingPlaceholder(height: Constants.seasonPlaceholderHeight)
        case .loaded(let seasonTypes):
            seasonLoaded(seasonTypes)
        case .failed:
            RetryContentUnavailableView(
                title: "홈 정보를 불러오지 못했어요",
                systemImage: "exclamationmark.triangle",
                description: "네트워크 상태를 확인한 뒤 다시 시도해주세요.",
                isRetrying: false,
                retryAction: { await viewModel.fetchProfile() }
            )
        }
    }

    private func seasonLoaded(_ seasonTypes: [SeasonType]) -> some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            ForEach(Array(seasonTypes.enumerated()), id: \.offset) { _, seasonType in
                SeasonCard(seasonType: seasonType)
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
            loadingPlaceholder(height: Constants.penaltyPlaceholderHeight)
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

    /// 최근 공지 섹션. 프로필 조회에 종속되므로 실패 안내는 `seasonSection`이 대표한다.
    @ViewBuilder
    private var recentNoticeSection: some View {
        switch viewModel.recentNoticeState {
        case .idle, .loading:
            loadingPlaceholder(height: Constants.recentNoticePlaceholderHeight)
        case .loaded(let notices):
            recentNoticeLoaded(notices)
        case .failed:
            EmptyView()
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
        } else {
            ForEach(schedules) { schedule in
                ScheduleListCard(data: schedule)
                    .equatable()
            }
        }
    }

    @ViewBuilder
    private func recentNoticeLoaded(_ notices: [NoticeItemModel]) -> some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            Text("최근 공지")
                .appFont(.title3, weight: .semibold, color: .grey900)

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

#Preview {
    let container = DIContainer()
    container.register(FetchHomeProfileUseCaseProtocol.self) { PreviewFetchHomeProfileUseCase() }
    container.register(FetchRecentNoticesUseCaseProtocol.self) { PreviewFetchRecentNoticesUseCase() }
    container.register(FetchSchedulesUseCaseProtocol.self) { PreviewFetchSchedulesUseCase() }
    return NavigationStack {
        HomeView(container: container)
    }
}
#endif
