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

    /// 현재 보고 있는 섹션 (그룹 관리 / 제출 현황)
    @State private var selectedSection: ManagementSection = .groups

    /// 워크북 상세 미결선 안내 표시 여부
    ///
    /// 제출 현황에서 워크북 상세(`WORKBOOK-102`)로 이동해야 하나 상세 화면이 아직 미이식이라
    /// 진입을 보류하고 안내만 표시한다.
    @State private var showWorkbookDetailUnavailable = false

    // MARK: - Section

    /// 운영진 스터디 관리 화면의 섹션
    private enum ManagementSection: String, CaseIterable, Identifiable {
        case groups = "그룹 관리"
        case submissions = "제출 현황"

        var id: String { rawValue }
    }

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
        static let sectionPickerTitle: String = "스터디 관리 섹션"
        static let allGroupsFilterTitle: String = "전체 그룹"
        static let submissionLoadingMessage: String = "제출 현황 불러오는 중..."
        static let submissionIdleTitle: String = "제출 현황을 불러올 준비가 됐어요"
        static let submissionIdleDescription: String = "아래 버튼을 눌러 불러올 수 있어요."
        static let submissionEmptyDescription: String =
            "선택한 조건에 해당하는 스터디원이 없어요.\n그룹이나 주차 필터를 바꿔보세요."
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            sectionPicker

            switch selectedSection {
            case .groups:
                groupManagementContentView
            case .submissions:
                submissionContentView
            }
        }
            .task {
                await viewModel.fetchGroupManagementData()
            }
            .toolbar {
                if canCreateStudyGroup && selectedSection == .groups {
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
            .alert("준비 중", isPresented: $showWorkbookDetailUnavailable) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("워크북 상세 화면은 커리큘럼 상세 이식 후 연결됩니다.")
            }
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        Picker(Constants.sectionPickerTitle, selection: $selectedSection) {
            ForEach(ManagementSection.allCases) { section in
                Text(section.rawValue).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
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

    // MARK: - Submission View

    /// 제출 현황 섹션 — 필터 + 상태별 본문
    private var submissionContentView: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            submissionFilterBar

            switch viewModel.submissionsState {
            // `.idle` 을 스피너로 그리지 않는다. 조회가 취소되면 이 상태로 되돌아오는데,
            // 그때 in-flight 가 없으므로 스피너는 영원히 돌기만 한다. 재시도 수단을 준다.
            case .idle:
                submissionRetryView(
                    title: Constants.submissionIdleTitle,
                    systemImage: "doc.text.magnifyingglass",
                    description: Constants.submissionIdleDescription
                )

            case .loading:
                loadingView(message: Constants.submissionLoadingMessage)

            case .loaded(let rows):
                if rows.isEmpty {
                    submissionEmptyView
                } else {
                    submissionListView(rows: rows)
                }

            case .failed(let error):
                submissionRetryView(
                    title: "불러오지 못했어요",
                    systemImage: "exclamationmark.triangle",
                    description: error.userMessage
                )
            }
        }
        .task {
            await viewModel.fetchSubmissions()
        }
    }

    private func submissionRetryView(
        title: String,
        systemImage: String,
        description: String
    ) -> some View {
        RetryContentUnavailableView(
            title: title,
            systemImage: systemImage,
            description: description,
            isRetrying: false,
            topPadding: DefaultSpacing.spacing32
        ) {
            await viewModel.retrySubmissions()
        }
        .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }

    /// 그룹·주차 필터 — 서버가 두 필터를 모두 선택 파라미터로 받는다.
    private var submissionFilterBar: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            // ChipButton 의 buttonSize/buttonStyle 은 `AnyChipButton` 전용이라 둘을 이어 붙일 수
            // 없다(첫 모디파이어가 `some View` 를 돌려줌). 두 값 모두 Environment 로 전달한다.
            ScrollView(.horizontal) {
                HStack(spacing: DefaultSpacing.spacing8) {
                    ChipButton(
                        Constants.allGroupsFilterTitle,
                        isSelected: viewModel.selectedSubmissionGroupId == nil
                    ) {
                        Task { await viewModel.selectSubmissionGroup(nil) }
                    }

                    ForEach(viewModel.studyGroupNames) { group in
                        ChipButton(
                            group.name,
                            isSelected: viewModel.selectedSubmissionGroupId == group.groupId
                        ) {
                            Task { await viewModel.selectSubmissionGroup(group.groupId) }
                        }
                    }
                }
                .environment(\.chipButtonSize, .small)
                .environment(\.chipButtonStyle, .filter)
                .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
            }
            .scrollIndicators(.hidden)

            if !viewModel.availableSubmissionWeekNos.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: DefaultSpacing.spacing8) {
                        ForEach(viewModel.availableSubmissionWeekNos, id: \.self) { weekNo in
                            ChipButton(
                                "\(weekNo)주차",
                                isSelected: viewModel.selectedSubmissionWeekNos
                                    .contains(weekNo)
                            ) {
                                Task { await viewModel.toggleSubmissionWeek(weekNo) }
                            }
                        }
                    }
                    .environment(\.chipButtonSize, .small)
                    .environment(\.chipButtonStyle, .fame)
                    .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var submissionEmptyView: some View {
        ContentUnavailableView {
            Label("제출 현황이 없어요", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text(Constants.submissionEmptyDescription)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }

    private func submissionListView(rows: [StudyMemberSubmission]) -> some View {
        ScrollView {
            // 카드마다 Liquid Glass 를 쓰므로 Container 로 묶어 렌더링 비용을 줄인다.
            GlassEffectContainer(spacing: DefaultSpacing.spacing16) {
                LazyVStack(spacing: DefaultSpacing.spacing16) {
                    ForEach(rows) { submission in
                        StudyManagementCard(submission: submission) { _ in
                            // TODO: 워크북 상세(WORKBOOK-102) 진입 결선 - [26.08.03] 이재원
                            //  — 상세 화면이 미이식이라 진입은 보류하고 안내만 표시한다.
                            showWorkbookDetailUnavailable = true
                        }
                        .task {
                            await viewModel.loadMoreSubmissionsIfNeeded(
                                currentMemberID: submission.studyGroupMemberId
                            )
                        }
                    }

                    if viewModel.isLoadingMoreSubmissions {
                        ProgressView()
                            .tint(Color.grey500)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DefaultSpacing.spacing8)
                    }
                }
            }
            .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeBtnPadding)
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

#Preview("스터디 관리 · 제출 현황") {
    NavigationStack {
        OperatorStudyManagementView(
            viewModel: previewOperatorStudyManagementViewModel(),
            userSession: previewCreateCapableSession(),
            onRegisterSchedule: { _ in }
        )
    }
}

#Preview("스터디 관리 · 제출 현황 빈 목록") {
    NavigationStack {
        OperatorStudyManagementView(
            viewModel: previewOperatorStudyManagementViewModel(
                submissionOutcome: .page(OperatorStudyPreviewData.emptySubmissionPage)
            ),
            userSession: previewCreateCapableSession(),
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
