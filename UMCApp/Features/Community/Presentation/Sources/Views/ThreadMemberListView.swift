//
//  ThreadMemberListView.swift
//  CommunityPresentation
//

import SwiftUI
import CommunityDomain
import CoreDesignSystem
import CoreDI
import CoreRouting
import CoreUIComponents
import UMCFoundation

// MARK: - Constants

fileprivate enum Constants {
    static let loadFailureTitle = "참여자를 불러오지 못했어요"
}

/// 스레드 참여자 목록.
///
/// 개설자에게만 행 ⋯ 메뉴(개설자 위임·내보내기)가 열린다. 위임 전용 화면을 따로 두지 않고
/// 이 메뉴 하나로 처리한다 (#1131 결정 2).
struct ThreadMemberListView: View {

    // MARK: - Property

    @State private var viewModel: ThreadMemberListViewModel

    /// 나가기가 끝났을 때 리스트 화면에 알린다. 실시간 `member.left` 로도 행이 지워지지만,
    /// 그걸 기다리면 루트로 돌아온 직후 잠깐 남아 있는 행이 보인다.
    private let onLeft: () -> Void

    @Environment(\.di) private var di
    @Environment(PathStore.self) private var pathStore

    @State private var isInviteSheetPresented = false

    // MARK: - Init

    init(viewModel: ThreadMemberListViewModel, onLeft: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onLeft = onLeft
    }

    // MARK: - Body

    var body: some View {
        content
            .navigationTitle("참여자")
            .navigationBarTitleDisplayMode(.inline)
            .umcDefaultBackground()
            .toolbar {
                if viewModel.isOwner {
                    ToolbarItem(placement: .topBarTrailing) { inviteButton }
                }
            }
            .alertPrompt(item: $viewModel.alertPrompt)
            .sheet(isPresented: $isInviteSheetPresented) {
                ThreadInviteSheet(
                    viewModel: ThreadInviteViewModel(
                        threadId: viewModel.threadId,
                        useCase: di.resolve(CommunityThreadInviteUseCaseProtocol.self)
                    ),
                    // 초대한 쪽에는 실시간 이벤트가 오지 않아 목록을 직접 다시 읽는다.
                    onInvited: { _ in Task { await viewModel.load() } }
                )
            }
            .task { await viewModel.load() }
            .onChange(of: viewModel.didLeave) { _, didLeave in
                guard didLeave else { return }
                onLeft()
                // 방까지 함께 접어야 한다 — 한 단계만 pop 하면 이미 나온 스레드의 채팅방이 남는다.
                pathStore[.community] = NavigationPath()
            }
    }

    // MARK: - View Component

    /// 초대 진입점. 개설자에게만 열린다 (#1136 완료 조건 1 · 시안 #36 상단 "초대").
    private var inviteButton: some View {
        Button("초대") { isInviteSheetPresented = true }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let members):
            memberList(members)

        case .failed(let error):
            RetryContentUnavailableView(
                title: Constants.loadFailureTitle,
                systemImage: "exclamationmark.triangle",
                description: error.userMessage,
                isRetrying: false
            ) {
                await viewModel.load()
            }
        }
    }

    private func memberList(_ members: [ThreadMember]) -> some View {
        List {
            Section("참여자 \(members.count)명") {
                ForEach(members) { member in
                    ThreadMemberRow(
                        member: member,
                        isMe: viewModel.isMe(member),
                        canManage: viewModel.canManage(member),
                        onTransferOwnership: {
                            viewModel.confirmTransferOwnership(to: member)
                        },
                        onKick: { viewModel.confirmKick(member) }
                    )
                }
            }

            leaveSection
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.load() }
    }

    /// 나가기. 개설자는 위임 전까지 버튼이 잠기고, 그 사유를 footer 로 붙인다 (#1131 결정 2).
    private var leaveSection: some View {
        Section {
            Button("스레드 나가기", role: .destructive) {
                viewModel.confirmLeave()
            }
            .disabled(!viewModel.canLeave)
        } footer: {
            if let reason = viewModel.leaveBlockReason {
                Text(reason)
                    .appFont(.caption1, color: .grey600)
            }
        }
    }
}
