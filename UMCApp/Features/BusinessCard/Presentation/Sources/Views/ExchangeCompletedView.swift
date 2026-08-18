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
    static let messageWidth: CGFloat = 228
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
    let onContinue: () -> Void
    let onFinish: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: .zero) {
            Spacer(minLength: .zero)

            VStack(spacing: Metrics.illustrationSpacing) {
                Image.umcExchangeCompleted
                    .resizable()
                    .frame(width: Metrics.illustrationSize, height: Metrics.illustrationSize)

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
            Text(Constants.title)
                .appFont(.title2, weight: .semibold, color: .grey900)

            Text(Constants.message(name: card.profile.name))
                .appFont(.subheadline, color: .grey600)
                .multilineTextAlignment(.center)
        }
        .frame(width: Metrics.messageWidth)
    }

    private var buttons: some View {
        VStack(spacing: Metrics.buttonSpacing) {
            CardActionButton(title: Constants.continueTitle, role: .primary, action: onContinue)
            CardActionButton(title: Constants.finishTitle, role: .secondary, action: onFinish)
        }
        .padding(.horizontal, Metrics.horizontalMargin)
        .padding(.bottom, Metrics.bottomMargin)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("교환 완료") {
    ExchangeCompletedView(
        card: ReceivedCard(
            id: "1",
            profile: MyCard(
                memberId: "7", name: "박의정", nickname: "의정",
                part: .design, generation: "11", university: "중앙대학교",
                email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil
            ),
            exchangedAt: Date(timeIntervalSince1970: .zero),
            exchangeContext: nil
        ),
        onContinue: {},
        onFinish: {}
    )
}
#endif
