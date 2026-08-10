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
///
/// 본문은 성격이 다른 두 섹션(``OperatorStudyGroupSection`` / ``OperatorStudySubmissionSection``)이
/// 맡고, 이 화면은 섹션 전환과 두 섹션에 걸친 툴바·시트·알럿만 관리합니다.
struct OperatorStudyManagementView: View {

    // MARK: - Property

    @State private var viewModel: OperatorStudyManagementViewModel

    private let userSession: UserSessionManager

    /// 스터디 그룹 생성 화면 push 여부
    @State private var showsGroupCreate = false

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
        static let sectionPickerTitle: String = "스터디 관리 섹션"
        static let workbookUnavailableTitle: String = "준비 중"
        static let workbookUnavailableMessage: String = "워크북 상세 화면은 커리큘럼 상세 이식 후 연결됩니다."
        static let confirmTitle: String = "확인"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            sectionPicker

            switch selectedSection {
            case .groups:
                OperatorStudyGroupSection(
                    viewModel: viewModel,
                    canCreateStudyGroup: canCreateStudyGroup,
                    onRegisterSchedule: onRegisterSchedule
                )
            case .submissions:
                OperatorStudySubmissionSection(viewModel: viewModel) {
                    showWorkbookDetailUnavailable = true
                }
            }
        }
            .task {
                await viewModel.fetchGroupManagementData()
            }
            .toolbar {
                if canCreateStudyGroup && selectedSection == .groups {
                    ToolBarCollection.AddBtn(action: {
                        showsGroupCreate = true
                    })
                }
            }
            // 생성 폼은 같은 ViewModel 을 그대로 쓴다. 생성 성공 시 낙관적 삽입과 백그라운드
            // 재조회가 이 화면의 목록 상태에 바로 반영되게 하려면 인스턴스가 하나여야 한다.
            .navigationDestination(isPresented: $showsGroupCreate) {
                OperatorStudyGroupCreateView(viewModel: viewModel)
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
            .alert(
                Constants.workbookUnavailableTitle,
                isPresented: $showWorkbookDetailUnavailable
            ) {
                Button(Constants.confirmTitle, role: .cancel) {}
            } message: {
                Text(Constants.workbookUnavailableMessage)
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
