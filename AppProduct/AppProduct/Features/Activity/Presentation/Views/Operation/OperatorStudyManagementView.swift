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

    @State private var showCreateView = false

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

    // MARK: - Constants

    private enum Constants {
        static let permissionTitle: String = "스터디 그룹 관리"
        static let permissionDescription: String = "등록된 스터디 그룹이 없습니다\n스터디 그룹 생성에는 별도 권한이 필요해요"
        static let permissionGuideTitle: String = "스터디 관리가 가능한 역할"
        static let roleChapterLeader: String = "지부장"
        static let rolePresident: String = "회장 / 부회장"
        static let roleOperator: String = "운영진"
        static let roleChapterLeaderDescription: String = "지부 내 전체 학교의 스터디를 관리할 수 있어요"
        static let rolePresidentDescription: String = "소속 학교의 스터디 그룹을 생성·관리할 수 있어요"
        static let roleOperatorDescription: String = "담당 파트의 스터디를 조회할 수 있어요"
    }

    // MARK: - Body

    var body: some View {
        groupManagementContentView
        .task {
            await viewModel.fetchGroupManagementData()
        }
        .toolbar {
            if canCreateStudyGroup {
                ToolBarCollection.AddBtn {
                    showCreateView = true
                }
            }
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
        .sheet(item: $viewModel.editingGroup) { _ in
            OperatorStudyGroupEditSheet(viewModel: viewModel)
        }
        .sheet(
            item: $viewModel.addMentorGroup,
            onDismiss: {
                Task {
                    await viewModel.applySelectedMentors()
                }
            }
        ) { _ in
            SelectedChallengerView(
                challenger: $viewModel.selectedMentors
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

    @ViewBuilder
    private var groupManagementEmptyView: some View {
        if canCreateStudyGroup {
            ContentUnavailableView {
                Label("등록된 스터디 그룹이 없어요", systemImage: "person.3")
            } description: {
                Text("오른쪽 위 + 버튼으로 새 그룹을 만들고\n스터디원과 멘토를 배정해 보세요.")
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
        } else {
            permissionDeniedView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
        }
    }

    private func groupManagementListView(groups: [StudyGroupInfo]) -> some View {
        ScrollView {
            // Apple iOS 26 가이드: 같은 화면에 Liquid Glass가 여러 개 있을 때
            // GlassEffectContainer 로 묶어 카드 사이 morphing/blending + 렌더링 성능 ↑
            GlassEffectContainer(spacing: DefaultSpacing.spacing16) {
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
                            onAddMentor: {
                                viewModel.showAddMentorSheet(for: group)
                            },
                            onSchedule: {
                                let isMentor = group.mentors.contains { mentor in
                                    mentor.challengerID == currentChallengerId
                                }
                                guard isMentor else {
                                    viewModel.alertPrompt = AlertPrompt(
                                        title: "권한 없음",
                                        message: "담당 파트장(멘토)만 일정을 등록할 수 있습니다.",
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
                            },
                            onRemoveMember: { member in
                                Task {
                                    await viewModel.removeMember(member, from: group)
                                }
                            },
                            onRemoveMentor: { mentor in
                                Task {
                                    await viewModel.removeMentor(mentor, from: group)
                                }
                            }
                        )
                        .equatable()
                        .task {
                            await viewModel.loadMoreGroupManagementDataIfNeeded(
                                currentGroupID: group.id
                            )
                        }
                    }

                    if viewModel.isLoadingMoreStudyGroupDetails {
                        ProgressView()
                            .tint(.grey500)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DefaultSpacing.spacing8)
                    }
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

    // MARK: - Permission Denied View

    private var permissionDeniedView: some View {
        ScrollView {
            VStack(spacing: DefaultSpacing.spacing32) {
                ContentUnavailableView {
                    Label(Constants.permissionTitle, systemImage: "person.3")
                } description: {
                    Text(Constants.permissionDescription)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
                    Text(Constants.permissionGuideTitle)
                        .appFont(.calloutEmphasis)

                    permissionRoleRow(
                        icon: "building.columns.fill",
                        role: Constants.roleChapterLeader,
                        description: Constants.roleChapterLeaderDescription
                    )

                    permissionRoleRow(
                        icon: "star.fill",
                        role: Constants.rolePresident,
                        description: Constants.rolePresidentDescription
                    )

                    permissionRoleRow(
                        icon: "person.badge.key.fill",
                        role: Constants.roleOperator,
                        description: Constants.roleOperatorDescription
                    )
                }
                .padding(DefaultSpacing.spacing16)
                .background(.regularMaterial, in: .rect(cornerRadius: DefaultConstant.defaultCornerRadius))
            }
            .padding(.top, DefaultSpacing.spacing32)
        }
    }

    private func permissionRoleRow(icon: String, role: String, description: String) -> some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            Image(systemName: icon)
                .font(.app(.title3))
                .foregroundStyle(.grey600)
                .frame(width: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(role)
                    .appFont(.subheadline)
                Text(description)
                    .appFont(.footnote)
                    .foregroundStyle(.grey500)
            }
        }
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(
        error: AppError,
        retryAction: @escaping () async -> Void
    ) -> some View {
        if error.isPermissionDenied {
            permissionDeniedView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
        } else {
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
