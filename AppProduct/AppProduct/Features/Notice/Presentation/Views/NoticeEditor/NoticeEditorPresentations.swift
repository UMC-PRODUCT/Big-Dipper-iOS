//
//  NoticeEditorPresentations.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import SwiftUI

// MARK: - ViewModifier

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
                if viewModel.showAIConfirmation {
                    AIConfirmationOverlay(
                        tokenUsage: viewModel.aiTokenUsage,
                        onConfirm: {
                            Task { await viewModel.startAIImprovement() }
                        },
                        onCancel: {
                            viewModel.showAIConfirmation = false
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .center)))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.showAIConfirmation)
            .overlay {
                if viewModel.isAIProcessing || viewModel.showAICompletionSummary {
                    AILoadingOverlay(
                        phase: viewModel.isAIProcessing ? .processing : .completed,
                        streamingText: viewModel.aiStreamingText,
                        onConfirm: { viewModel.dismissAICompletionSummary() }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .center)))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.isAIProcessing)
            .animation(.easeInOut(duration: 0.25), value: viewModel.showAICompletionSummary)
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

    private func targetSheet(_ sheetType: TargetSheetType) -> some View {
        TargetSheetView(viewModel: viewModel, sheetType: sheetType)
            .presentationDetents(targetSheetDetents(for: sheetType))
            .presentationDragIndicator(.visible)
    }

    private func votingSheet() -> some View {
        VotingFormSheetView(
            formData: $viewModel.voteFormData,
            onCancel: viewModel.cancelVotingEdit,
            onConfirm: viewModel.confirmVote,
            mode: viewModel.isVoteConfirmed ? .edit : .create
        )
    }

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
    func noticeEditorPresentations(viewModel: NoticeEditorViewModel) -> some View {
        modifier(NoticeEditorPresentations(viewModel: viewModel))
    }
}
