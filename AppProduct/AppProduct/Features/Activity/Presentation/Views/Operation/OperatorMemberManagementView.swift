//
//  OperatorMemberManagementView.swift
//  AppProduct
//
//  Created by 이예지 on 2/16/26.
//

import SwiftUI

/// Admin 모드의 멤버 관리 섹션
///
/// 운영진이 동아리 멤버를 관리하는 화면입니다.
struct OperatorMemberManagementView: View {

    // MARK: - Property

    @State private var viewModel: MemberListViewModel

    // MARK: - Initializer

    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        userSessionManager: UserSessionManager
    ) {
        let useCaseProvider = container.resolve(ActivityUseCaseProviding.self)
        let memberListViewModel = MemberListViewModel(
            fetchMembersUseCase: useCaseProvider.fetchMembersUseCase,
            errorHandler: errorHandler,
            userSessionManager: userSessionManager
        )
        self._viewModel = .init(wrappedValue: memberListViewModel)
    }

    // MARK: - Body
    var body: some View {

        Group {
            switch viewModel.membersState {
            case .idle, .loading:
                loadingView
            case .loaded:
                memberListContent
            case .failed(let error):
                RetryContentUnavailableView(
                    title: "불러오지 못했어요",
                    systemImage: "exclamationmark.triangle",
                    description: error.userMessage,
                    isRetrying: false
                ) {
                    await viewModel.fetchMembers()
                }
            }
        }
        .task {
            await viewModel.fetchMembers()
        }
        .searchable(text: $viewModel.searchText)
        .searchToolbarBehavior(.minimize)
        .overlay {
            if viewModel.isLoadingMemberDetail {
                ProgressView()
                    .controlSize(.regular)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .sheet(item: $viewModel.selectedMember) { member in
            OperatorMemberDetailSheetView(
                member: member,
                availablePointTypes: viewModel.availablePointTypes,
                isSubmittingPoint: viewModel.isSubmittingPoint,
                isDeletingPoint: viewModel.isDeletingPoint,
                onGrantPoint: { pointType, pointValue, description in
                    await viewModel.submitPoint(
                        member: member,
                        pointType: pointType,
                        pointValue: pointValue,
                        description: description
                    )
                },
                onDeletePoint: { history in
                    await viewModel.deletePoint(
                        member: member,
                        history: history
                    )
                }
            )
        }
        .alertPrompt(item: $viewModel.alertPrompt)
    }

    // MARK: - SubView

    private var loadingView: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            ProgressView()

            Text("챌린저 목록 불러오는 중...")
                .appFont(.subheadline, color: .grey500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var memberListContent: some View {
        Group {
            if viewModel.groupedMembers.isEmpty && viewModel.searchText.isEmpty {
                emptyMemberView
            } else if viewModel.isSearchResultEmpty {
                searchEmptyView
            } else {
                memberList
            }
        }
    }

    private var memberList: some View {
        List {
            ForEach(viewModel.groupedMembers, id: \.part) { group in
                Section {
                    ForEach(group.members) { item in
                        Button(action: {
                            Task {
                                await viewModel.openChallengerMemberDetail(item)
                            }
                        }) {
                            CoreMemberManagementList(memberManagementItem: item, mode: .management)
                        }
                    }
                } header: {
                    Text(group.part.name)
                        .appFont(.title3Emphasis, color: .black)
                }
            }
        }
    }

    private var searchEmptyView: some View {
        ContentUnavailableView {
            Label("검색 결과가 없습니다.", systemImage: "magnifyingglass")
        } description: {
            Text("'\(viewModel.searchText)'에 대한 결과가 없습니다")
        }
    }

    private var emptyMemberView: some View {
        ContentUnavailableView {
            Label("멤버 관리", systemImage: "person.3")
        } description: {
            Text("등록된 멤버가 없습니다")
        }
    }
}
#if DEBUG
#Preview {
    OperatorMemberManagementView(
        container: MissionPreviewData.container,
        errorHandler: MissionPreviewData.errorHandler,
        userSessionManager: UserSessionManager()
    )
}
#endif
