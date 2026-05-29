//
//  RetryContentUnavailableView.swift
//  CoreUIComponents
//
//  Created by 이예지 on 5/30/26.
//

import SwiftUI

/// 로딩 실패 시 재시도 액션을 함께 제공하는 공통 Unavailable View입니다.
public struct RetryContentUnavailableView: View {

    // MARK: - Property
    public let title: String
    public let systemImage: String
    public let description: String
    public let retryTitle: String
    public let isRetrying: Bool
    public let minRetryButtonWidth: CGFloat
    public let minRetryButtonHeight: CGFloat
    public let topPadding: CGFloat
    public let retryAction: () async -> Void

    // MARK: - Initializer
    public init(
        title: String,
        systemImage: String,
        description: String,
        retryTitle: String = "다시 시도",
        isRetrying: Bool,
        minRetryButtonWidth: CGFloat = 72,
        minRetryButtonHeight: CGFloat = 20,
        topPadding: CGFloat = .zero,
        retryAction: @escaping () async -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.retryTitle = retryTitle
        self.isRetrying = isRetrying
        self.minRetryButtonWidth = minRetryButtonWidth
        self.minRetryButtonHeight = minRetryButtonHeight
        self.topPadding = topPadding
        self.retryAction = retryAction
    }

    // MARK: - Body
    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(description)
                .multilineTextAlignment(.center)
        } actions: {
            Button {
                Task {
                    await retryAction()
                }
            } label: {
                ZStack {
                    Text(retryTitle)
                        .opacity(isRetrying ? 0 : 1)
                    if isRetrying {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .frame(
                    minWidth: minRetryButtonWidth,
                    minHeight: minRetryButtonHeight
                )
            }
            .buttonStyle(.glassProminent)
            .disabled(isRetrying)
        }
        .padding(.top, topPadding)
    }
}
