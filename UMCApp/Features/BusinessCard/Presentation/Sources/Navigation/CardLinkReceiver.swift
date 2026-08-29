//
//  CardLinkReceiver.swift
//  BusinessCardPresentation
//
//  Created by One on 8/19/26.
//

import SwiftUI
import BusinessCardDomain
import CoreDI
import UMCFoundation

/// 명함 링크 수신을 화면 한 곳에 붙이는 진입점.
public extension View {

    /// 명함 링크가 들어오면 상대 명함을 받아 명함첩에 저장하고 완료 화면을 덮는다.
    ///
    /// 앱 셸(딥링크)과 인앱 스캐너(``CardScanView``)가 같은 모디파이어로 들어온다 —
    /// 호출부는 명함 UseCase 나 완료 화면을 알 필요가 없다 (선례: ``BusinessCardRoutingView``).
    /// 처리를 마치면 바인딩을 `nil` 로 비워 같은 링크가 다시 열리지 않게 한다.
    ///
    /// - Parameter link: ``CardLink`` 통째로 받는다. `memberId` 만 넘기면 링크가 나르는
    ///   만료·서명(#1226)이 여기 닿기 전에 버려진다.
    func businessCardLinkReceiver(
        link: Binding<CardLink?>,
        container: DIContainer
    ) -> some View {
        modifier(CardLinkReceiverModifier(link: link, container: container))
    }
}

/// UseCase 를 컨테이너에서 꺼내 ViewModel 을 만드는 겉면.
///
/// `ErrorHandler` 가 환경에서만 오므로 ViewModel 을 `init` 에서 만들 수 없다. 생성은
/// `body` 에서 하고, 실제 상태 보유는 ``CardLinkReceiverCore`` 의 `@State` 가 맡는다.
private struct CardLinkReceiverModifier: ViewModifier {

    // MARK: - Property

    @Binding var link: CardLink?

    let container: DIContainer

    @Environment(ErrorHandler.self) private var errorHandler

    // MARK: - Body

    func body(content: Content) -> some View {
        let provider = container.resolve(BusinessCardUseCaseProviding.self)

        content.modifier(
            CardLinkReceiverCore(
                link: $link,
                viewModel: CardLinkReceiveViewModel(
                    fetchPeerCard: provider.fetchPeerCardUseCase,
                    saveReceivedCard: provider.saveReceivedCardUseCase,
                    // 로그인 시점에 저장되는 값이라 링크가 먼저 도착해도 읽는 순간엔 채워져
                    // 있다. 없으면 빈 문자열 — 저장 UseCase 가 아무도 거르지 않는다.
                    ownerMemberIdProvider: { AppStorageKey.memberIdString() ?? "" },
                    errorHandler: errorHandler
                )
            )
        )
    }
}

/// 링크를 실제로 처리하고 완료 화면을 띄우는 속.
private struct CardLinkReceiverCore: ViewModifier {

    // MARK: - Property

    @Binding var link: CardLink?

    @State private var viewModel: CardLinkReceiveViewModel

    // MARK: - Init

    init(link: Binding<CardLink?>, viewModel: CardLinkReceiveViewModel) {
        self._link = link
        self._viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            // `id:` 를 링크 값으로 두면 새 링크마다 다시 돈다. 처리 후 바인딩을 비우므로
            // 같은 상대를 다시 스캔해도 값이 nil → link 로 바뀌며 또 실행된다.
            .task(id: link) {
                guard let link else { return }
                await viewModel.receive(link: link)
                self.link = nil
            }
            .fullScreenCover(item: Binding(
                get: { viewModel.savedCard },
                set: { if $0 == nil { viewModel.dismissCompletion() } }
            )) { card in
                ExchangeCompletedView(
                    card: card,
                    onContinue: nil,
                    onFinish: { viewModel.dismissCompletion() }
                )
            }
            .alertPrompt(item: $viewModel.alertPrompt)
    }
}
