//
//  AILoadingOverlay.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import SwiftUI

/// AI 글 개선 처리 중/완료 시 표시되는 전체 화면 오버레이입니다.
struct AILoadingOverlay: View {

    // MARK: - Property

    let phase: Phase
    let streamingText: String
    var onConfirm: (() -> Void)? = nil

    // MARK: - Types

    enum Phase {
        case processing
        case completed
    }

    // MARK: - Constants

    private enum Constants {
        static let cardPadding: EdgeInsets = .init(top: 24, leading: 28, bottom: 24, trailing: 28)
        static let cardMaxWidth: CGFloat = 360
        static let streamingLineLimit: Int = 3
        static let streamingLineSpacing: CGFloat = 1
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
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
                .font(.system(size: DefaultConstant.iconSize, weight: .medium))
                .foregroundStyle(.indigo500)
                .symbolEffect(.variableColor.iterative.reversing)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: DefaultConstant.iconSize, weight: .medium))
                .foregroundStyle(.indigo500)
        }
    }

    private var titleText: String {
        switch phase {
        case .processing: "본문을 다듬고 있어요..."
        case .completed:  "다듬기가 끝났어요"
        }
    }
}
