//
//  MyPageView.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import BusinessCardDomain
import BusinessCardPresentation
import CoreDesignSystem
import CoreDI
import CoreRouting
import CoreUIComponents
import MyPageDomain
import SwiftUI
import UMCFoundation

/// MyPage 탭 루트 화면 (v3 — 명함 중심).
///
/// 명함 카드 + 「명함 관리」 + 「나의 활동」 섹션이 루트다. 기존 섹션 7종(외부 링크·설정·법률·정보·
/// 소셜 연동·회원 관리·UMC 채널)은 ``MyPageSettingsView``로 옮겨갔고, 툴바 ⚙ 버튼으로 진입한다.
///
/// - Important: 자체 `NavigationStack`을 만들지 않는다. 탭별 스택은 상위 탭 셸이 소유한다.
struct MyPageView: View {

    // MARK: - Property

    @State private var viewModel: MyPageViewModel

    /// 명함 앞/뒷면 전환. 카드 소유이며 뒤집힘 여부는 다른 화면 상태에 얽히지 않는다.
    @State private var isCardFlipped = false

    @Environment(PathStore.self) private var pathStore

    private let container: DIContainer
    private let onOpenBusinessCard: (BusinessCardEntry) -> Void

    // MARK: - Init

    /// - Parameters:
    ///   - container: 섹션·목적지 화면이 UseCase를 resolve할 DI 컨테이너
    ///   - onOpenBusinessCard: 명함 카드 버튼·「받은 명함」 행이 App 셸에 명함 진입을 요청한다.
    ///   - viewModel: 프리뷰/테스트용 주입 지점 (기본값: container로 생성)
    init(
        container: DIContainer,
        onOpenBusinessCard: @escaping (BusinessCardEntry) -> Void,
        viewModel: MyPageViewModel? = nil
    ) {
        self.container = container
        self.onOpenBusinessCard = onOpenBusinessCard
        _viewModel = State(initialValue: viewModel ?? MyPageViewModel(container: container))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing24) {
                cardContent

                VStack(alignment: .leading, spacing: Metrics.sectionGroupSpacing) {
                    BusinessCardSection(
                        receivedCardCount: viewModel.activityStat.receivedCardCount,
                        onReceivedCards: { onOpenBusinessCard(.receivedCards) },
                        onCardEdit: cardEditAction,
                        isCardEditPending: viewModel.isCardEditPending
                    )

                    MyActivitySection(studyCount: viewModel.activityStat.studyCount)
                }
            }
            .padding(.horizontal, Metrics.contentHorizontalPadding)
            .padding(.top, DefaultSpacing.spacing16)
            .padding(.bottom, DefaultSpacing.spacing24)
        }
        .navigation(naviTitle: NavigationTitle.MyPage.root, displayMode: .inline)
        .umcDefaultBackground()
        .alertPrompt(item: $viewModel.alertPrompt)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    pathStore.push(MyPageDestination.settings, on: .mypage)
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("설정")
            }
        }
        .navigationDestination(for: MyPageDestination.self) { destination in
            MyPageRoutingView(destination: destination, container: container)
        }
        .task {
            await viewModel.fetchProfile()
        }
        .task {
            await viewModel.loadBusinessCard()
        }
        // 프로필 상세에서 이미지·링크를 수정하고 돌아오면 카드가 옛 스냅샷으로 남는다.
        // 수정 API가 세션 캐시를 갱신해 두므로 여기서는 추가 왕복 없이 최신 값을 다시 읽는다.
        // 명함도 같은 정본 프로필 캐시에서 파생되므로 함께 다시 읽는다.
        .onChange(of: pathStore.depth(of: .mypage)) { previousDepth, currentDepth in
            guard currentDepth < previousDepth else { return }
            Task {
                await viewModel.fetchProfile()
                await viewModel.loadBusinessCard()
            }
        }
    }

    // MARK: - View Component

    @ViewBuilder
    private var cardContent: some View {
        switch viewModel.myCard {
        case .idle, .loading:
            Progress()
                .frame(maxWidth: .infinity)

        case .loaded(let card):
            BusinessCardFaceView(
                card: card,
                isFlipped: isCardFlipped,
                qrImage: viewModel.qrImage,
                onFlip: { isCardFlipped.toggle() },
                onExchange: { onOpenBusinessCard(.exchange) },
                onQR: { onOpenBusinessCard(.cardQR) }
            )

        case .failed(let error):
            RetryContentUnavailableView(
                title: "명함을 불러오지 못했어요",
                systemImage: "person.crop.circle.badge.exclamationmark",
                description: error.errorDescription ?? "잠시 후 다시 시도해 주세요.",
                isRetrying: viewModel.isCardRetryInFlight,
                retryAction: { await Self.retryCardAndProfile(viewModel: viewModel) }
            )
        }
    }

    // MARK: - Function

    /// 명함 편집(프로필 상세)으로 이동하는 액션. 스냅샷이 아직 없으면(로딩 중·실패) `nil` —
    /// `BusinessCardSection`이 이를 받아 행을 비활성화한다(``MyPageViewModel/isCardEditPending``
    /// 이 로딩 중인 구간의 진행 표시를 함께 맡는다). `nil`이 아닐 때도 재조회하지 않고 루트가
    /// 이미 로드해 둔 스냅샷을 싣는다 — `MyPageDestination.profile`의 문서 주석과 같은 이유
    /// (어긋난 값으로 편집이 시작되는 것을 막기 위함)다.
    private var cardEditAction: (() -> Void)? {
        guard let profile = viewModel.profileData.value else { return nil }
        return { pathStore.push(MyPageDestination.profile(profileData: profile), on: .mypage) }
    }

    /// 명함 카드 로드 실패 후 재시도. 진입 시 네트워크 장애로 `profileData`도 함께
    /// `.failed`가 됐을 수 있다 — 카드만 재시도하면 「명함 편집」 행이 활성 외관인 채
    /// 무반응으로 남으므로(``cardEditAction``이 `profileData`를 요구) 두 로드를 함께
    /// 재시도한다. `static`으로 뽑아 뷰 렌더링 없이 테스트한다.
    static func retryCardAndProfile(viewModel: MyPageViewModel) async {
        await viewModel.fetchProfile(forceRefresh: true)
        await viewModel.loadBusinessCard(forceRefresh: true)
    }

    // MARK: - Metrics

    /// 시안 실측값 (`view-facts.md` 「마이페이지 v3 루트」).
    private enum Metrics {
        static let contentHorizontalPadding: CGFloat = 14
        /// 「명함 관리」·「나의 활동」 섹션 그룹 사이 간격.
        static let sectionGroupSpacing: CGFloat = 23
    }
}
