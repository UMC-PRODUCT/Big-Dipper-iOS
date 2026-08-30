import SwiftUI

// MARK: - WatchButtonRole

/// 워치 액션 버튼 역할. Glass 는 **컨트롤에만** 허용되므로 세 역할 모두 Glass 배리언트를 쓴다.
public enum WatchButtonRole: Sendable, CaseIterable {
    /// 화면당 1개. `.glassProminent` + 인디고 tint.
    case primary
    /// 보조 액션. `.glass` 중립(tint 없음).
    case secondary
    /// 파괴적이지만 **채우지 않는** 안전형. `.glass` + 에러 레드 tint.
    /// 빨간 채움 버튼은 워치 좁은 화면에서 오탭을 유도하므로 쓰지 않는다.
    case destructive
}

// MARK: - WatchActionButton

/// 워치 공통 CTA. 캡슐 형태는 watchOS Glass 버튼 스타일의 기본값이라 별도 지정하지 않는다.
///
/// 비활성은 `disabledReason` 으로만 만든다 — **사유 없는 비활성 버튼을 만들 수 없다**.
/// 비활성일 때 버튼은 회색조 `.glass` 로 바뀌고, 사유가 버튼 아래 캡션으로 노출되며
/// VoiceOver 에는 `accessibilityValue` 로 전달된다(캡션 자체는 중복 낭독 방지로 숨김).
/// hint 가 아니라 value 인 이유: hint 는 VoiceOver 설정에서 꺼질 수 있는 보조 정보인데
/// "왜 못 누르는가"는 필수 정보다.
///
/// 높이를 고정하지 않는다 — iOS `PrimaryButtonStyle`(height 44) 을 워치에 가져오면
/// 큰 Dynamic Type 에서 라벨이 잘린다.
public struct WatchActionButton: View {

    // MARK: - Property

    private let title: String
    private let role: WatchButtonRole
    private let systemImage: String?
    private let disabledReason: String?
    private let action: () -> Void

    // MARK: - Init

    /// - Note: `.primary` 는 화면당 1개 제약이 있어 기본값으로 두지 않는다.
    ///   화면의 대표 CTA 에만 명시적으로 지정한다.
    public init(
        _ title: String,
        role: WatchButtonRole = .secondary,
        systemImage: String? = nil,
        disabledReason: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.role = role
        self.systemImage = systemImage
        self.disabledReason = disabledReason
        self.action = action
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: WatchLayout.tightSpacing) {
            styledButton

            if let disabledReason {
                Text(disabledReason)
                    .font(.watch(.caption))
                    .foregroundStyle(WatchColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Function

    @ViewBuilder
    private var styledButton: some View {
        if let disabledReason {
            baseButton
                .buttonStyle(.glass)
                .foregroundStyle(WatchColor.textDisabled)
                .disabled(true)
                .accessibilityValue(disabledReason)
        } else {
            switch role {
            case .primary:
                baseButton.buttonStyle(.glassProminent).tint(WatchColor.brandPrimary)
            case .secondary:
                baseButton.buttonStyle(.glass)
            case .destructive:
                baseButton.buttonStyle(.glass).tint(WatchColor.statusError)
            }
        }
    }

    private var baseButton: some View {
        Button(action: action) {
            label.frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var label: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
        } else {
            Text(title)
        }
    }
}

#if DEBUG
private struct WatchActionButtonGallery: View {

    var body: some View {
        ScrollView {
            VStack(spacing: WatchLayout.stackSpacing) {
                WatchActionButton("출석 체크", role: .primary, systemImage: "checkmark") {}
                WatchActionButton("나중에", role: .secondary) {}
                WatchActionButton("출석 취소", role: .destructive) {}
                WatchActionButton(
                    "출석 체크",
                    disabledReason: "출석 장소에서 200m 밖입니다"
                ) {}
            }
            .padding(.horizontal, WatchLayout.screenHorizontalPadding)
        }
        .watchScreenBackground()
    }
}

#Preview("WatchActionButton — 4 상태") {
    NavigationStack {
        WatchActionButtonGallery()
    }
}

#Preview("WatchActionButton — A11y 크기") {
    NavigationStack {
        WatchActionButtonGallery()
    }
    .dynamicTypeSize(.accessibility3)
}
#endif
