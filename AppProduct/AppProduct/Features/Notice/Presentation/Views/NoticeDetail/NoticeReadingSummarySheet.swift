//
//  NoticeReadingSummarySheet.swift
//  AppProduct
//
//  Created by euijjang97 on 5/31/26.
//

import SwiftUI
import SwiftData

/// AI 읽기 요약 시트
///
/// 공지 본문을 온디바이스 AI로 요약한 결과를 스트리밍으로 표시합니다.
struct NoticeReadingSummarySheet: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: NoticeDetailViewModel
    let noticeContent: String

    /// 시트 높이. 기본은 `.medium`, 필요 시 `.large` 로 끌어올릴 수 있다.
    @State private var selectedDetent: PresentationDetent = .medium

    // MARK: - Constants

    fileprivate enum Constants {
        static let sheetHorizontalPadding: CGFloat = DefaultConstant.defaultSafeHorizon
        static let sheetTopPadding: CGFloat = DefaultSpacing.spacing24
        static let headerSpacing: CGFloat = DefaultSpacing.spacing8
        static let bodySpacing: CGFloat = DefaultSpacing.spacing16
        static let iconSize: CGFloat = DefaultConstant.iconSize
        static let cardPadding: EdgeInsets = .init(
            top: DefaultSpacing.spacing16,
            leading: DefaultConstant.defaultSafeHorizon,
            bottom: DefaultSpacing.spacing16,
            trailing: DefaultConstant.defaultSafeHorizon
        )
        static let retryButtonTitle: String = "다시 시도"
        static let dismissButtonTitle: String = "닫기"
        static let headerLabel: String = "Apple Intelligence"
        static let streamingPlaceholder: String = "요약하는 중..."
        static let failedIconName: String = "exclamationmark.circle"
        static let sparklesIconName: String = "sparkles"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: Constants.bodySpacing) {
                    headerSection
                    summarySection
                    Spacer(minLength: DefaultSpacing.spacing24)
                }
                .padding(.horizontal, Constants.sheetHorizontalPadding)
                .padding(.top, Constants.sheetTopPadding)
            }
            .navigation(naviTitle: .noticeAISummary, displayMode: .inline)
            .toolbar { sheetToolbar }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .onAppear {
            if viewModel.readingSummaryPhase == .idle {
                viewModel.requestReadingSummary(content: noticeContent, modelContext: modelContext)
            }
        }
        .onDisappear {
            viewModel.dismissReadingSummary()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: Constants.headerSpacing) {
            Image(systemName: Constants.sparklesIconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.indigo500)

            Text(Constants.headerLabel)
                .appFont(.calloutEmphasis)
                .foregroundStyle(.grey700)
        }
    }

    // MARK: - Summary Content

    @ViewBuilder
    private var summarySection: some View {
        switch viewModel.readingSummaryPhase {
        case .idle:
            EmptyView()

        case .streaming:
            streamingContent

        case .completed:
            completedContent

        case .failed(let message):
            failedContent(message: message)
        }
    }

    private var streamingContent: some View {
        VStack(alignment: .leading, spacing: Constants.bodySpacing) {
            if viewModel.readingSummaryStreamingText.isEmpty {
                HStack(spacing: DefaultSpacing.spacing8) {
                    ProgressView()
                        .tint(.grey500)
                    Text(Constants.streamingPlaceholder)
                        .appFont(.body, color: .grey500)
                }
            } else {
                Text(viewModel.readingSummaryStreamingText)
                    .appFont(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Constants.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius)))
    }

    private var completedContent: some View {
        Text(renderedSummary)
            .appFont(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Constants.cardPadding)
            .glassEffect(.regular, in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius)))
    }

    /// 요약 마크다운(굵게 · 불릿)을 네이티브 `AttributedString` 으로 변환합니다.
    ///
    /// UITextView 기반 렌더러는 ScrollView 안에서 너비 제안이 비면 한 줄로 붕괴하므로,
    /// 네이티브 `Text` 로 렌더링해 항상 정상 줄바꿈되도록 합니다.
    /// `* ` / `- ` 로 시작하는 줄은 `•` 불릿으로 치환합니다.
    private var renderedSummary: AttributedString {
        let normalized = viewModel.readingSummaryStreamingText
            .components(separatedBy: "\n")
            .map { line -> String in
                let trimmed = line.drop(while: { $0 == " " })
                if trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ") {
                    return "•  " + String(trimmed.dropFirst(2))
                }
                return line
            }
            .joined(separator: "\n")

        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: normalized, options: options))
            ?? AttributedString(normalized)
    }

    private func failedContent(message: String) -> some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            Image(systemName: Constants.failedIconName)
                .font(.system(size: Constants.iconSize, weight: .medium))
                .foregroundStyle(.grey400)

            Text(message)
                .appFont(.footnote, color: .grey500)
                .multilineTextAlignment(.center)

            MainButton(Constants.retryButtonTitle) {
                viewModel.requestReadingSummary(content: noticeContent, modelContext: modelContext)
            }
            .buttonStyle(.glassProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(Constants.cardPadding)
        .glassEffect(.regular, in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius)))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var sheetToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(Constants.dismissButtonTitle) {
                dismiss()
            }
            .appFont(.body, color: .grey700)
        }
    }
}
