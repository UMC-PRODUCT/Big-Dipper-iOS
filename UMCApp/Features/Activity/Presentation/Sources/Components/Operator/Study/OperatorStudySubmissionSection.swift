//
//  OperatorStudySubmissionSection.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/10/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import SwiftUI

// MARK: - OperatorStudySubmissionSection

/// 운영진 스터디 관리의 제출 현황 섹션
///
/// 그룹·주차 필터와 제출 현황 목록은 그룹 관리와 상태를 공유하지 않아, 워크북 상세 결선 같은
/// 후속 작업이 그룹 관리 코드와 섞이지 않도록 이 파일로 떼어냈습니다.
struct OperatorStudySubmissionSection: View {

    // MARK: - Property

    let viewModel: OperatorStudyManagementViewModel

    /// 워크북 상세 진입 요청 — 상세 화면이 미이식이라 안내 알럿은 상위(셸)가 띄운다.
    let onSelectWorkbook: () -> Void

    // MARK: - Constants

    private enum Constants {
        static let allGroupsFilterTitle: String = "전체 그룹"
        static let loadingMessage: String = "제출 현황 불러오는 중..."
        static let idleTitle: String = "제출 현황을 불러올 준비가 됐어요"
        static let idleDescription: String = "아래 버튼을 눌러 불러올 수 있어요."
        static let emptyTitle: String = "제출 현황이 없어요"
        static let emptyDescription: String =
            "선택한 조건에 해당하는 스터디원이 없어요.\n그룹이나 주차 필터를 바꿔보세요."
        static let errorTitle: String = "불러오지 못했어요"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            filterBar

            switch viewModel.submissionsState {
            // `.idle` 을 스피너로 그리지 않는다. 조회가 취소되면 이 상태로 되돌아오는데,
            // 그때 in-flight 가 없으므로 스피너는 영원히 돌기만 한다. 재시도 수단을 준다.
            case .idle:
                retryView(
                    title: Constants.idleTitle,
                    systemImage: "doc.text.magnifyingglass",
                    description: Constants.idleDescription
                )

            case .loading:
                StudyManagementLoadingView(message: Constants.loadingMessage)

            case .loaded(let rows):
                if rows.isEmpty {
                    emptyView
                } else {
                    listView(rows: rows)
                }

            case .failed(let error):
                retryView(
                    title: Constants.errorTitle,
                    systemImage: "exclamationmark.triangle",
                    description: error.userMessage
                )
            }
        }
        .task {
            await viewModel.fetchSubmissions()
        }
    }

    // MARK: - Filter Bar

    /// 그룹·주차 필터 — 서버가 두 필터를 모두 선택 파라미터로 받는다.
    private var filterBar: some View {
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

    // MARK: - Submission List View

    private var emptyView: some View {
        ContentUnavailableView {
            Label(Constants.emptyTitle, systemImage: "doc.text.magnifyingglass")
        } description: {
            Text(Constants.emptyDescription)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }

    private func listView(rows: [StudyMemberSubmission]) -> some View {
        ScrollView {
            // 카드마다 Liquid Glass 를 쓰므로 Container 로 묶어 렌더링 비용을 줄인다.
            GlassEffectContainer(spacing: DefaultSpacing.spacing16) {
                LazyVStack(spacing: DefaultSpacing.spacing16) {
                    ForEach(rows) { submission in
                        StudyManagementCard(submission: submission) { _ in
                            // TODO: 워크북 상세(WORKBOOK-102) 진입 결선 - [26.08.03] 이재원
                            //  — 상세 화면이 미이식이라 진입은 보류하고 안내만 표시한다.
                            onSelectWorkbook()
                        }
                        .task {
                            await viewModel.loadMoreSubmissionsIfNeeded(
                                currentMemberID: submission.studyGroupMemberId
                            )
                        }
                    }

                    if viewModel.isLoadingMoreSubmissions {
                        StudyManagementLoadMoreIndicator()
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

    // MARK: - Retry View

    private func retryView(
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
}
