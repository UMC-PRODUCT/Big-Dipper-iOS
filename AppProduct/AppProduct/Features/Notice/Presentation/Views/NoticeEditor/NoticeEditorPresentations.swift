//
//  NoticeEditorPresentations.swift
//  AppProduct
//
//  Created by 이예지 on 1/24/26.
//

import SwiftUI

// MARK: - ViewModifier

/// 공지 에디터 화면의 sheet/fullScreenCover/overlay/alert 등 프레젠테이션 계열 modifier를 묶은 ViewModifier입니다.
struct NoticeEditorPresentations: ViewModifier {

    // MARK: - Property

    @Bindable var viewModel: NoticeEditorViewModel

    // MARK: - Constants

    private enum Constants {
        static let targetSheetLargeDetentFraction: CGFloat = 0.86
        static let targetSheetSmallDetentFraction: CGFloat = 0.38
        static let formatPanelHeight: CGFloat = 330
    }

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .sheet(item: $viewModel.activeSheetType, content: targetSheet)
            .fullScreenCover(isPresented: $viewModel.showVoting, content: votingSheet)
            .alertPrompt(item: $viewModel.alertPrompt)
            .overlay {
                if viewModel.isAIProcessing {
                    AILoadingOverlay(streamingText: viewModel.aiStreamingText)
                        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .center)))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.isAIProcessing)
            .sheet(
                isPresented: Binding(
                    get: { viewModel.editorToolbarViewModel.isFormatPanelVisible },
                    set: { if !$0 { viewModel.editorToolbarViewModel.dismissFormatPanel() } }
                )
            ) {
                FormatPanelView(viewModel: viewModel.editorToolbarViewModel)
                    .presentationDetents([.height(Constants.formatPanelHeight)])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.regularMaterial)
            }
    }

    // MARK: - View Builders

    /// 타겟 선택 시트를 표시합니다.
    private func targetSheet(_ sheetType: TargetSheetType) -> some View {
        TargetSheetView(viewModel: viewModel, sheetType: sheetType)
            .presentationDetents(targetSheetDetents(for: sheetType))
            .presentationDragIndicator(.visible)
    }

    /// 투표 폼 시트를 표시합니다.
    private func votingSheet() -> some View {
        VotingFormSheetView(
            formData: $viewModel.voteFormData,
            onCancel: viewModel.cancelVotingEdit,
            onConfirm: viewModel.confirmVote,
            mode: viewModel.isVoteConfirmed ? .edit : .create
        )
    }

    /// 타겟 선택 시트 높이 설정
    private func targetSheetDetents(for sheetType: TargetSheetType) -> Set<PresentationDetent> {
        switch sheetType {
        case .part, .branch:
            return [.fraction(Constants.targetSheetSmallDetentFraction)]
        case .school:
            return [.fraction(Constants.targetSheetLargeDetentFraction)]
        }
    }
}

// MARK: - View Extension

extension View {
    /// 공지 에디터의 프레젠테이션 계열 modifier를 일괄 적용합니다.
    func noticeEditorPresentations(viewModel: NoticeEditorViewModel) -> some View {
        modifier(NoticeEditorPresentations(viewModel: viewModel))
    }
}
