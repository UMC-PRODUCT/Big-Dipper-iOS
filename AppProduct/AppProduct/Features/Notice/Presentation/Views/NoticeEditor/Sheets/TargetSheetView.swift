//
//  TargetSheetView.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import SwiftUI

struct TargetSheetView: View {

    // MARK: - Property

    @Bindable var viewModel: NoticeEditorViewModel
    let sheetType: TargetSheetType
    @Environment(\.dismiss) private var dismiss
    @State private var isRetryingTargetOptions: Bool = false

    // MARK: - Constants

    private enum Constants {
        static let sectionSpacing: CGFloat = DefaultSpacing.spacing12
        static let chipSpacing: CGFloat = DefaultSpacing.spacing12
        static let horizontalPadding: CGFloat = 12
        static let topPadding: CGFloat = DefaultSpacing.spacing16
        static let retryButtonWidth: CGFloat = 72
        static let retryButtonHeight: CGFloat = 20
    }

    // MARK: - Helper

    private var navigationTitle: NavigationModifier.Navititle {
        switch sheetType {
        case .branch: return .branchSelection
        case .school: return .schoolSelection
        case .part:   return .partSelection
        }
    }

    private var navigationSubtitle: String {
        switch sheetType {
        case .branch: return "선택하지 않으면 전체 대상 공지로 발송됩니다."
        case .school: return "선택하지 않으면 전체 학교로 발송됩니다."
        case .part:   return "선택하지 않으면 전체 파트 대상 공지로 발송됩니다."
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            statefulSheetContent
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.top, Constants.topPadding)
            .navigation(naviTitle: navigationTitle, displayMode: .inline)
            .navigationSubtitle(navigationSubtitle)
            .task {
                if case .idle = viewModel.targetOptionsState {
                    await viewModel.loadTargetOptions()
                }
            }
        }
    }
    
    // MARK: - Content

    @ViewBuilder
    private var statefulSheetContent: some View {
        switch viewModel.targetOptionsState {
        case .idle, .loading:
            Progress(message: "대상 목록을 불러오고 있어요")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        case .loaded:
            sheetContent
        case .failed:
            RetryContentUnavailableView(
                title: "대상 목록을 불러오지 못했습니다.",
                systemImage: "exclamationmark.triangle",
                description: "일시적인 오류가 발생했습니다. 다시 시도해주세요.",
                retryTitle: "다시 시도",
                isRetrying: isRetryingTargetOptions,
                minRetryButtonWidth: Constants.retryButtonWidth,
                minRetryButtonHeight: Constants.retryButtonHeight
            ) {
                await retryTargetOptions()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private var sheetContent: some View {
        Group {
            switch sheetType {
            case .part:
                partFilterSection
            case .branch:
                branchFilterSection
            case .school:
                schoolFilterSection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Retry

    @MainActor
    private func retryTargetOptions() async {
        guard !isRetryingTargetOptions else { return }
        isRetryingTargetOptions = true
        defer { isRetryingTargetOptions = false }
        await viewModel.loadTargetOptions()
    }
    
    // MARK: - Section Builders

    private var branchFilterSection: some View {
        selectionSection {
            FlowLayout(spacing: Constants.chipSpacing) {
                ForEach(viewModel.branchOptions, id: \.self) { branch in
                    ChipButton(branch.name, isSelected: viewModel.isBranchSelected(branch)) {
                        viewModel.toggleBranch(branch)
                    }
                    .buttonSize(.medium)
                }
            }
        }
    }
    
    private var schoolFilterSection: some View {
        selectionSection {
            ScrollView(.vertical) {
                FlowLayout(spacing: Constants.chipSpacing) {
                    ForEach(viewModel.schoolOptions, id: \.self) { school in
                        ChipButton(school.name, isSelected: viewModel.isSchoolSelected(school)) {
                            viewModel.toggleSchool(school)
                        }
                        .buttonSize(.medium)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
    }
    
    private var partFilterSection: some View {
        selectionSection {
            FlowLayout(spacing: Constants.chipSpacing) {
                ForEach(NoticePart.allCases) { part in
                    ChipButton(
                        part.displayName,
                        isSelected: viewModel.isPartSelected(part.umcPartType)
                    ) {
                        viewModel.togglePart(part.umcPartType)
                    }
                    .buttonSize(.medium)
                }
            }
        }
    }
    
    // MARK: - Shared Section

    @ViewBuilder
    private func selectionSection<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
