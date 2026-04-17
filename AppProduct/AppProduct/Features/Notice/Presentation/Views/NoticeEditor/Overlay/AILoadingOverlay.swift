//
//  AILoadingOverlay.swift
//  AppProduct
//
//  Created by 이예지 on 1/24/26.
//

import SwiftUI

/// AI 글 개선 처리 중/완료 시 표시되는 전체 화면 오버레이입니다.
struct AILoadingOverlay: View {

    // MARK: - Property

    let phase: Phase
    let streamingText: String
    let tokenUsage: NoticeEditorViewModel.AITokenUsage?
    var onConfirm: (() -> Void)? = nil

    // MARK: - Types

    enum Phase {
        case processing
        case completed
    }

    // MARK: - Constants

    private enum Constants {
        static let overlayOpacity: Double = 0.55
        static let cardCornerRadius: CGFloat = 20
        static let iconSize: CGFloat = 36
        static let cardPadding: EdgeInsets = .init(top: 24, leading: 28, bottom: 24, trailing: 28)
        static let cardMaxWidth: CGFloat = 300
        static let streamingLineLimit: Int = 3
        static let streamingLineSpacing: CGFloat = 1
        static let tokenProgressHeight: CGFloat = 3
        static let tokenRowSpacing: CGFloat = 6
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.opacity(Constants.overlayOpacity)
                .ignoresSafeArea()

            VStack(spacing: DefaultSpacing.spacing16) {
                headerIcon

                Text(titleText)
                    .appFont(.calloutEmphasis)
                    .multilineTextAlignment(.center)

                if phase == .processing, !streamingText.isEmpty {
                    Text(streamingText)
                        .font(.app(.footnote))
                        .foregroundStyle(.grey500)
                        .lineSpacing(Constants.streamingLineSpacing)
                        .lineLimit(Constants.streamingLineLimit)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.15), value: streamingText)
                }

                if let tokenUsage {
                    tokenUsageRow(tokenUsage)
                }

                if phase == .completed {
                    MainButton("확인") {
                        onConfirm?()
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .padding(Constants.cardPadding)
            .frame(maxWidth: Constants.cardMaxWidth)
            .glassEffect(.regular, in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius)))
        }
    }

    // MARK: - View Builders

    @ViewBuilder
    private var headerIcon: some View {
        switch phase {
        case .processing:
            Image(systemName: "sparkles")
                .font(.system(size: Constants.iconSize, weight: .medium))
                .foregroundStyle(.indigo500)
                .symbolEffect(.variableColor.iterative.reversing)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: Constants.iconSize, weight: .medium))
                .foregroundStyle(.indigo500)
        }
    }

    private var titleText: String {
        switch phase {
        case .processing: "AI가 글을 개선하고 있어요..."
        case .completed:  "AI 개선이 완료됐어요"
        }
    }

    @ViewBuilder
    private func tokenUsageRow(_ usage: NoticeEditorViewModel.AITokenUsage) -> some View {
        VStack(spacing: Constants.tokenRowSpacing) {
            ProgressView(value: usage.progress)
                .progressViewStyle(.linear)
                .tint(.indigo500)
                .frame(height: Constants.tokenProgressHeight)

            HStack {
                switch phase {
                case .processing:
                    Text("사용 \(usage.cumulativeUsed.formatted()) 토큰")
                case .completed:
                    Text("이번 \(usage.lastRunTokens.formatted()) 토큰")
                }
                Spacer(minLength: 8)
                Text("남음 \(usage.remaining.formatted()) / \(usage.total.formatted())")
            }
            .font(.app(.caption2))
            .foregroundStyle(.grey500)
        }
        .animation(.easeInOut(duration: 0.2), value: usage)
    }
}
