import CoreDesignSystem
import CoreDI
import CoreUIComponents
import HomeDomain
import SwiftUI
import UMCFoundation

/// 홈 대시보드 메인 화면.
///
/// 슬라이스 1(#913) 범위: 진입 시 프로필을 로드해 시즌 카드와 세대별 상벌점 카드를
/// 표시한다. 캘린더/최근 공지 등 나머지 섹션은 후속 슬라이스에서 추가된다.
/// `NavigationStack`은 루트 탭 셸이 소유하므로 이 뷰는 콘텐츠만 구성한다.
struct HomeView: View {

    // MARK: - Property

    @State private var viewModel: HomeViewModel

    // MARK: - Constants

    fileprivate enum Constants {
        static let seasonPlaceholderHeight: CGFloat = 120
        static let penaltyPlaceholderHeight: CGFloat = 240
    }

    // MARK: - Init

    /// - Parameters:
    ///   - container: UseCase를 resolve할 DI 컨테이너
    ///   - viewModel: 프리뷰/테스트용 주입 지점 (기본값: container로 생성)
    init(container: DIContainer, viewModel: HomeViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? HomeViewModel(container: container))
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: DefaultSpacing.spacing24) {
                seasonSection
                generationSection
            }
            .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
        }
        .contentMargins(.bottom, DefaultConstant.defaultContentBottomMargins, for: .scrollContent)
        .umcDefaultBackground()
        .task {
            await viewModel.fetchProfileIfNeeded()
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
private struct PreviewFetchMyProfileUseCase: FetchMyProfileUseCaseProtocol {
    func execute() async throws -> HomeProfileResult {
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

#Preview {
    let container = DIContainer()
    container.register(FetchMyProfileUseCaseProtocol.self) { PreviewFetchMyProfileUseCase() }
    return NavigationStack {
        HomeView(container: container)
    }
}
#endif
