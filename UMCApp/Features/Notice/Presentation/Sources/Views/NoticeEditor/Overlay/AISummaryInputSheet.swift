//
//  AISummaryInputSheet.swift
//  NoticePresentation
//
//  Created by 이예지 on 7/3/26.
//

import SwiftUI
import CoreDesignSystem
import CoreUIComponents

/// 외부 텍스트를 붙여넣고 AI 요약을 요청하는 시트입니다.
///
/// 사용자가 디스코드·이메일·메모 등 외부 텍스트를 입력 영역에 붙여넣은 뒤
/// "AI 요약" 버튼을 탭하면 공지 초안 생성 흐름이 시작됩니다.
/// 카테고리·대상·알림 발송 여부는 이 흐름에서 절대 변경하지 않습니다.
struct AISummaryInputSheet: View {

    // MARK: - Property

    @Binding var sourceText: String
    let tokenUsage: NoticeEditorViewModel.AITokenUsage?
    let onSummarize: () -> Void
    let onCancel: () -> Void

    // MARK: - Constants

    private enum Constants {
        static let inputMinHeight: CGFloat = 160
        static let cardPadding: EdgeInsets = .init(top: 24, leading: 24, bottom: 24, trailing: 24)
        static let textEditorCornerRadius: CGFloat = 12
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
                headerSection
                inputSection
                if let tokenUsage {
                    tokenSection(tokenUsage)
                }
                Spacer(minLength: 0)
                actionSection
            }
            .padding(Constants.cardPadding)
            .navigationTitle("붙여넣고 AI 요약")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소", action: onCancel)
                        .foregroundStyle(Color.grey500)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - View Builders

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
            HStack(spacing: DefaultSpacing.spacing8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.indigo500)
                Text("Apple Intelligence")
                    .appFont(.callout, weight: .semibold)
            }
            Text("외부 텍스트에서 공지 제목과 본문 초안을 생성합니다.\n카테고리·대상·알림 설정은 직접 지정해주세요.")
                .font(.app(.footnote))
                .foregroundStyle(Color.grey500)
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            Text("붙여넣을 텍스트")
                .appFont(.footnote, weight: .semibold)
                .foregroundStyle(Color.grey600)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Constants.textEditorCornerRadius)
                    .fill(.thinMaterial)

                if sourceText.isEmpty {
                    Text("디스코드 메시지, 이메일, 메모 등을 붙여넣으세요")
                        .font(.app(.footnote))
                        .foregroundStyle(Color.grey500)
                        .padding(.horizontal, DefaultSpacing.spacing12)
                        .padding(.vertical, DefaultSpacing.spacing12)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $sourceText)
                    .font(.app(.footnote))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, DefaultSpacing.spacing8)
                    .padding(.vertical, DefaultSpacing.spacing8)
            }
            .frame(minHeight: Constants.inputMinHeight)
        }
    }

    @ViewBuilder
    private func tokenSection(_ usage: NoticeEditorViewModel.AITokenUsage) -> some View {
        if isTokenExhausted(usage) {
            exhaustedView
        } else {
            tokenGaugeView(usage)
        }
    }

    private var exhaustedView: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
            Text("오늘 사용 가능한 토큰을 모두 사용했어요")
                .appFont(.footnote, weight: .semibold)
                .foregroundStyle(.red)
        }
    }

    private func tokenGaugeView(_ usage: NoticeEditorViewModel.AITokenUsage) -> some View {
        let progress = usage.progress
        let gaugeTint = gaugeTintColor(for: progress)

        return VStack(spacing: DefaultSpacing.spacing4) {
            Gauge(
                value: Double(usage.cumulativeUsed),
                in: 0...Double(usage.total)
            ) {
                EmptyView()
            }
            .gaugeStyle(.linearCapacity)
            .tint(gaugeTint)

            HStack {
                Text("사용된 토큰 \(usage.cumulativeUsed.formatted())")
                    .appFont(.caption1)
                    .foregroundStyle(Color.grey500)
                Spacer(minLength: 0)
                Text("남은 토큰 \(usage.remaining.formatted())")
                    .appFont(.caption1)
                    .foregroundStyle(Color.grey500)
            }
        }
    }

    private var actionSection: some View {
        MainButton("AI 요약 (초안 생성)") {
            onSummarize()
        }
        .buttonStyle(.glassProminent)
        .disabled(isActionDisabled)
    }

    // MARK: - Function

    private var isActionDisabled: Bool {
        sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || tokenUsage.map { isTokenExhausted($0) } ?? false
    }

    private func isTokenExhausted(_ usage: NoticeEditorViewModel.AITokenUsage) -> Bool {
        usage.remaining == 0
    }

    private func gaugeTintColor(for progress: Double) -> Color {
        if progress >= 0.90 { return .red }
        if progress >= 0.80 { return .orange }
        return .indigo500
    }
}
