//
//  HomeView.swift
//  AppProduct
//
//  Created by euijjang97 on 1/19/26.
//

import StoreKit
import SwiftUI
import ClockKit

/// 홈 화면의 메인 뷰입니다.
///
/// 기수 정보, 일정, 패널티 현황 및 최근 공지사항을 종합적으로 보여줍니다.
struct HomeView: View {
    
    // MARK: - Properties
    
    /// 의존성 주입 컨테이너
    @Environment(\.di) var di
    /// 에러 핸들러 객체
    @Environment(ErrorHandler.self) var errorHandler
    /// 앱 리뷰 요청
    @Environment(\.requestReview) private var requestReview

    /// 홈 화면의 비즈니스 로직을 담당하는 뷰 모델
    @State private var viewModel: HomeViewModel

    /// 캘린더에서 선택된 날짜 (기본값: 현재 날짜)
    @State var selectedDate: Date = .init()

    /// 캘린더의 현재 표시 중인 월 (기본값: 현재 월)
    @State var currentMonth: Date = .init()

    /// 섹션별 재시도 로딩 상태
    @State private var isRetryingProfileSection: Bool = false
    @State private var isRetryingRecentNoticeSection: Bool = false
    @State private var isScheduleCategoryLoading: Bool = false
    @State private var scheduleCategories: [Int: ScheduleIconCategory] = [:]
    @State private var scheduleClassificationKey: [Int] = []

    /// Path Store
    private var pathStore: PathStore {
        di.resolve(PathStore.self)
    }

    /// 화면 진입 시 초기 데이터 로딩 수행 여부
    private let shouldFetchOnTask: Bool

    /// 일정 분류기를 공유해 모델/캐시 로딩 오버헤드를 줄입니다.
    private static let sharedScheduleClassifierUseCase: ClassifyScheduleUseCase = {
        let repository = ScheduleClassifierRepositoryImpl()
        return ClassifyScheduleUseCaseImpl(repository: repository)
    }()
    
    // MARK: - Init
    init(
        container: DIContainer,
        viewModel: HomeViewModel? = nil,
        selectedDate: Date = .init(),
        currentMonth: Date = .init(),
        shouldFetchOnTask: Bool = true
    ) {
        _viewModel = State(
            initialValue: viewModel ?? HomeViewModel(container: container)
        )
        _selectedDate = State(initialValue: selectedDate)
        _currentMonth = State(initialValue: currentMonth)
        self.shouldFetchOnTask = shouldFetchOnTask
    }
    
    // MARK: - Constants
    
    /// UI 구성에 사용되는 상수 모음입니다.
    private enum Constants {
        /// 최근 공지 표시 개수 (최대 5개)
        static let recentCardCount: Int = 5
        
        /// 최근 공지 섹션 타이틀 텍스트
        static let recentUpdateText: String = "최근 공지"
        
        /// 스크롤 위치 식별자 ID
        static let scrollId: String = "scroll"

    }
    
