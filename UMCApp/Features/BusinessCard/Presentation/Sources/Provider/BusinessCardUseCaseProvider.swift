//
//  BusinessCardUseCaseProvider.swift
//  BusinessCardPresentation
//
//  Created by One on 8/16/26.
//

import Foundation
import BusinessCardDomain
import CoreNearbyExchange

/// BusinessCard Presentation 레이어의 UseCase Bundle Protocol.
/// ViewModel이 개별 UseCase 대신 Provider 한 개로 묶어 받는다 (MyPage 패턴).
public protocol BusinessCardUseCaseProviding {
    var fetchMyCardUseCase: FetchMyCardUseCaseProtocol { get }
    var fetchReceivedCardsUseCase: FetchReceivedCardsUseCaseProtocol { get }
    var saveReceivedCardUseCase: SaveReceivedCardUseCaseProtocol { get }
    var deleteReceivedCardUseCase: DeleteReceivedCardUseCaseProtocol { get }
    var fetchActivityStatUseCase: FetchActivityStatUseCaseProtocol { get }
    var generateCardQRUseCase: GenerateCardQRUseCaseProtocol { get }
    var exchangeCardsUseCase: ExchangeCardsUseCaseProtocol { get }
}

public final class BusinessCardUseCaseProvider: BusinessCardUseCaseProviding {

    // MARK: - Property

    public let fetchMyCardUseCase: FetchMyCardUseCaseProtocol
    public let fetchReceivedCardsUseCase: FetchReceivedCardsUseCaseProtocol
    public let saveReceivedCardUseCase: SaveReceivedCardUseCaseProtocol
    public let deleteReceivedCardUseCase: DeleteReceivedCardUseCaseProtocol
    public let fetchActivityStatUseCase: FetchActivityStatUseCaseProtocol
    public let generateCardQRUseCase: GenerateCardQRUseCaseProtocol
    public let exchangeCardsUseCase: ExchangeCardsUseCaseProtocol

    // MARK: - Init

    public init(
        businessCardRepository: BusinessCardRepositoryProtocol,
        receivedCardRepository: ReceivedCardRepositoryProtocol,
        activityStatRepository: ActivityStatRepositoryProtocol,
        qrGenerator: QRCodeGenerating,
        transport: NearbyTransportProtocol
    ) {
        let save = SaveReceivedCardUseCase(repository: receivedCardRepository)
        self.fetchMyCardUseCase = FetchMyCardUseCase(repository: businessCardRepository)
        self.fetchReceivedCardsUseCase = FetchReceivedCardsUseCase(
            repository: receivedCardRepository
        )
        self.saveReceivedCardUseCase = save
        self.deleteReceivedCardUseCase = DeleteReceivedCardUseCase(
            repository: receivedCardRepository
        )
        self.fetchActivityStatUseCase = FetchActivityStatUseCase(
            statRepository: activityStatRepository,
            receivedCardRepository: receivedCardRepository
        )
        self.generateCardQRUseCase = GenerateCardQRUseCase(generator: qrGenerator)
        self.exchangeCardsUseCase = ExchangeCardsUseCase(
            transport: transport,
            saveReceivedCard: save
        )
    }
}
