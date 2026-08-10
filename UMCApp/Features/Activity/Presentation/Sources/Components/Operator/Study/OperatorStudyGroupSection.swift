//
//  OperatorStudyGroupSection.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/10/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import SwiftUI
import UMCFoundation

// MARK: - OperatorStudyGroupSection

/// 운영진 스터디 관리의 그룹 관리 섹션
///
/// 제출 현황 섹션과 상태를 공유하지 않고 ViewModel 하나만 함께 보기 때문에, 목록·빈 상태·권한
/// 안내·에러까지 그룹 관리에만 필요한 표현을 이 파일로 모았습니다.
struct OperatorStudyGroupSection: View {

    // MARK: - Property

    let viewModel: OperatorStudyManagementViewModel

    /// 스터디 그룹 생성 권한 보유 여부 — 빈 상태·에러를 권한 안내로 바꿔 그릴지 판단한다.
    let canCreateStudyGroup: Bool

    /// 일정 등록 화면 이동 요청 (권한 확인을 통과한 그룹만 전달)
    let onRegisterSchedule: (StudyGroupInfo) -> Void

    // MARK: - Constants

    private enum Constants {
        static let loadingMessage: String = "스터디 그룹 관리 불러오는 중..."
        static let emptyTitle: String = "등록된 스터디 그룹이 없어요"
        static let emptyDescription: String =
            "스터디 그룹 생성 기능을 준비하고 있어요.\n곧 이곳에서 스터디원과 멘토를 배정할 수 있어요."
        static let errorTitle: String = "불러오지 못했어요"
    }

    // MARK: - Body

    @ViewBuilder
    var body: some View {
        switch viewModel.studyGroupDetailsState {
        case .idle, .loading:
            StudyManagementLoadingView(message: Constants.loadingMessage)

        case .loaded:
            if viewModel.studyGroupDetails.isEmpty {
                emptyView
            } else {
                listView(groups: viewModel.studyGroupDetails)
            }

        case .failed(let error):
            errorView(error: error) {
                await viewModel.fetchGroupManagementData()
            }
        }
    }

    // MARK: - Group List View

    @ViewBuilder
    private var emptyView: some View {
        if canCreateStudyGroup {
            ContentUnavailableView {
                Label(Constants.emptyTitle, systemImage: "person.3")
            } description: {
                Text(Constants.emptyDescription)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
        } else {
            StudyGroupPermissionGuideView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
        }
    }

    private func listView(groups: [StudyGroupInfo]) -> some View {
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
                        StudyManagementLoadMoreIndicator()
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
            StudyGroupPermissionGuideView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
        } else {
            RetryContentUnavailableView(
                title: Constants.errorTitle,
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
