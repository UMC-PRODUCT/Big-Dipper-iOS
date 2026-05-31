//
//  NoticeEditorPresentations.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
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
            // AI Rewrite: 확인 다이얼로그
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
            // AI Rewrite: 로딩/완료 오버레이
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
            // AI Summary: 붙여넣기 입력 시트
            .sheet(isPresented: $viewModel.showAISummaryInput, onDismiss: {
                viewModel.summarySourceText = ""
            }) {
                AISummaryInputSheet(
                    sourceText: $viewModel.summarySourceText,
                    tokenUsage: viewModel.aiTokenUsage,
                    onSummarize: {
                        viewModel.requestAISummary(from: viewModel.summarySourceText)
                    },
                    onCancel: {
                        viewModel.closeSummaryInput()
                    }
                )
            }
            // AI Summary: 확인 다이얼로그
            .overlay {
                if viewModel.showAISummaryConfirmation {
                    AIConfirmationOverlay(
                        tokenUsage: viewModel.aiTokenUsage,
                        titleText: "외부 텍스트를 요약해 공지 초안을 만들어 드릴게요.\n지금 시작할까요?",
                        confirmButtonTitle: "요약하기",
                        onConfirm: {
                            Task { await viewModel.startAISummary() }
                        },
                        onCancel: {
                            viewModel.showAISummaryConfirmation = false
                            viewModel.pendingSummaryDraft = nil
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .center)))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.showAISummaryConfirmation)
            // AI Summary: 요약 진행 중 오버레이
            .overlay {
                if viewModel.isAISummaryProcessing {
                    AILoadingOverlay(
                        phase: .processing,
                        streamingText: viewModel.aiSummaryStreamingText
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .center)))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.isAISummaryProcessing)
            // AI Summary: 초안 검토 오버레이
            .overlay {
                if viewModel.showAISummaryDraftReview, let draft = viewModel.pendingSummaryDraft {
                    AISummaryDraftOverlay(
                        draft: draft,
                        onAccept: { viewModel.applySummaryDraft() },
                        onReject: { viewModel.dismissAISummaryDraft() }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .center)))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.showAISummaryDraftReview)
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
