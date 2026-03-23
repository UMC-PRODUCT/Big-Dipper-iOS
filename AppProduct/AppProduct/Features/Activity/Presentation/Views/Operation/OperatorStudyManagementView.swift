//
//  OperatorStudyManagementView.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/23/26.
//

import SwiftUI

/// Admin 모드의 스터디 관리 섹션
///
/// 운영진이 스터디와 활동을 관리하는 화면입니다.
struct OperatorStudyManagementView: View {

    // MARK: - Property

    @State private var viewModel: OperatorStudyManagementViewModel

    private let container: DIContainer
    private let errorHandler: ErrorHandler

    private var pathStore: PathStore {
        container.resolve(PathStore.self)
    }

    private var userSession: UserSessionManager {
        container.resolve(UserSessionManager.self)
    }

    @AppStorage(AppStorageKey.organizationType)
    private var organizationType: String = ""

    @AppStorage(AppStorageKey.challengerId)
    private var currentChallengerId: Int = 0

    @State private var selectedTab: ManagementTab = .submission
    @State private var showCreateView = false

    /// 관리 화면 탭 구분
    private enum ManagementTab: Int, CaseIterable {
        case submission
        case groupManagement

        /// 탭 표시 제목
        var title: String {
            switch self {
            case .submission: "제출 현황"
            case .groupManagement: "스터디 그룹 관리"
            }
        }
    }

    // MARK: - Initializer

    /// - Parameters:
    ///   - container: 의존성 주입 컨테이너
    ///   - errorHandler: 전역 에러 핸들러
    init(container: DIContainer, errorHandler: ErrorHandler) {
        self.container = container
        self.errorHandler = errorHandler

        let useCase = container
            .resolve(ActivityUseCaseProviding.self)
            .fetchStudyMembersUseCase
        let studyManagementViewModel = OperatorStudyManagementViewModel(
            container: container,
            errorHandler: errorHandler,
            useCase: useCase
        )
        _viewModel = State(initialValue: studyManagementViewModel)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Picker("관리", selection: $selectedTab) {
                ForEach(ManagementTab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
            .padding(.vertical, DefaultSpacing.spacing8)

            switch selectedTab {
            case .submission:
                submissionContentView

            case .groupManagement:
                groupManagementContentView
            }
        }
        .task(id: selectedTab) {
            if selectedTab == .submission {
                await viewModel.fetchSubmissionMembers()
            } else {
                await viewModel.fetchGroupManagementData()
            }
        }
        .toolbar {
            if selectedTab == .submission {
                ToolBarCollection.StudyWeekFilter(
                    weeks: viewModel.weeks,
                    selection: $viewModel.selectedWeek,
                    onChange: viewModel.selectWeek
                )
                ToolBarCollection.StudyGroupFilter(
                    studyGroups: viewModel.studyGroups,
                    selection: $viewModel.selectedStudyGroup,
                    onChange: viewModel.selectStudyGroup
                )
            } else if canCreateStudyGroup {
                ToolBarCollection.AddBtn {
                    showCreateView = true
                }
            }
        }
        .sheet(
            item: $viewModel.selectedMemberForReview,
            onDismiss: { viewModel.presentPendingAlert() }
        ) { member in
            OperatorStudyReviewSheet(
                member: member,
                onApprove: { feedback in
                    await viewModel.submitReviewApproval(
                        member: member,
                        feedback: feedback
                    )
                },
                onReject: { feedback in
                    await viewModel.submitReviewRejection(
                        member: member,
                        feedback: feedback
                    )
                }
            )
        }
        .sheet(
            item: $viewModel.selectedMemberForBest,
            onDismiss: { viewModel.presentPendingAlert() }
        ) { member in
            OperatorBestWorkbookSheet(
                member: member,
                onSelect: { recommendation in
                    await viewModel.submitBestWorkbookSelection(
                        member: member,
                        recommendation: recommendation
                    )
                }
            )
        }
        .sheet(
            item: $viewModel.addMemberGroup,
            onDismiss: {
                Task {
                    await viewModel.applySelectedChallengers()
                }
            }
        ) { _ in
            SelectedChallengerView(
                challenger: $viewModel.selectedChallengers
            )
        }
        .sheet(item: $viewModel.editingGroup) { group in
            OperatorStudyGroupEditSheet(
                detail: group,
                onSave: { name, part in
                    await viewModel.updateGroup(
                        groupID: group.id,
                        name: name,
                        part: part
                    )
                }
            )
        }
        .navigationDestination(isPresented: $showCreateView) {
            OperatorStudyGroupCreateView(viewModel: viewModel)
        }
        .alertPrompt(item: $viewModel.alertPrompt)
    }

    // MARK: - Function

    /// 스터디 그룹 생성 권한 확인 (보유 역할 중 회장/부회장 포함 여부)
    private var canCreateStudyGroup: Bool {
        userSession.hasAnyRole { $0.canCreateStudyGroup }
    }

    // MARK: - Submission Content View

    @ViewBuilder
    private var submissionContentView: some View {
        switch viewModel.membersState {
        case .idle, .loading:
            loadingView(message: "제출 현황 불러오는 중...")

        case .loaded(let members):
            if members.isEmpty {
                emptyView
            } else {
                memberListView(members: members)
            }

        case .failed(let error):
            errorView(error: error)
        }
    }

    // MARK: - Group Management View

    @ViewBuilder
    private var groupManagementContentView: some View {
        switch viewModel.studyGroupDetailsState {
        case .idle, .loading:
            loadingView(message: "스터디 그룹 관리 불러오는 중...")

        case .loaded:
            if viewModel.studyGroupDetails.isEmpty {
                groupManagementEmptyView
            } else {
                groupManagementListView(groups: viewModel.studyGroupDetails)
            }

        case .failed(let error):
            errorView(error: error) {
                await viewModel.fetchGroupManagementData()
            }
        }
    }

    private var groupManagementEmptyView: some View {
        emptyContentView(
            title: "스터디 그룹 관리",
            message: "등록된 스터디 그룹이 없습니다"
        )
    }

    private func groupManagementListView(groups: [StudyGroupInfo]) -> some View {
        ScrollView {
            LazyVStack(spacing: DefaultSpacing.spacing16) {
                ForEach(groups) { group in
                    StudyGroupCard(
                        detail: group,
                        onEdit: {
                            viewModel.showEditSheet(for: group)
                        },
                        onDelete: {
                            viewModel.deleteGroup(group)
                        },
                        onAddMember: {
                            viewModel.showAddMemberSheet(
                                for: group
                            )
                        },
                        onSchedule: {
                            guard group.leader.challengerID == currentChallengerId else {
                                viewModel.alertPrompt = AlertPrompt(
                                    title: "권한 없음",
                                    message: "그룹 리더만 일정을 등록할 수 있습니다.",
                                    positiveBtnTitle: "확인"
                                )
                                return
                            }
                            guard let studyGroupId = Int(group.serverID) else {
                                return
                            }
                            pathStore.activityPath.append(
                                .activity(
                                    .studyScheduleRegistration(
                                        studyName: group.name,
                                        studyGroupId: studyGroupId
                                    )
                                )
                            )
                        }
                    )
                    .equatable()
                    .onAppear {
                        Task {
                            await viewModel.loadMoreGroupManagementDataIfNeeded(
                                currentGroupID: group.id
                            )
                        }
                    }
                }

                if viewModel.isLoadingMoreStudyGroupDetails {
                    ProgressView()
                        .tint(.grey500)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DefaultSpacing.spacing8)
                }
            }
            .safeAreaPadding(
                .horizontal,
                DefaultConstant.defaultSafeBtnPadding
            )
        }
        .contentMargins(
            .bottom,
            DefaultConstant.defaultContentBottomMargins,
            for: .scrollContent
        )
    }

