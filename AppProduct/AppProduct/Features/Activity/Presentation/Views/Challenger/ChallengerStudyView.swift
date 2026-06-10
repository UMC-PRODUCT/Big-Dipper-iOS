//
//  ChallengerStudyView.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/23/26.
//

import SwiftUI

/// Challenger 모드의 스터디/활동 섹션
///
/// 참여 중인 스터디와 활동 목록을 표시합니다.
struct ChallengerStudyView: View {

    // MARK: - Property

    @State private var viewModel: ChallengerStudyViewModel
    
    // MARK: - Init
    
    init(
        container: DIContainer,
        errorHandler: ErrorHandler
    ) {
        let activityProvider = container.resolve(ActivityUseCaseProviding.self)
        let challengerStudyViewModel = ChallengerStudyViewModel(
            fetchCurriculumUseCase: activityProvider.fetchCurriculumUseCase,
            errorHandler: errorHandler
        )
        self._viewModel = .init(wrappedValue: challengerStudyViewModel)
    }

    // MARK: - Body

    var body: some View {
        Group {
            contentView(viewModel: viewModel)
        }
        .task {
            await viewModel.fetchCurriculum()
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private func contentView(viewModel: ChallengerStudyViewModel) -> some View {
        switch viewModel.curriculumState {
        case .idle, .loading:
            loadingView

        case .loaded(let data):
            // 커리큘럼은 조회됐지만 등록된 주차가 없어 표시할 미션이 없는 경우,
            // 게이지만 0/0으로 덩그러니 남지 않도록 안내 가이드를 노출합니다.
            if data.missions.isEmpty {
                emptyCurriculumGuide
            } else {
                ChallengerCurriculumView(
                    curriculumModel: data.progress,
                    missions: data.missions
                )
            }

        case .failed(let error):
            errorView(error: error, viewModel: viewModel)
        }
    }

    /// 등록된 주차별 커리큘럼이 없을 때 표시하는 안내 가이드입니다.
    ///
    /// 서버가 커리큘럼 미등록(`CURRICULUM-0001`)을 에러로 내려주는 경우와
    /// 시각적으로 동일하게 맞춰, 빈 응답(200·weeks 없음)도 같은 가이드로 안내합니다.
    private var emptyCurriculumGuide: some View {
        ContentUnavailableView {
            Label("커리큘럼 준비 중", systemImage: "clock.badge.questionmark")
        } description: {
            Text("아직 등록된 주차별 커리큘럼이 없어요.\n커리큘럼이 등록되면 이곳에 표시됩니다.")
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            ProgressView()

            Text("커리큘럼 불러오는 중...")
                .appFont(.subheadline, color: .grey500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func errorView(error: AppError, viewModel: ChallengerStudyViewModel) -> some View {
        if case .domain(.curriculumNotRegistered) = error {
            ContentUnavailableView {
                Label("커리큘럼 준비 중", systemImage: "clock.badge.questionmark")
            } description: {
                Text(error.userMessage)
                    .multilineTextAlignment(.center)
            }
        } else if case .domain(.curriculumUnavailableForGeneration) = error {
            ContentUnavailableView {
                Label("커리큘럼 조회 불가", systemImage: "info.circle")
            } description: {
                Text(error.userMessage)
                    .multilineTextAlignment(.center)
            }
        } else {
            RetryContentUnavailableView(
                title: "불러오지 못했어요",
                systemImage: "exclamationmark.triangle",
                description: error.userMessage,
                isRetrying: false
            ) {
                await viewModel.fetchCurriculum()
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ChallengerStudyView(
        container: MissionPreviewData.container,
        errorHandler: MissionPreviewData.errorHandler)
}
#endif
