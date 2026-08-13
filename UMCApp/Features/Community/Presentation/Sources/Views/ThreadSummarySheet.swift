//
//  ThreadSummarySheet.swift
//  CommunityPresentation
//

import SwiftUI
import CommunityDomain
import CoreDesignSystem
import CoreUIComponents
import UMCFoundation

// MARK: - Constants

fileprivate enum Constants {
    static let navigationTitle = "대화 요약"
    static let engineLabel = "Apple Intelligence"
    static let onDeviceLabel = "온디바이스"
    static let disclaimer = "요약은 참고용이에요. 중요한 내용은 원문을 확인해 주세요."
    static let loadingTitle = "대화를 읽고 있어요"
    static let bulletsTitle = "이런 이야기가 오갔어요"
    static let actionItemsTitle = "내 액션 아이템"
    static let emptyActionItems = "지금 바로 해야 할 일은 없어요."
    static let failureTitle = "요약을 만들지 못했어요"
    static let retryTitle = "다시 요약"
    static let originalTitle = "원문 보기"
    static let dismissTitle = "닫기"

    static let sparklesImage = "sparkles"
    static let failureImage = "exclamationmark.circle"
    static let bulletImage = "circle.fill"
    static let actionItemImage = "checkmark.circle"

    static let headerIconSize: CGFloat = 16
    static let bulletIconSize: CGFloat = 5
    static let actionItemIconSize: CGFloat = 14
    static let failureIconSize: CGFloat = DefaultConstant.iconSize
    static let cardPadding: EdgeInsets = .init(
        top: DefaultSpacing.spacing16,
        leading: DefaultConstant.defaultSafeHorizon,
        bottom: DefaultSpacing.spacing16,
        trailing: DefaultConstant.defaultSafeHorizon
    )
    static let shimmerBarHeight: CGFloat = 12
    /// 줄마다 오른쪽을 다르게 비워 실제 문단처럼 보이게 한다. 비율 대신 여백으로 잡는 이유는
    /// 비율을 쓰려면 카드 너비를 재야 하고, 그 값을 재는 순간 카드 안쪽 패딩까지 따라와서다.
    static let shimmerBarInsets: [CGFloat] = [0, DefaultSpacing.spacing24, DefaultSpacing.spacing96]
    static let shimmerDuration: Double = 1.1
    static let aiBorderWidth: CGFloat = 1

    /// AI 처리 중임을 알리는 그라디언트.
    static let aiGradient = LinearGradient(
        colors: [.indigo300, .indigo500, .indigo700],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// 미읽음 구간 요약 시트.
///
/// 헤더(무엇이 만들었는지)와 하단 면책 문구는 요약 상태와 무관하게 항상 그린다. 생성형 결과를
/// 보여 주는 화면에서 출처와 한계 표기는 결과가 있을 때만 보여 줄 성질의 것이 아니다.
struct ThreadSummarySheet: View {

    // MARK: - Property

    let viewModel: CommunityThreadRoomViewModel

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
                    header
                    content
                    disclaimer
                }
                .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
                .padding(.top, DefaultSpacing.spacing24)
                .padding(.bottom, DefaultSpacing.spacing24)
            }
            .umcDefaultBackground()
            .navigationTitle(Constants.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Constants.dismissTitle) { dismiss() }
                        .appFont(.body, color: .grey700)
                }
            }
        }
        .presentationDetents([.medium, .large])
        // 시트를 다시 열 때마다 그 사이 쌓인 메시지까지 반영해야 해서 `.idle` 로 되돌려 두고,
        // 여기서 다시 요청한다.
        .task {
            guard viewModel.summary.isIdle else { return }
            await viewModel.requestSummary()
        }
        .onDisappear { viewModel.dismissSummary() }
    }

    // MARK: - View Component

    /// 무엇이 만든 요약인지. "온디바이스" 는 대화 내용이 기기 밖으로 나가지 않는다는 뜻이라
    /// 채팅 요약에서는 브랜드 표기보다 중요한 정보다.
    private var header: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Image(systemName: Constants.sparklesImage)
                .font(.system(size: Constants.headerIconSize, weight: .medium))
                .foregroundStyle(Color.indigo500)

            Text(Constants.engineLabel)
                .appFont(.callout, weight: .semibold, color: .grey700)

            Text(Constants.onDeviceLabel)
                .appFont(.caption2, color: .indigo600)
                .padding(.horizontal, DefaultSpacing.spacing8)
                .padding(.vertical, DefaultSpacing.spacing4)
                .background(Color.indigo100, in: .capsule)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.summary {
        case .idle, .loading:
            loadingCard

        case .loaded(let summary):
            resultCard(summary)

        case .failed(let error):
            failureCard(error)
        }
    }

    private var loadingCard: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            HStack(spacing: DefaultSpacing.spacing8) {
                Image(systemName: Constants.sparklesImage)
                    .font(.system(size: Constants.headerIconSize, weight: .medium))
                    .foregroundStyle(Color.indigo500)
                    .symbolEffect(.variableColor.iterative.reversing)

                Text(Constants.loadingTitle)
                    .appFont(.callout, weight: .semibold, color: .grey700)
            }

            ProgressView()
                .progressViewStyle(.linear)
                .tint(Color.indigo500)

            ForEach(Constants.shimmerBarInsets, id: \.self) { inset in
                ShimmerBar(trailingInset: inset)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Constants.cardPadding)
        .glassEffect(
            .regular,
            in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius))
        )
        // 처리 중임을 색으로도 알린다. 진행바 하나만으로는 일반 로딩과 구분되지 않는다.
        .overlay {
            ConcentricRectangle(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
            .stroke(Constants.aiGradient, lineWidth: Constants.aiBorderWidth)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Constants.loadingTitle)
    }

    /// 요약과 액션 아이템을 다른 카드로 나눈다.
    ///
    /// "내가 할 일" 은 훑어보는 요약과 성격이 달라 한 카드 안에 소제목으로만 구분하면 그대로
    /// 지나친다. 카드를 쪼개는 편이 시선을 한 번 더 끊는다.
    private func resultCard(_ summary: ThreadSummary) -> some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
            if !summary.bullets.isEmpty {
                summarySection(summary.bullets)
            }
            actionItemSection(summary.actionItems)
            resultActions
        }
    }

    private func summarySection(_ bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            Text(Constants.bulletsTitle)
                .appFont(.footnote, weight: .semibold, color: .grey500)

            ForEach(bullets, id: \.self) { bullet in
                HStack(alignment: .firstTextBaseline, spacing: DefaultSpacing.spacing8) {
                    Image(systemName: Constants.bulletImage)
                        .font(.system(size: Constants.bulletIconSize))
                        .foregroundStyle(Color.grey400)

                    Text(bullet)
                        .appFont(.subheadline, color: .grey900)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Constants.cardPadding)
        .glassEffect(
            .regular,
            in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius))
        )
    }

    private func actionItemSection(_ actionItems: [String]) -> some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            HStack(spacing: DefaultSpacing.spacing4) {
                Image(systemName: Constants.actionItemImage)
                    .font(.system(size: Constants.actionItemIconSize, weight: .semibold))
                    .foregroundStyle(Color.indigo500)

                Text(Constants.actionItemsTitle)
                    .appFont(.footnote, weight: .semibold, color: .indigo600)
            }

            if actionItems.isEmpty {
                Text(Constants.emptyActionItems)
                    .appFont(.subheadline, color: .grey500)
            } else {
                ForEach(actionItems, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: DefaultSpacing.spacing8) {
                        Image(systemName: Constants.bulletImage)
                            .font(.system(size: Constants.bulletIconSize))
                            .foregroundStyle(Color.indigo400)

                        Text(item)
                            .appFont(.subheadline, weight: .medium, color: .grey900)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Constants.cardPadding)
        // 톤을 반투명으로 깔면 화면 배경(`grey100` 55%)과 섞여 라이트 모드에서 카드 경계가
        // 사라진다. 불릿 카드와 시각적으로 갈라지는 게 이 섹션의 존재 이유라 원색으로 채운다.
        .background {
            ConcentricRectangle(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
            .fill(Color.indigo100)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Constants.actionItemsTitle)
    }

    private var resultActions: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            MainButton(Constants.originalTitle) { dismiss() }
                .buttonStyle(.glass)

            MainButton(Constants.retryTitle) {
                Task { await viewModel.retrySummary() }
            }
            .buttonStyle(.glassProminent)
        }
    }

    private func failureCard(_ error: AppError) -> some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            Image(systemName: Constants.failureImage)
                .font(.system(size: Constants.failureIconSize, weight: .medium))
                .foregroundStyle(Color.grey400)

            Text(Constants.failureTitle)
                .appFont(.callout, weight: .semibold, color: .grey700)

            Text(error.userMessage)
                .appFont(.footnote, color: .grey500)
                .multilineTextAlignment(.center)

            MainButton(Constants.retryTitle) {
                Task { await viewModel.retrySummary() }
            }
            .buttonStyle(.glassProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(Constants.cardPadding)
        .glassEffect(
            .regular,
            in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius))
        )
    }

    private var disclaimer: some View {
        Text(Constants.disclaimer)
            .appFont(.caption2, color: .grey500)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Shimmer

/// 요약이 오기 전 자리를 잡아 주는 뼈대 줄.
///
/// 그라디언트의 시작·끝 지점을 애니메이션해 빛이 지나가게 만든다. 마스크를 오프셋으로 미는
/// 흔한 방식은 뷰 너비를 알아야 해서 `GeometryReader` 가 붙는데, 여기서는 그 값이 필요 없다.
private struct ShimmerBar: View {

    // MARK: - Property

    let trailingInset: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isAnimating = false

    // MARK: - Body

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [.grey100, .grey200, .grey100],
                    startPoint: isAnimating ? .init(x: 1, y: 0.5) : .init(x: -1, y: 0.5),
                    endPoint: isAnimating ? .init(x: 2, y: 0.5) : .init(x: 0, y: 0.5)
                )
            )
            .frame(height: Constants.shimmerBarHeight)
            .padding(.trailing, trailingInset)
            // 끝나지 않는 반복 애니메이션이라 모션 민감 사용자에게는 그대로 두면 안 된다.
            // 뼈대 줄 자체는 남긴다 — 자리를 잡아 주는 역할은 움직임과 무관하다.
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .linear(duration: Constants.shimmerDuration).repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}
