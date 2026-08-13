//
//  ThreadInviteSheet.swift
//  CommunityPresentation
//

import SwiftUI
import CommunityDomain
import CoreDesignSystem
import CoreUIComponents
import UMCFoundation

// MARK: - Constants

fileprivate enum Constants {
    static let navigationTitle = "참여자 초대"
    static let searchPrompt = "이름 검색"
    static let dismissTitle = "취소"
    static let loadFailureTitle = "멤버를 불러오지 못했어요"
    static let emptyTitle = "초대할 수 있는 멤버가 없어요"
    static let emptyDescription = "이미 모두 참여 중이거나 동아리에 다른 멤버가 없어요."
    static let searchEmptyTitle = "검색 결과가 없어요"
    static let capacityFullTitle = "정원이 가득 찼어요"
    static let capacityFullDescription = "참여자가 나가야 새로 초대할 수 있어요."
    static let selectedSectionTitle = "선택한 멤버"
    static let emptyImage = "person.2.slash"
    static let failureImage = "exclamationmark.triangle"
    static let avatarSize = CGSize(width: 40, height: 40)
    /// HIG 최소 탭 타깃.
    static let rowMinHeight: CGFloat = 44
}

/// 초대할 멤버를 고르는 시트 — 이름 검색 + 다중 선택 + 선택 칩.
///
/// 검색 대상은 **동아리 전체**이고 파트·기수 필터는 두지 않는다 (#1131 결정 3). 이미 참여
/// 중인 멤버는 서버(`/invitable`)가 걸러 주므로 화면이 다시 거르지 않는다.
struct ThreadInviteSheet: View {

    // MARK: - Property

    @State private var viewModel: ThreadInviteViewModel

    /// 초대에 성공한 인원 수를 상위에 알린다. 서버는 초대한 쪽에 실시간 이벤트를 보내지 않아
    /// (초대받은 사람만 `thread.invited` 를 받는다) 이 통로가 없으면 멤버 수가 그대로 남는다.
    private let onInvited: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    init(viewModel: ThreadInviteViewModel, onInvited: @escaping (Int) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onInvited = onInvited
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(Constants.navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .umcDefaultBackground()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(Constants.dismissTitle) { dismiss() }
                            .appFont(.body, color: .grey700)
                    }
                }
                .task { await viewModel.load() }
                .onChange(of: viewModel.invitedCount) { _, invitedCount in
                    guard let invitedCount else { return }
                    onInvited(invitedCount)
                    dismiss()
                }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - View Component

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded:
            // 정원이 가득 찬 방은 고를 것이 없다. 목록을 띄워 두고 탭마다 거절하는 대신
            // 사유를 먼저 알린다 (완료 조건 5).
            if viewModel.isCapacityFull {
                capacityFullView
            } else {
                picker
            }

        case .failed(let error):
            RetryContentUnavailableView(
                title: Constants.loadFailureTitle,
                systemImage: Constants.failureImage,
                description: error.userMessage,
                isRetrying: false
            ) {
                await viewModel.load()
            }
        }
    }

    private var picker: some View {
        candidateList
            .searchable(text: $viewModel.searchText, prompt: Constants.searchPrompt)
            .safeAreaInset(edge: .bottom) { submitBar }
    }

    @ViewBuilder
    private var candidateList: some View {
        if viewModel.candidates.isEmpty {
            ContentUnavailableView(
                Constants.emptyTitle,
                systemImage: Constants.emptyImage,
                description: Text(Constants.emptyDescription)
            )
        } else {
            List {
                if !viewModel.selectedMembers.isEmpty {
                    Section(Constants.selectedSectionTitle) { selectedChips }
                }

                Section("동아리 멤버 \(viewModel.filteredCandidates.count)명") {
                    if viewModel.filteredCandidates.isEmpty {
                        Text(Constants.searchEmptyTitle)
                            .appFont(.footnote, color: .grey600)
                    }

                    ForEach(viewModel.filteredCandidates) { member in
                        candidateRow(member)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    /// 고른 사람을 한 줄로 되짚어 준다. 검색어를 바꾸면 목록에서 사라지므로 이 줄이 없으면
    /// 누구를 골랐는지 확인할 방법이 없다.
    private var selectedChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DefaultSpacing.spacing8) {
                ForEach(viewModel.selectedMembers) { member in
                    ChipButton(member.name, isSelected: true) {
                        viewModel.toggle(member)
                    }
                    .buttonSize(.small)
                    .accessibilityLabel("\(member.name) 선택 해제")
                }
            }
            .padding(.vertical, DefaultSpacing.spacing4)
        }
        .scrollIndicators(.hidden)
    }

    private func candidateRow(_ member: ThreadMember) -> some View {
        let isSelected = viewModel.isSelected(member)

        return Button {
            viewModel.toggle(member)
        } label: {
            HStack(spacing: DefaultSpacing.spacing12) {
                RemoteImage(
                    urlString: member.profileImageURL ?? "",
                    size: Constants.avatarSize
                )

                VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                    Text(member.name)
                        .appFont(.subheadline, weight: .semibold, color: .grey900)
                        .lineLimit(1)

                    if let part = member.part, !part.isEmpty {
                        Text(part)
                            .appFont(.caption1, color: .grey600)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: DefaultSpacing.spacing8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.indigo500 : Color.grey400)
            }
            .frame(minHeight: Constants.rowMinHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var capacityFullView: some View {
        ContentUnavailableView(
            Constants.capacityFullTitle,
            systemImage: Constants.emptyImage,
            description: Text(Constants.capacityFullDescription)
        )
    }

    /// 선택 인원 · 거절 사유 · 전송 버튼. 한 명도 고르지 않으면 보낼 것이 없어 잠가 둔다
    /// (서버도 빈 배열을 400 으로 거절한다).
    private var submitBar: some View {
        VStack(spacing: DefaultSpacing.spacing8) {
            if let notice = viewModel.capacityNotice {
                noticeLabel(notice, color: .grey700)
            }

            if let error = viewModel.submitState.error {
                noticeLabel(error.userMessage, color: .red500)
            }

            MainButton(submitTitle) {
                Task { await viewModel.invite() }
            }
            .buttonSize(.large)
            .buttonStyle(.glassProminent)
            .disabled(!viewModel.canSubmit)
        }
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .padding(.vertical, DefaultSpacing.spacing12)
        .background(.bar)
    }

    private func noticeLabel(_ message: String, color: Color) -> some View {
        Text(message)
            .appFont(.footnote, color: color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Computed Property

    private var submitTitle: String {
        viewModel.selectedCount > 0 ? "\(viewModel.selectedCount)명 초대하기" : "초대하기"
    }
}
