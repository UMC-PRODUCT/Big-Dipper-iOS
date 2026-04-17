//
//  TargetSheetView.swift
//  AppProduct
//
//  Created by 이예지 on 1/26/26.
//

import SwiftUI

/// 공지 수신 대상 선택 시트 (지부/학교/파트)
struct TargetSheetView: View {
    
    // MARK: - Property
    
    @Bindable var viewModel: NoticeEditorViewModel
    let sheetType: TargetSheetType
    @Environment(\.dismiss) private var dismiss
    @State private var isRetryingTargetOptions: Bool = false
    
    // MARK: - Constants
    
    /// 타겟 선택 시트의 레이아웃/문구 상수 모음
    private enum Constants {
        static let rootContentSpacing: CGFloat = DefaultSpacing.spacing24
        static let sectionSpacing: CGFloat = DefaultSpacing.spacing12
        static let chipSpacing: CGFloat = DefaultSpacing.spacing12
        static let horizontalPadding: CGFloat = 12
        static let topPadding: CGFloat = DefaultSpacing.spacing16
        static let bottomPadding: CGFloat = DefaultSpacing.spacing24
        
        static let branchGuideMessage: String = "선택하지 않으면 전체 대상 공지로 발송됩니다."
        static let schoolGuideMessage: String = "선택하지 않으면 전체 학교로 발송됩니다."
        static let partGuideMessage: String = "선택하지 않으면 전체 파트 대상 공지로 발송됩니다."
        static let failedTitle: String = "대상 목록을 불러오지 못했습니다."
        static let failedDescription: String = "일시적인 오류가 발생했습니다. 다시 시도해주세요."
        static let failedIcon: String = "exclamationmark.triangle"
        static let retryTitle: String = "다시 시도"
        static let retryButtonWidth: CGFloat = 72
        static let retryButtonHeight: CGFloat = 20
        static let loadingMessage: String = "대상 목록을 불러오고 있어요"
    }
    
    // MARK: - Helper
    
    private var navigationTitle: NavigationModifier.Navititle {
        switch sheetType {
        case .branch:
            return .branchSelection
        case .school:
            return .schoolSelection
        case .part:
            return .partSelection
        }
    }
    
    private var navigationSubtitle: String {
        switch sheetType {
        case .branch:
            return Constants.branchGuideMessage
        case .school:
            return Constants.schoolGuideMessage
        case .part:
            return Constants.partGuideMessage
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
    
    /// 선택된 시트 타입에 맞는 필터 섹션을 반환합니다.
    @ViewBuilder
    private var statefulSheetContent: some View {
        switch viewModel.targetOptionsState {
        case .idle, .loading:
            Progress(message: Constants.loadingMessage)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        case .loaded:
            sheetContent
        case .failed:
            RetryContentUnavailableView(
                title: Constants.failedTitle,
                systemImage: Constants.failedIcon,
                description: Constants.failedDescription,
                retryTitle: Constants.retryTitle,
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

    /// 타겟 옵션 로드 실패 시 재시도합니다. 중복 호출을 방지합니다.
    @MainActor
    private func retryTargetOptions() async {
        guard !isRetryingTargetOptions else { return }
        isRetryingTargetOptions = true
        defer { isRetryingTargetOptions = false }
        await viewModel.loadTargetOptions()
    }
    
    // MARK: - Section Builders
    
    /// 지부 대상 선택 섹션
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
    
    /// 학교 대상 선택 섹션
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
    
    /// 파트 대상 선택 섹션
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
    
    /// 타겟 선택 칩 레이아웃을 공통화합니다.
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
