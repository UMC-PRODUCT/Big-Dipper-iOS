//
//  ChallengerStudyView.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/15/26.
//

import SwiftUI
import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import UMCFoundation

/// Challenger 모드의 스터디/활동 섹션
///
/// 진행률(`curriculumState`)과 주차별 미션(`missionsState`) 두 Loadable 을 조립해
/// 커리큘럼 화면을 구성합니다. ViewModel 은 조립부(탭 라우터, #996)에서 주입받습니다.
struct ChallengerStudyView: View {

    // MARK: - Property

    @State private var viewModel: ChallengerStudyViewModel

    // MARK: - Init

    init(viewModel: ChallengerStudyViewModel) {
        self._viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - Body

    var body: some View {
        Group {
            contentView(viewModel: viewModel)
        }
        .task {
            await viewModel.load()
        }
    }

    // MARK: - View Components

    /// 진행률/미션 두 상태를 조합해 화면을 결정합니다.
    ///
    /// - 조회가 실패하면 에러 뷰
    /// - 둘 다 로드되면 미션 유무에 따라 커리큘럼 뷰 또는 안내 가이드
    /// - 그 외(로딩/대기)는 로딩 뷰
    ///
    /// 두 상태는 단일 조회(`load()`)에서 함께 전이되므로 실패 여부는 한쪽만 확인해도
    /// 충분합니다. 미션만 따로 실패하는 상황은 성립하지 않습니다.
    @ViewBuilder
    private func contentView(viewModel: ChallengerStudyViewModel) -> some View {
        if case .failed(let error) = viewModel.curriculumState {
            errorView(error: error, viewModel: viewModel)
        } else if case .loaded(let progress) = viewModel.curriculumState,
                  case .loaded(let missions) = viewModel.missionsState {
            // 커리큘럼은 조회됐지만 등록된 주차가 없어 표시할 미션이 없는 경우,
            // 게이지만 0/0으로 덩그러니 남지 않도록 안내 가이드를 노출합니다.
            if missions.isEmpty {
                emptyCurriculumGuide
            } else {
                ChallengerCurriculumView(
                    curriculumModel: progress,
                    missions: missions
                )
            }
        } else {
            loadingView
        }
    }

    /// 등록된 주차별 커리큘럼이 없을 때 표시하는 안내 가이드입니다.
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
    private func errorView(
        error: AppError,
        viewModel: ChallengerStudyViewModel
    ) -> some View {
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
                isRetrying: viewModel.isLoading
            ) {
                await viewModel.load()
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ChallengerStudyView(viewModel: MissionPreviewData.makeViewModel())
}
#endif
