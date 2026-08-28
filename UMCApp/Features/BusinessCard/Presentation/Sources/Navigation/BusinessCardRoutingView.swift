//
//  BusinessCardRoutingView.swift
//  BusinessCardPresentation
//
//  Created by One on 8/18/26.
//

import CoreDI
import SwiftUI
import UMCFoundation

/// ``BusinessCardDestination``을 실제 화면으로 바꾸는 라우팅 뷰.
///
/// 마이페이지 탭 루트가 `.navigationDestination(for: BusinessCardDestination.self)`에서
/// 사용한다. `BusinessCardDestination`이 `public`인 이유(App 셸이 목적지 값을 만들고 등록)와
/// 짝을 이뤄, 이 타입도 App 셸이 등록할 수 있도록 `public`으로 연다 (선례: `MyPageRoutingView`).
///
/// - Important: 자체 `NavigationStack`을 만들지 않는다. 탭별 스택은 상위 셸이 소유한다.
public struct BusinessCardRoutingView: View {

    // MARK: - Property

    @Environment(ErrorHandler.self) private var errorHandler

    private let destination: BusinessCardDestination
    private let container: DIContainer

    // MARK: - Init

    public init(destination: BusinessCardDestination, container: DIContainer) {
        self.destination = destination
        self.container = container
    }

    // MARK: - Body

    public var body: some View {
        let provider = container.resolve(BusinessCardUseCaseProviding.self)

        switch destination {
        case .receivedCards:
            ReceivedCardsView(
                viewModel: ReceivedCardsViewModel(
                    fetchReceivedCards: provider.fetchReceivedCardsUseCase,
                    deleteReceivedCard: provider.deleteReceivedCardUseCase,
                    errorHandler: errorHandler
                )
            )

        case .cardQR:
            CardQRView(
                viewModel: CardQRViewModel(
                    fetchMyCard: provider.fetchMyCardUseCase,
                    generateCardQR: provider.generateCardQRUseCase,
                    imageSaver: PhotoLibraryCardImageSaver(),
                    errorHandler: errorHandler
                )
            )

        case .exchange:
            CardExchangeView(
                viewModel: CardExchangeViewModel(
                    fetchMyCard: provider.fetchMyCardUseCase,
                    exchangeCards: provider.exchangeCardsUseCase,
                    errorHandler: errorHandler
                )
            )

        // 스캔 화면은 provider 를 쓰지 않는다 — 수신 모디파이어가 컨테이너에서 직접
        // UseCase 를 꺼내므로 컨테이너만 넘긴다.
        case .scan:
            CardScanView(container: container, viewModel: CardScanViewModel())
        }
    }
}
