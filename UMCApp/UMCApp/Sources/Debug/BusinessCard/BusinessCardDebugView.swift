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

    // MARK: - Init

    init(container: DIContainer) {
        self.container = container
        _viewModel = State(initialValue: BusinessCardDebugViewModel(container: container))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                DebugBusinessCardHero(container: container, viewModel: viewModel)
                cardManagementSection
                myActivitySection
                toolsSection
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("마이페이지 (검증)")
        .navigationBarTitleDisplayMode(.large)
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

    private var toolsSection: some View {
        DebugSectionCard(title: "검증 도구 (시안에 없음)") {
            DebugMyPageRow(
                icon: "wrench.and.screwdriver.fill",
                iconTint: .gray,
                title: "QR 스캔 · UWB · 원본 필드"
            ) {
                DebugToolsView(viewModel: viewModel)
            }
        }
    }
}
#endif
