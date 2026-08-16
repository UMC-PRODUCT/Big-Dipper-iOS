//
//  BusinessCardDebugView.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import CoreDI
import SwiftUI
import BusinessCardDomain
import UMCFoundation

/// 명함 기능 계층(#1193~#1196) 동작 확인용 검증 화면.
///
/// **배치는 마이페이지 v3 시안(Figma 12630:33563)을 따른다** — 명함 카드, 「명함 관리」
/// 2행, 「나의 활동」 2행. 색·타이포·간격은 시안 토큰이 아니라 시스템 값이다. 목적은
/// 실기기에서 각 기능이 제자리에서 동작하는지 보는 것이지 픽셀을 맞추는 게 아니다.
///
/// 시안에 없는 검증 전용 도구(QR 스캔·UWB·페이로드 왕복)는 맨 아래 한 단계 밑으로 격리한다.
/// 릴리스 빌드에는 포함되지 않는다.
struct BusinessCardDebugView: View {

    // MARK: - Property

    @State private var viewModel: BusinessCardDebugViewModel

    private let container: DIContainer

    /// 시안 마이페이지 v3 루트(12630:33563) 실측값.
    private enum Constants {
        static let horizontalPadding: CGFloat = 14
        static let cardToSectionsSpacing: CGFloat = 24
        static let sectionSpacing: CGFloat = 23
    }

    // MARK: - Init

    init(container: DIContainer) {
        self.container = container
        _viewModel = State(initialValue: BusinessCardDebugViewModel(container: container))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            // 시안 실측: 콘텐츠 x=14 / w=372. 명함 카드와 섹션 그룹 사이 24, 섹션 그룹
            // 안쪽 두 섹션 사이 23 — 값이 다르므로 하나의 VStack으로 뭉뚱그리지 않는다.
            VStack(spacing: Constants.cardToSectionsSpacing) {
                DebugBusinessCardHero(container: container, viewModel: viewModel)

                VStack(spacing: Constants.sectionSpacing) {
                    cardManagementSection
                    myActivitySection
                }
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("마이페이지")
        .navigationBarTitleDisplayMode(.large)
        // 검증 도구는 본문에서 뺀다 — 시안에 없는 섹션이 배치 확인을 방해했다. 다만 NI(UWB)
        // 레인징이 이 안에 있고 아직 검증이 남아서 없애지는 않고 툴바 뒤로 옮긴다.
        // 시안의 우상단은 설정(gearshape) 자리인데, 설정 화면 착수 전까지 여기를 빌린다.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    DebugToolsView(container: container, viewModel: viewModel)
                } label: {
                    Image(systemName: "wrench.and.screwdriver")
                }
                .accessibilityLabel("검증 도구")
            }
        }
        .task { await viewModel.loadAll() }
        // 하위 화면에서 돌아왔을 때 카운트가 따라오도록 한다 (`task`는 재진입 시 다시 돌지 않는다).
        .onAppear { Task { await viewModel.reloadActivityStat() } }
        .refreshable { await viewModel.loadAll() }
    }

    // MARK: - Section

    private var cardManagementSection: some View {
        DebugSectionCard(title: "명함 관리") {
            DebugMyPageRow(
                icon: "person.text.rectangle.fill",
                iconTint: .green,
                title: "받은 명함",
                trailingValue: "\(viewModel.activityStat.receivedCardCount)장"
            ) {
                DebugReceivedCardsView(viewModel: viewModel)
            }

            DebugRowDivider()

            DebugMyPageRow(
                icon: "square.and.pencil",
                iconTint: .blue,
                title: "명함 편집"
            ) {
                DebugCardEditView(container: container, viewModel: viewModel)
            }
        }
    }

    private var myActivitySection: some View {
        DebugSectionCard(title: "나의 활동") {
            DebugMyPageRow(
                icon: "chart.bar.fill",
                iconTint: .orange,
                title: "나의 스터디",
                trailingValue: "\(viewModel.activityStat.studyCount)건"
            ) {
                DebugMyStudyListView(container: container)
            }

            DebugRowDivider()

            DebugMyPageRow(
                icon: "folder.fill",
                iconTint: .teal,
                title: "나의 활동 · 프로젝트",
                trailingValue: "\(viewModel.activityStat.activityCount)건"
            ) {
                DebugMyActivityListView(container: container)
            }
        }
    }

}
#endif
