//
//  ExchangeCompletedView.swift
//  BusinessCardPresentation
//
//  Created by One on 8/18/26.
//

import SwiftUI
import BusinessCardDomain
import CoreDesignSystem
import CoreUIComponents
import UMCFoundation

// MARK: - Constants

private enum Constants {
    static let title = "명함을 주고받았어요!"
    static let continueTitle = "계속 교환하기"
    static let finishTitle = "확인"

    static func message(name: String) -> String {
        "\(name)님의 명함이 명함첩에 저장됐어요"
    }
}

private enum Metrics {
    static let illustrationSize: CGFloat = 200
    /// 시안 실측 폭. **상한**이다 — 고정하면 큰 글자에서 문구가 넘치고,
    /// 그렇다고 풀어 두면 한 줄이 화면 끝까지 늘어져 시안 리듬이 깨진다.
    static let messageMaxWidth: CGFloat = 228
    static let illustrationSpacing: CGFloat = 16
    static let textSpacing: CGFloat = 4
    static let buttonSpacing: CGFloat = 10
    static let horizontalMargin: CGFloat = 16
    static let bottomMargin: CGFloat = 16
}

/// 교환 완료 (시안 `12657:37758`).
///
/// **상대 명함을 보여주지 않는다** — 시안에 카드도 미리보기도 없고 일러스트와 문구뿐이다.
/// 받은 명함은 이미 명함첩에 저장돼 있고, 이 화면은 그 사실만 알린다.
///
/// - Important: 시안에 내비게이션 바·뒤로가기가 없다. 두 버튼이 유일한 이탈 경로라
///   모달로 띄우는 것이 전제다.
struct ExchangeCompletedView: View {

    // MARK: - Property

    let card: ReceivedCard

    /// 「계속 교환하기」. 근거리 교환에서만 의미가 있어 QR 링크 경로는 `nil` 로 감춘다 —
    /// 링크로 받은 사람에게는 이어서 교환할 세션이 없다.
    let onContinue: (() -> Void)?
    let onFinish: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: .zero) {
            Spacer(minLength: .zero)

            VStack(spacing: Metrics.illustrationSpacing) {
                Image.umcExchangeCompleted
                    .resizable()
                    .frame(width: Metrics.illustrationSize, height: Metrics.illustrationSize)
                    .accessibilityHidden(true)

                message
            }

            Spacer(minLength: .zero)

            buttons
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.grey000)
    }

    // MARK: - View Component

    private var message: some View {
        VStack(spacing: Metrics.textSpacing) {
            // 시안은 Pretendard Bold 지만 `AppFontWeight` 에 bold 가 없어 semibold 로 간다.
            // 확장하려면 `Core/DesignSystem/Resources/Fonts/` 에 `Pretendard-Bold.otf` 가
            // 먼저 들어와야 한다 — 파일 없이 케이스만 늘리면 `Font.custom` 이 조용히
            // 시스템 서체로 떨어진다 (#1237).
            Text(Constants.title)
                .appFont(.title2, weight: .semibold, color: .grey900)

            Text(Constants.message(name: card.profile.name))
                .appFont(.subheadline, color: .grey600)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: Metrics.messageMaxWidth)
        // 제목과 안내가 한 덩어리로 읽혀야 한다 — 나눠 읽으면 이름이 문맥 없이 뜬다.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var buttons: some View {
        VStack(spacing: Metrics.buttonSpacing) {
            if let onContinue {
                CardActionButton(
                    title: Constants.continueTitle,
                    role: .primary,
                    action: onContinue
                )
                CardActionButton(title: Constants.finishTitle, role: .secondary, action: onFinish)
            } else {
                // 버튼이 하나뿐이면 그게 주 동작이다 — 회색 버튼만 남기면 유일한 이탈
                // 경로가 부차적으로 보인다.
                CardActionButton(title: Constants.finishTitle, role: .primary, action: onFinish)
            }
        }
        .padding(.horizontal, Metrics.horizontalMargin)
        .padding(.bottom, Metrics.bottomMargin)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("교환 완료") {
    ExchangeCompletedView(
        card: BusinessCardPreviewData.receivedCard,
        onContinue: {},
        onFinish: {}
    )
}
#endif