    // MARK: - Body
    var body: some View {
        // NavigationStack의 path를 PathStore에 바인딩하여 홈 내 네비게이션 상태를 유지합니다.
        NavigationStack(path: Binding(
            get: { pathStore.homePath },
            set: { pathStore.homePath = $0 }
        )) {
            // 스크롤 위치 제어를 위해 ScrollViewReader를 사용합니다.
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: DefaultSpacing.spacing24) {
                        seasonCard
                        generations
                        calendar
                        recentUpdate
                    }
                    .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
                }
                .contentMargins(.bottom, DefaultConstant.defaultContentBottomMargins, for: .scrollContent)
                .toolbar {
                    ToolBarCollection.BellBtn(action: { pathStore.homePath.append(.home(.alarmHistory)) })
                    ToolBarCollection.Logo(image: .logoLight)
                }
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                NavigationRoutingView(destination: destination)
            }
            .umcDefaultBackground()
            // 화면 진입 시 홈 화면에 필요한 모든 데이터를 한 번에 로드합니다.
            .task {
                guard shouldFetchOnTask else { return }
                await viewModel.fetchAllIfNeeded()
                requestReviewIfNeeded()
            }
            .task(id: pathStore.homePath.count) {
                guard shouldFetchOnTask else { return }
                guard pathStore.homePath.isEmpty else { return }
                await reloadVisibleScheduleMonth()
            }
            .onReceive(NotificationCenter.default.publisher(for: .memberPenaltyUpdated)) { _ in
                guard shouldFetchOnTask else { return }
                Task {
                    await viewModel.fetchProfile()
                }
            }
        }
    }
    
    // MARK: - Season Info
    
    /// 상단 기 뷰
    @ViewBuilder
    private var seasonCard: some View {
        switch viewModel.seasonData {
        case .loading where isRetryingProfileSection:
            SectionErrorCard(content: .seasonInfo, isLoading: true) {
                Task { await retryProfileSection() }
            }
        case .idle, .loading:
            LoadingView(.home(.seasonLoading))
        case .loaded(let seasonData):
            seasonLoaded(seasonData)
        case .failed:
            SectionErrorCard(content: .seasonInfo, isLoading: isRetryingProfileSection) {
                Task { await retryProfileSection() }
            }
        }
    }
    
    private func seasonLoaded(_ seasonData: [SeasonType]) -> some View {
        HStack {
            ForEach(Array(seasonData.enumerated()), id: \.offset) { index, season in
                SeasonCard(type: season)
                    .equatable()
            }
        }
    }
    
    // MARK: - Penalty Info
    
    /// 기수별 패널티 현황을 보여주는 뷰
    @ViewBuilder
    private var generations: some View {
        switch viewModel.generationData {
        case .loading where isRetryingProfileSection:
            SectionErrorCard(content: .penaltyInfo, isLoading: true) {
                Task { await retryProfileSection() }
            }
        case .idle, .loading:
            LoadingView(.home(.penaltyLoading))
        case .loaded(let generation):
            generationLoaded(generation)
        case .failed:
            SectionErrorCard(content: .penaltyInfo, isLoading: isRetryingProfileSection) {
                Task { await retryProfileSection() }
            }
        }
    }
    
    @ViewBuilder
    private func generationLoaded(_ generation: [GenerationData]) -> some View {
        PenaltyCard(generations: generation)
            .equatable()
    }
    
    // MARK: - Calendar
    
    /// 캘린더 및 일정 리스트를 포함하는 뷰
    private var calendar: some View {
        VStack(spacing: DefaultSpacing.spacing8, content: {
            // 캘린더 카드: 선택 날짜와 현재 월 상태를 전달합니다.
            ScheduleCard(selectedDate: $selectedDate,
                         currentMonth: $currentMonth,
                         scheduledDates: viewModel.scheduleDates
            )
            .equatable()

            scheduleList
        })
        // 월 변경 시 해당 월의 일정을 다시 불러옵니다.
        .onChange(of: currentMonth) { _, newMonth in
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = ServerDateTimeConverter.kstTimeZone
            let year = calendar.component(.year, from: newMonth)
            let month = calendar.component(.month, from: newMonth)
            Task {
                await viewModel.fetchSchedules(year: year, month: month)
            }
        }
    }
    
    /// 선택된 날짜의 상세 일정 리스트 표시
    @ViewBuilder
    private var scheduleList: some View {
        let schedules = viewModel.getSchedules(selectedDate)

        Group {
            if schedules.isEmpty {
                emptySchedule
            } else if isScheduleCategoryLoading || !areScheduleCategoriesReady(for: schedules) {
                LoadingView(.home(.seasonLoading))
            } else {
                LazyVStack(spacing: DefaultSpacing.spacing8) {
                    ForEach(schedules, id: \.id) { schedule in
                        Button(action: {
                            // 일정 상세 화면으로 이동하며 선택 날짜를 함께 전달합니다.
                            pathStore.homePath.append(
                                .home(
                                    .detailSchedule(
                                        scheduleId: schedule.scheduleId
                                    )
                                )
                            )
                        }) {
                            ScheduleListCard(
                                data: schedule,
                                category: scheduleCategories[schedule.scheduleId]
                            )
                                .equatable()
                        }
                        .buttonStyle(ScheduleCardPressStyle())
                    }
                }
            }
        }
        .task(id: scheduleClassificationTaskKey(for: schedules)) {
            await classifyScheduleCategories(for: schedules)
        }
    }
    
    /// 일정이 없을 때 표시되는 빈 상태 뷰
    private var emptySchedule: some View {
        ContentUnavailableView("일정이 없습니다.",
                               systemImage: "calendar.badge.exclamationmark",
                               description: Text("선택한 날짜에 등록된 일정이 없습니다.")
        )
        .glassEffect(.regular, in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius), isUniform: true))
    }

    @MainActor
    private func classifyScheduleCategories(for schedules: [ScheduleDetailData]) async {
        let ids = schedules.map(\.scheduleId)

        guard !ids.isEmpty else {
            scheduleClassificationKey = []
            isScheduleCategoryLoading = false
            return
        }

        scheduleClassificationKey = ids
        isScheduleCategoryLoading = true

        var classified: [Int: ScheduleIconCategory] = [:]
        await withTaskGroup(of: (Int, ScheduleIconCategory).self) { group in
            for schedule in schedules {
                group.addTask {
                    let category = await Self.sharedScheduleClassifierUseCase.execute(title: schedule.name)
                    return (schedule.scheduleId, category)
                }
            }

            for await (scheduleId, category) in group {
                classified[scheduleId] = category
            }
        }

        // 스크롤/날짜 변경으로 대상이 바뀐 경우 이전 결과는 버립니다.
        guard scheduleClassificationKey == ids else { return }
        scheduleCategories.merge(classified) { _, new in new }
        isScheduleCategoryLoading = false
    }

    private func areScheduleCategoriesReady(for schedules: [ScheduleDetailData]) -> Bool {
        schedules.allSatisfy { scheduleCategories[$0.scheduleId] != nil }
    }

    private func scheduleClassificationTaskKey(for schedules: [ScheduleDetailData]) -> String {
        schedules
            .map { "\($0.scheduleId):\($0.name)" }
            .joined(separator: "|")
    }

    @MainActor
    private func reloadVisibleScheduleMonth() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = ServerDateTimeConverter.kstTimeZone
        let year = calendar.component(.year, from: currentMonth)
        let month = calendar.component(.month, from: currentMonth)
        await viewModel.fetchSchedules(year: year, month: month)
    }
    
    // MARK: - Recent Notices
    
    /// 최근 공지사항 섹션 전체 뷰
    private var recentUpdate: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12, content: {
            recentHeader
            sectionContent
        })
    }
    
    /// 최근 공지 섹션 헤더
    private var recentHeader: some View {
        Text(Constants.recentUpdateText)
            .appFont(.title3Emphasis, color: .grey900)
    }
    
    /// 최근 공지 데이터 상태(로딩, 성공, 실패)에 따른 컨텐츠 뷰
    @ViewBuilder
    private var sectionContent: some View {
        switch viewModel.recentNoticeData {
        case .loading where isRetryingRecentNoticeSection:
            SectionErrorCard(content: .recentNotice, isLoading: true) {
                Task { await retryRecentNoticeSection() }
            }
        case .idle, .loading:
            LoadingView(.home(.recentNoticeLoading))
        case .loaded(let recentNoticeData):
            recentView(recentNoticeData)
        case .failed:
            SectionErrorCard(content: .recentNotice, isLoading: isRetryingRecentNoticeSection) {
                Task { await retryRecentNoticeSection() }
            }
        }
    }

    /// 마지막 리뷰 요청으로부터 4주 경과 시 앱 리뷰를 요청합니다.
    private func requestReviewIfNeeded() {
        let key = "lastReviewRequestDate"
        let fourWeeks: TimeInterval = 60 * 60 * 24 * 28

        if let lastDate = UserDefaults.standard.object(forKey: key) as? Date,
           Date().timeIntervalSince(lastDate) < fourWeeks {
            return
        }

        UserDefaults.standard.set(Date(), forKey: key)
        requestReview()
    }

    /// 프로필 섹션(기수 카드 + 패널티) 재시도
    @MainActor
    private func retryProfileSection() async {
        guard !isRetryingProfileSection else { return }
        isRetryingProfileSection = true
        defer { isRetryingProfileSection = false }
        await viewModel.fetchProfile()
    }

    /// 최근 공지 섹션 재시도 (역할 정보 없으면 프로필부터 재조회)
    @MainActor
    private func retryRecentNoticeSection() async {
        guard !isRetryingRecentNoticeSection else { return }
        isRetryingRecentNoticeSection = true
        defer { isRetryingRecentNoticeSection = false }
        if viewModel.roles.isEmpty {
            await viewModel.fetchProfile()
        }
        await viewModel.fetchRecentNotices()
    }
    
    /// 로드된 최근 공지 데이터를 표시하는 리스트 뷰
    /// - Parameter recentNoticeData: 표시할 공지 데이터 배열
    @ViewBuilder
    private func recentView(_ recentNoticeData: [RecentNoticeData]) -> some View {
        if recentNoticeData.isEmpty {
            ContentUnavailableView(
                "최근 공지가 없습니다.",
                systemImage: "megaphone",
                description: Text("아직 등록된 최근 공지 항목이 없습니다.")
            )
            .glassEffect(.regular, in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius), isUniform: true))
        } else {
            LazyVStack(spacing: DefaultSpacing.spacing8) {
                ForEach(recentNoticeData.prefix(Constants.recentCardCount), id: \.id) { data in
                    Button {
                        openRecentNoticeDetail(data)
                    } label: {
                        RecentNoticeCard(data: data)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func openRecentNoticeDetail(_ data: RecentNoticeData) {
        let detail = makeNoticeDetail(from: data)
        pathStore.homePath.append(.home(.detailNotice(detailItem: detail)))
    }

    private func makeNoticeDetail(from data: RecentNoticeData) -> NoticeDetail {
        let scope: NoticeScope
        switch data.category {
        case .operationsTeam:
            scope = .central
        case .univ:
            scope = .campus
        case .oranization:
            scope = .branch
        }

        let generation = viewModel.roles.max(by: { $0.gisu < $1.gisu })?.gisu ?? 0
        let targetAudience = TargetAudience.all(generation: generation, scope: scope)

        return NoticeDetail(
            id: String(data.noticeId),
            generation: generation,
            scope: scope,
            category: .general,
            title: data.title,
            content: "",
            authorID: "",
            authorName: "",
            authorImageURL: nil,
            createdAt: data.createdAt,
            updatedAt: nil,
            targetAudience: targetAudience,
            hasPermission: false,
            images: [],
            links: [],
            vote: nil
        )
    }
}

/// 일정 카드 탭 시 눌림 효과를 제공하는 ButtonStyle
private struct ScheduleCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

#if DEBUG
#Preview("홈 - 패널티 0점") {
    ZeroPenaltyHomePreviewView()
}

private struct ZeroPenaltyHomePreviewView: View {
    private let di: DIContainer
    private let viewModel: HomeViewModel

    init() {
        let container = DIContainer()
        container.register(PathStore.self) { PathStore() }
        self.di = container
        self.viewModel = HomeViewModel.zeroPenaltyPreview(container: container)
    }

    var body: some View {
        NavigationStack {
            HomeView(
                container: di,
                viewModel: viewModel,
                shouldFetchOnTask: false
            )
        }
        .environment(\.di, di)
        .environment(ErrorHandler())
    }
}
#endif
