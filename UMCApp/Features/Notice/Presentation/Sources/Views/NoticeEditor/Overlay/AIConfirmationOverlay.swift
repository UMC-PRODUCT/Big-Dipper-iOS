//
//  AIConfirmationOverlay.swift
//  NoticePresentation
//
//  Created by 이예지 on 7/3/26.
//

import SwiftUI
import CoreDesignSystem
import CoreUIComponents

struct AIConfirmationOverlay: View {

    // MARK: - Property

    let tokenUsage: NoticeEditorViewModel.AITokenUsage?
    var titleText: String = "공지 본문을 더 읽기 좋게 다듬어 드릴게요.\n지금 바로 시작할까요?"
    var confirmButtonTitle: String = "작성하기"
    let onConfirm: () -> Void
    let onCancel: () -> Void

    // MARK: - Constants

    private enum Constants {
        static let cardPadding: EdgeInsets = .init(top: 24, leading: 28, bottom: 24, trailing: 28)
        static let cardMaxWidth: CGFloat = 360
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()

            VStack(spacing: DefaultSpacing.spacing16) {
                Image(systemName: "sparkles")
                    .font(.system(size: DefaultConstant.iconSize, weight: .medium))
                    .foregroundStyle(Color.indigo500)

                Text("Apple Intelligence")
                    .appFont(.callout, weight: .semibold)
                    .multilineTextAlignment(.center)

                Text(titleText)
                    .font(.app(.footnote))
                    .foregroundStyle(Color.grey500)
                    .multilineTextAlignment(.center)

                if let tokenUsage {
                    if isTokenExhausted(tokenUsage) {
                        exhaustedView
                    } else {
                        sandwichTokenView(tokenUsage)
                    }
                }

                HStack(spacing: DefaultSpacing.spacing8) {
                    MainButton("취소") { onCancel() }
                        .buttonStyle(.glass)
                    MainButton(confirmButtonTitle) { onConfirm() }
                        .buttonStyle(.glassProminent)
                        .disabled(tokenUsage.map { isTokenExhausted($0) } ?? false)
                }
            }
            .padding(Constants.cardPadding)
            .frame(maxWidth: Constants.cardMaxWidth)
            .glassEffect(.regular, in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius)))
        }
    }

    // MARK: - View Builders

    @ViewBuilder
    private var exhaustedView: some View {
        VStack(alignment: .center, spacing: DefaultSpacing.spacing4) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: DefaultConstant.iconSize, weight: .medium))
                .foregroundStyle(Color.red)

            Text("오늘 사용 가능한 토큰을 모두 사용했어요")
                .appFont(.footnote, weight: .semibold)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)

            Text("내일 다시 사용할 수 있어요")
                .appFont(.caption1)
                .foregroundStyle(Color.grey500)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func sandwichTokenView(_ usage: NoticeEditorViewModel.AITokenUsage) -> some View {
        let progress = usage.progress
        let valueColor = valueWarningColor(for: progress)
        let gaugeTint = gaugeTintColor(for: progress)

        VStack(spacing: DefaultSpacing.spacing4) {
            HStack {
                Text("사용된 토큰")
                    .appFont(.caption1)
                    .foregroundStyle(Color.grey500)
                Spacer(minLength: 0)
                Text("남은 토큰")
                    .appFont(.caption1)
                    .foregroundStyle(Color.grey500)
            }

            Gauge(
                value: Double(usage.cumulativeUsed),
                in: 0...Double(usage.total)
            ) {
                EmptyView()
            }
            .gaugeStyle(.linearCapacity)
            .tint(gaugeTint)

            HStack {
                Text("\(usage.cumulativeUsed.formatted()) 토큰")
                    .appFont(.footnote, weight: .semibold)
                    .foregroundStyle(valueColor)
                Spacer(minLength: 0)
                Text("\(usage.remaining.formatted()) 토큰")
                    .appFont(.footnote, weight: .semibold)
                    .foregroundStyle(valueColor)
            }
        }
    }

    // MARK: - Function

    private func isTokenExhausted(_ usage: NoticeEditorViewModel.AITokenUsage) -> Bool {
        usage.remaining == 0
    }

    private func valueWarningColor(for progress: Double) -> Color {
        if progress >= 0.90 {
            return .red
        } else if progress >= 0.80 {
            return .orange
        } else {
            return .grey500
        }
    }

    private func gaugeTintColor(for progress: Double) -> Color {
        if progress >= 0.90 {
            return .red
        } else if progress >= 0.80 {
            return .orange
        } else {
            return .indigo500
        }
    }
}
