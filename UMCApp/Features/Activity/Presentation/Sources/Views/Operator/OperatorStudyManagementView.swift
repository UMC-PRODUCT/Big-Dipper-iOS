//
//  OperatorStudyManagementView.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/15/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreDomain
import CoreUIComponents
import SwiftUI
import UMCFoundation

/// Admin 모드의 스터디 관리 섹션
///
/// 운영진이 스터디와 활동을 관리하는 화면입니다.
/// ViewModel 과 세션은 상위(라우터/루트 화면)에서 주입받습니다.
struct OperatorStudyManagementView: View {

    // MARK: - Property

    @State private var viewModel: OperatorStudyManagementViewModel

    private let userSession: UserSessionManager

    /// 스터디 그룹 생성 미결선 안내 표시 여부
    ///
    /// 생성 폼(`OperatorStudyGroupCreateView`)은 이식 완료됐으나, 멘토·스터디원 선택이
    /// 미이식 상태인 챌린저 검색에 의존해 저장을 완료할 수 없다. 검색 서브시스템 이식 전까지
    /// 진입점(+ 버튼)을 게이팅하고 안내만 표시한다. 이식 후 생성 폼 네비게이션을 복원한다.
    @State private var showCreateUnavailable = false

    /// 일정 등록 화면으로 이동을 상위(Activity 탭 루트)에 위임하는 콜백.
    ///
    /// 이 화면은 "어느 그룹의 일정을 등록하려 한다"까지만 알고, 그것을 어떤 경로로 띄울지는
    /// 탭 루트가 정한다. 그래야 이 화면이 라우팅 세부를 몰라도 되고 프리뷰에서도 그대로 뜬다.
    private let onRegisterSchedule: (StudyGroupInfo) -> Void

    // MARK: - Initializer

    /// - Parameters:
    ///   - viewModel: 운영진 스터디 관리 ViewModel
    ///   - userSession: 앱 전역 세션(스터디 그룹 생성 권한 확인용)
    ///   - onRegisterSchedule: 일정 등록 화면 이동 요청 (권한 확인을 통과한 그룹만 전달)
    init(
        viewModel: OperatorStudyManagementViewModel,
        userSession: UserSessionManager,
        onRegisterSchedule: @escaping (StudyGroupInfo) -> Void
    ) {
        _viewModel = State(wrappedValue: viewModel)
        self.userSession = userSession
        self.onRegisterSchedule = onRegisterSchedule
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
                    ToolBarCollection.AddBtn(action: {
                        showCreateUnavailable = true
                    })
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
            .alertPrompt(item: $viewModel.alertPrompt)
            .alert("준비 중", isPresented: $showCreateUnavailable) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("스터디 그룹 생성은 챌린저 검색 이식 후 연결됩니다.")
            }
    }

    // MARK: - Function

    /// 스터디 그룹 생성 권한 확인 (보유 역할 중 회장/부회장 포함 여부)
    private var canCreateStudyGroup: Bool {
        userSession.hasAnyRole(where: { $0.canCreateStudyGroup })
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
                Text("스터디 그룹 생성 기능을 준비하고 있어요.\n곧 이곳에서 스터디원과 멘토를 배정할 수 있어요.")
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
                                Task { await viewModel.deleteGroup(group) }
                            },
                            onAddMember: {
                                viewModel.showAddMemberSheet(for: group)
                            },
                            onAddMentor: {
                                viewModel.showAddMentorSheet(for: group)
                            },
                            onSchedule: {
                                guard viewModel.canRegisterSchedule(for: group) else {
                                    viewModel.presentScheduleRegistrationDenied()
                                    return
                                }
                                onRegisterSchedule(group)
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
                            .tint(Color.grey500)
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
                .tint(Color.grey500)

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
                        .appFont(.callout, weight: .semibold)

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
                .background(
                    .regularMaterial,
                    in: .rect(cornerRadius: DefaultConstant.defaultCornerRadius)
                )
            }
            .padding(.top, DefaultSpacing.spacing32)
        }
    }

    private func permissionRoleRow(
        icon: String,
        role: String,
        description: String
    ) -> some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            Image(systemName: icon)
                .font(.app(.title3))
                .foregroundStyle(Color.grey600)
                .frame(width: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(role)
                    .appFont(.subheadline)
                Text(description)
                    .appFont(.footnote)
                    .foregroundStyle(Color.grey500)
            }
        }
    }

    // MARK: - Error View

    /// 로딩 실패 처리.
    ///
    /// 레거시는 `AppError.isPermissionDenied`(403)로 권한 안내 분기를 판단했으나 이식된
    /// `AppError` 에는 해당 프로퍼티가 없다. 권한 안내의 의도(생성 권한 없는 사용자에게 역할
    /// 가이드 노출)를 세션 권한(`canCreateStudyGroup`)으로 대신 판단한다.
    @ViewBuilder
    private func errorView(
        error: AppError,
        retryAction: @escaping () async -> Void
    ) -> some View {
        if !canCreateStudyGroup {
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
#Preview("스터디 관리 · 목록") {
    NavigationStack {
        OperatorStudyManagementView(
            viewModel: previewOperatorStudyManagementViewModel(),
            userSession: previewCreateCapableSession(),
            onRegisterSchedule: { _ in }
        )
    }
}

#Preview("스터디 관리 · 빈 목록") {
    NavigationStack {
        OperatorStudyManagementView(
            viewModel: previewOperatorStudyManagementViewModel(
                outcome: .page(OperatorStudyPreviewData.emptyPage)
            ),
            userSession: previewCreateCapableSession(),
            onRegisterSchedule: { _ in }
        )
    }
}

#Preview("스터디 관리 · 권한 없음") {
    NavigationStack {
        OperatorStudyManagementView(
            viewModel: previewOperatorStudyManagementViewModel(
                outcome: .page(OperatorStudyPreviewData.emptyPage)
            ),
            userSession: previewChallengerSession(),
            onRegisterSchedule: { _ in }
        )
    }
}

#Preview("스터디 관리 · 에러") {
    NavigationStack {
        OperatorStudyManagementView(
            viewModel: previewOperatorStudyManagementViewModel(
                outcome: .failure(PreviewSampleError.failed)
            ),
            userSession: previewCreateCapableSession(),
            onRegisterSchedule: { _ in }
        )
    }
}
#endif
