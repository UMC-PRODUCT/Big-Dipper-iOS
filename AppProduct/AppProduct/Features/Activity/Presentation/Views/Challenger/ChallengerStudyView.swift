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
            submitMissionUseCase: activityProvider.submitMissionUseCase,
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
            ChallengerCurriculumView(
                curriculumModel: data.progress,
                missions: data.missions
            ) { mission, type, link in
                Task {
                    await viewModel.submitMission(mission, type: type, link: link)
                }
            }

        case .failed(let error):
            errorView(error: error, viewModel: viewModel)
        }
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
        if case .domain(.curriculumUnavailableForGeneration) = error {
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