    // MARK: - Loading View

    private func loadingView(message: String) -> some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            ProgressView()
                .controlSize(.large)
                .tint(.grey500)

            Text(message)
                .appFont(.subheadline, color: .grey500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        emptyContentView(
            title: "제출 현황 관리",
            message: "과제를 제출한 스터디원이 없습니다."
        )
    }

    private func emptyContentView(
        title: String,
        message: String
    ) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: "person.3")
        } description: {
            Text(message)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }

    // MARK: - Member List View

    private func memberListView(members: [StudyMemberItem]) -> some View {
        List {
            ForEach(members) { member in
                OperatorStudyMemberCard(member: member)
                    .equatable()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(
                        top: DefaultSpacing.spacing4,
                        leading: DefaultConstant.defaultSafeHorizon,
                        bottom: DefaultSpacing.spacing4,
                        trailing: DefaultConstant.defaultSafeHorizon
                    ))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            viewModel.openReviewSheet(for: member)
                        } label: {
                            Label("검토", systemImage: "checkmark.circle.fill")
                        }
                        .tint(.indigo500)

                        Button {
                            if viewModel.isBestSelectionDisabled(for: member) {
                                viewModel.showBestSelectionDisabledAlert()
                            } else {
                                viewModel.selectedMemberForBest = member
                            }
                        } label: {
                            Label("베스트", systemImage: "trophy")
                        }
                        .tint(
                            viewModel.isBestSelectionDisabled(for: member) ? .gray : .orange
                        )
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, DefaultConstant.defaultContentBottomMargins, for: .scrollContent)
    }

    // MARK: - Error View

    private func errorView(error: AppError) -> some View {
        errorView(error: error) {
            await viewModel.fetchSubmissionMembers()
        }
    }

    private func errorView(
        error: AppError,
        retryAction: @escaping () async -> Void
    ) -> some View {
            RetryContentUnavailableView(
                title: "불러오지 못했어요",
                systemImage: "exclamationmark.triangle",
                description: error.userMessage,
                isRetrying: false,
                topPadding: DefaultSpacing.spacing32
            ) {
                await retryAction()
            }
            .safeAreaPadding(
                .horizontal,
                DefaultConstant.defaultSafeHorizon
            )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        OperatorStudyManagementView(
            container: AttendancePreviewData.container,
            errorHandler: AttendancePreviewData.errorHandler
        )
    }
}
#endif
