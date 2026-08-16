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
                DebugCountSourceView(
                    title: "나의 스터디",
                    value: viewModel.activityStat.studyCount,
                    source: "GET /api/v1/study-groups/managed → itemCount",
                    caveat: """
                    이 엔드포인트는 StudyRouter 주석에 「운영 스터디 그룹 페이지 조회」로 적혀 있다. \
                    참여 스터디가 아니라 관리하는 스터디일 수 있다 — 값이 본인의 참여 스터디 수와 \
                    다르면 엔드포인트를 바꿔야 한다.
                    """
                )
            }

            DebugRowDivider()

            DebugMyPageRow(
                icon: "folder.fill",
                iconTint: .teal,
                title: "나의 활동 · 프로젝트",
                trailingValue: "\(viewModel.activityStat.activityCount)건"
            ) {
                DebugCountSourceView(
                    title: "나의 활동 · 프로젝트",
                    value: viewModel.activityStat.activityCount,
                    source: "프로필 캐시의 challengerRecords에서 admin 제외 count (네트워크 왕복 없음)",
                    caveat: """
                    서버에 활동/프로젝트 전용 API가 없어 기수 이력에서 파생한다. 그래서 실제 의미는 \
                    「챌린저로 활동한 기수 수」다. 마이페이지 활동 이력 목록은 운영진 역할까지 \
                    합치므로 두 숫자가 다를 수 있다. 「프로젝트」에 대응하는 서버 개념은 없다.
                    """
                )
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

/// 카운트 한 개가 **어디서 오는지**를 적어두는 화면.
///
/// 숫자만 보면 맞는지 알 수 없다 — 출처와 알려진 함정을 같이 보여줘야 실기기에서 판단할 수 있다.
private struct DebugCountSourceView: View {

    let title: String
    let value: String
    let source: String
    let caveat: String

    var body: some View {
        List {
            Section {
                HStack {
                    Text("현재 값").foregroundStyle(.secondary)
                    Spacer()
                    Text(value).font(.title3.bold())
                }
            }

            Section("데이터 출처") {
                Text(source).font(.callout).monospaced()
            }

            Section("확인할 것") {
                Text(caveat).font(.callout)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
