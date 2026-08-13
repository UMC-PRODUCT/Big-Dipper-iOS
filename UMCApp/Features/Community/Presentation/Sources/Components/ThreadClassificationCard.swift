//
//  ThreadClassificationCard.swift
//  CommunityPresentation
//

import SwiftUI
import CommunityDomain
import CoreDesignSystem
import CoreUIComponents

// MARK: - Constants

fileprivate enum Constants {
    static let engineLabel = "Apple Intelligence"
    static let onDeviceLabel = "온디바이스"
    static let idleHint = "제목과 특징을 채우면 카테고리와 아이콘을 대신 정해 드려요."
    static let idleDisabledHint = "스레드 특징을 입력하면 분류할 수 있어요."
    static let classifyTitle = "AI로 분류하기"
    static let reclassifyTitle = "다시 분류하기"
    static let changeIconTitle = "이모지 변경하기"
    static let loadingTitle = "스레드를 살펴보고 있어요"
    static let resultTitle = "이렇게 분류했어요"
    static let failureTitle = "분류하지 못했어요"
    static let unavailableTitle = "자동 분류를 쓸 수 없어요"
    static let unavailableMessage = """
    이 기기에서는 Apple Intelligence 를 사용할 수 없어요. \
    카테고리와 이모지를 직접 골라 주세요.
    """
    static let manualHint = "마음에 들지 않으면 카테고리와 이모지를 직접 바꿀 수 있어요."

    static let sparklesImage = "sparkles"
    static let failureImage = "exclamationmark.circle"

    static let headerIconSize: CGFloat = 16
    static let resultIconSize: CGFloat = 34
    static let cardPadding: EdgeInsets = .init(
        top: DefaultSpacing.spacing16,
        leading: DefaultConstant.defaultSafeHorizon,
        bottom: DefaultSpacing.spacing16,
        trailing: DefaultConstant.defaultSafeHorizon
    )
    /// 줄마다 오른쪽을 다르게 비워 실제 문단처럼 보이게 한다.
    static let shimmerBarInsets: [CGFloat] = [0, DefaultSpacing.spacing48]
    static let aiBorderWidth: CGFloat = 1

    /// AI 처리 중임을 알리는 그라디언트. 대화 요약 시트와 같은 값으로 맞춘다.
    static let aiGradient = LinearGradient(
        colors: [.indigo300, .indigo500, .indigo700],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// 생성·편집 폼 안의 온디바이스 분류 카드.
///
/// 아이콘·카테고리·근거를 한 카드에 묶는다. 분류 결과를 폼 필드에만 반영하고 카드를 두지
/// 않으면, 카테고리가 왜 바뀌었는지 알 수 없는 채로 값만 바뀌어 있다.
///
/// 미지원 기기에서도 카드를 감추지 않는다 — 안내를 띄워야 사용자가 직접 고르러 간다.
struct ThreadClassificationCard: View {

    // MARK: - Property

    let viewModel: any ThreadClassificationPresenting

    /// 이모지 칸으로 포커스를 옮긴다. 포커스는 폼이 들고 있어 화면이 넘겨 준다.
    let onChangeIcon: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            header
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Constants.cardPadding)
        .glassEffect(
            .regular,
            in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius))
        )
        // 처리 중임을 색으로도 알린다. 진행바 하나만으로는 일반 로딩과 구분되지 않는다.
        .overlay {
            if viewModel.classification.isLoading {
                ConcentricRectangle(
                    corners: .concentric(minimum: DefaultConstant.concentricRadius),
                    isUniform: true
                )
                .stroke(Constants.aiGradient, lineWidth: Constants.aiBorderWidth)
            }
        }
    }

    // MARK: - View Component

    /// 무엇이 정한 값인지. "온디바이스" 는 입력한 특징이 기기 밖으로 나가지 않는다는 뜻이라
    /// 브랜드 표기만큼 중요한 정보다.
    private var header: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Image(systemName: Constants.sparklesImage)
                .font(.system(size: Constants.headerIconSize, weight: .medium))
                .foregroundStyle(Color.indigo500)
                .symbolEffect(
                    .variableColor.iterative.reversing,
                    isActive: viewModel.classification.isLoading
                )

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
        if !viewModel.isClassificationAvailable {
            unavailableContent
        } else {
            switch viewModel.classification {
            case .idle:
                idleContent
            case .loading:
                loadingContent
            case .loaded(let classification):
                resultContent(classification)
            case .failed:
                failureContent
            }
        }
    }

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            Text(viewModel.canClassify ? Constants.idleHint : Constants.idleDisabledHint)
                .appFont(.footnote, color: .grey500)
                .frame(maxWidth: .infinity, alignment: .leading)

            MainButton(Constants.classifyTitle) { classify() }
                .buttonStyle(.glassProminent)
                .disabled(!viewModel.canClassify)
        }
    }

    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            Text(Constants.loadingTitle)
                .appFont(.footnote, weight: .semibold, color: .grey700)

            ProgressView()
                .progressViewStyle(.linear)
                .tint(Color.indigo500)

            ForEach(Constants.shimmerBarInsets, id: \.self) { inset in
                ShimmerBar(trailingInset: inset)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Constants.loadingTitle)
    }

    /// 아이콘·카테고리·근거 3요소.
    ///
    /// 근거를 빼면 사용자가 결과를 검토할 근거가 없어 그대로 통과시키게 된다.
    private func resultContent(_ classification: ThreadClassification) -> some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            HStack(spacing: DefaultSpacing.spacing12) {
                Text(classification.icon)
                    .font(.system(size: Constants.resultIconSize))

                VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                    Text(Constants.resultTitle)
                        .appFont(.caption1, color: .grey500)

                    Text(classification.category.displayName)
                        .appFont(.body, weight: .semibold, color: .grey900)
                }

                Spacer(minLength: 0)
            }

            Text(classification.reason)
                .appFont(.footnote, color: .grey700)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(Constants.manualHint)
                .appFont(.caption2, color: .grey500)
                .frame(maxWidth: .infinity, alignment: .leading)

            actions
        }
        .accessibilityElement(children: .contain)
    }

    private var failureContent: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            Label {
                Text(Constants.failureTitle)
                    .appFont(.footnote, weight: .semibold, color: .grey700)
            } icon: {
                Image(systemName: Constants.failureImage)
                    .foregroundStyle(Color.grey400)
            }

            if let message = viewModel.classificationErrorMessage {
                Text(message)
                    .appFont(.footnote, color: .grey500)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(Constants.manualHint)
                .appFont(.caption2, color: .grey500)
                .frame(maxWidth: .infinity, alignment: .leading)

            actions
        }
    }

    /// 미지원 기기. 분류는 잠기지만 이모지 변경은 남는다 — 손으로 고르는 길까지 막을 이유가 없다.
    private var unavailableContent: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            Text(Constants.unavailableTitle)
                .appFont(.footnote, weight: .semibold, color: .grey700)

            Text(Constants.unavailableMessage)
                .appFont(.footnote, color: .grey500)
                .frame(maxWidth: .infinity, alignment: .leading)

            actions
        }
    }

    /// "다시 분류하기" 는 미지원·특징 미입력·처리 중에 잠긴다. "이모지 변경하기" 는 항상 열려 있다.
    private var actions: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            MainButton(Constants.reclassifyTitle) { classify() }
                .buttonStyle(.glassProminent)
                .disabled(!viewModel.canClassify)

            MainButton(Constants.changeIconTitle, action: onChangeIcon)
                .buttonStyle(.glass)
        }
    }

    // MARK: - Function

    private func classify() {
        Task { await viewModel.classify() }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("분류 전") {
    ThreadClassificationCard(
        viewModel: previewViewModel(description: "매주 화요일 8시에 모여서 iOS 공부해요"),
        onChangeIcon: {}
    )
    .padding(DefaultSpacing.spacing16)
}

#Preview("미지원 기기") {
    ThreadClassificationCard(
        viewModel: previewViewModel(
            description: "매주 화요일 8시에 모여서 iOS 공부해요",
            isAvailable: false
        ),
        onChangeIcon: {}
    )
    .padding(DefaultSpacing.spacing16)
}

@MainActor
private func previewViewModel(
    description: String,
    isAvailable: Bool = true
) -> CommunityThreadCreateViewModel {
    let viewModel = CommunityThreadCreateViewModel(
        useCase: PreviewCreateUseCase(),
        classifier: PreviewClassifier(isAvailable: isAvailable)
    )
    viewModel.title = "iOS 스터디"
    viewModel.threadDescription = description
    return viewModel
}

private struct PreviewClassifier: ThreadClassifying {
    let isAvailable: Bool

    func classify(title: String, description: String) async throws -> ThreadClassification {
        ThreadClassification(
            category: .study,
            icon: "📚",
            reason: "매주 정해진 시간에 모여 공부한다는 내용이 있어 스터디로 봤어요."
        )
    }
}

private struct PreviewCreateUseCase: CommunityThreadCreateUseCaseProtocol {
    func create(
        title: String,
        description: String,
        category: CommunityThreadCategory,
        icon: String
    ) async throws -> CommunityThread {
        throw ThreadClassificationError.unavailable
    }
}
#endif
