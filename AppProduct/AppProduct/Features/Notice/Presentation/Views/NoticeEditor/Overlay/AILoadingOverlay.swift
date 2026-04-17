//
//  AILoadingOverlay.swift
//  AppProduct
//
//  Created by 이예지 on 1/24/26.
//

import SwiftUI

/// AI 글 개선 처리 중 표시되는 전체 화면 로딩 오버레이입니다.
struct AILoadingOverlay: View {

    // MARK: - Property

    let streamingText: String

    // MARK: - Constants

    private enum Constants {
        static let overlayOpacity: Double = 0.55
        static let cardCornerRadius: CGFloat = 20
        static let iconSize: CGFloat = 36
        static let cardPadding: EdgeInsets = .init(top: 24, leading: 28, bottom: 24, trailing: 28)
        static let cardMaxWidth: CGFloat = 300
        static let streamingLineLimit: Int = 3
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.opacity(Constants.overlayOpacity)
                .ignoresSafeArea()

            VStack(spacing: DefaultSpacing.spacing16) {
                Image(systemName: "sparkles")
                    .font(.system(size: Constants.iconSize, weight: .medium))
                    .foregroundStyle(.indigo500)
                    .symbolEffect(.variableColor.iterative.reversing)

                Text("AI가 글을 개선하고 있어요...")
                    .appFont(.calloutEmphasis)
                    .multilineTextAlignment(.center)

                if !streamingText.isEmpty {
                    Text(streamingText)
                        .appFont(.footnote, color: .grey500)
                        .lineLimit(Constants.streamingLineLimit)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.15), value: streamingText)
                }
            }
            .padding(Constants.cardPadding)
            .frame(maxWidth: Constants.cardMaxWidth)
            .glassEffect(.regular, in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius)))
        }
    }
}
