import CoreWatchDesignSystem
import SwiftUI

// MARK: - WatchFallbackScene

/// 폴백 화면 공통 스켈레톤(심볼 + 제목 + 설명 + 힌트 + CTA). 배경·래핑은 호출자가 고른다 —
/// `WatchFallbackView` 는 전체 화면(`watchScreenBackground()`)으로, `WatchOfflineQueueCard`·
/// `WatchMandatoryNoticeBanner` 는 카드(`watchCard(...)`)로 감싸 재사용한다.
struct WatchFallbackScene: View {

    // MARK: - Property

    let presentation: WatchFallbackPresentation
    /// 핸들러를 넘기지 않으면 해당 CTA 를 **그리지 않는다** — 눌러도 아무 일도 없는 버튼이
    /// 곧 무음 실패이므로, 동작 없는 CTA 를 구조적으로 만들 수 없게 옵셔널로 둔다.
    var onPrimaryAction: (() -> Void)?
    var onSecondaryAction: (() -> Void)?

    // MARK: - Body

    var body: some View {
        VStack(spacing: WatchLayout.stackSpacing) {
            symbol
            textBlock
            actions
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Function

    /// 심볼은 접근성 트리에서 숨긴다 — 같은 정보가 `title` 텍스트로 이미 전달된다.
    private var symbol: some View {
        Image(systemName: presentation.symbolName)
            .font(.watch(.screenTitle))
            .foregroundStyle(presentation.status.tint)
            .accessibilityHidden(true)
    }

    /// 제목·설명·힌트를 하나의 접근성 요소로 합쳐 한 번에 낭독한다.
    private var textBlock: some View {
        VStack(spacing: WatchLayout.tightSpacing) {
            Text(presentation.title)
                .font(.watch(.screenTitle))
                .foregroundStyle(WatchColor.textPrimary)
            Text(presentation.message)
                .font(.watch(.cardValue))
                .foregroundStyle(WatchColor.textSecondary)
            if let hint = presentation.hint {
                Text(hint)
                    .font(.watch(.caption))
                    .foregroundStyle(WatchColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// 비활성 CTA 가 있으면 그것만 그린다 — `disabledAction` 은 "사유 없는 비활성 금지" 규약상
    /// 활성 액션과 공존할 이유가 없다(비활성인 이상 primary/secondary 는 의미가 없다).
    @ViewBuilder
    private var actions: some View {
        if let disabledAction = presentation.disabledAction {
            WatchActionButton(disabledAction.title, disabledReason: disabledAction.reason) {}
        } else {
            if let primary = presentation.primaryAction, let onPrimaryAction {
                WatchActionButton(
                    primary.title,
                    role: .primary,
                    systemImage: primary.systemImage,
                    action: onPrimaryAction
                )
            }
            if let secondary = presentation.secondaryAction, let onSecondaryAction {
                WatchActionButton(
                    secondary.title,
                    systemImage: secondary.systemImage,
                    action: onSecondaryAction
                )
            }
        }
    }
}

#if DEBUG
#Preview("WatchFallbackScene — 9종 갤러리") {
    NavigationStack {
        ScrollView {
            VStack(spacing: WatchLayout.stackSpacing) {
                ForEach(WatchFallbackReason.allCases, id: \.self) { reason in
                    WatchFallbackScene(
                        presentation: reason.presentation,
                        onPrimaryAction: {},
                        onSecondaryAction: {}
                    )
                    .watchCard()
                }
            }
            .padding(.horizontal, WatchLayout.screenHorizontalPadding)
        }
        .watchScreenBackground()
    }
}

#Preview("WatchFallbackScene — A11y 크기") {
    NavigationStack {
        ScrollView {
            WatchFallbackScene(
                presentation: WatchFallbackReason.checkInRequestFailed.presentation,
                onPrimaryAction: {},
                onSecondaryAction: {}
            )
            .watchCard()
            .padding(.horizontal, WatchLayout.screenHorizontalPadding)
        }
        .watchScreenBackground()
    }
    .dynamicTypeSize(.accessibility3)
}
#endif
