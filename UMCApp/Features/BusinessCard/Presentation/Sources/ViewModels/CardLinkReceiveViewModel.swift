//
//  CardLinkReceiveViewModel.swift
//  BusinessCardPresentation
//
//  Created by One on 8/19/26.
//

import Foundation
import BusinessCardDomain
import UMCFoundation

// MARK: - Constants

private enum Constants {
    static let feature = "BusinessCard"
    static let action = "receiveCardLink"

    /// 명함첩 행에 남는 출처 표기. 근거리 교환과 구분된다.
    static let exchangeContext = "QR 링크"

    static let ownCardTitle = "내 명함이에요"
    static let ownCardMessage = "다른 사람의 QR을 스캔하면 그 명함이 명함첩에 저장돼요."
    static let ownCardConfirm = "확인"
}

/// QR·공유 링크로 들어온 상대 명함을 명함첩에 넣는다.
///
/// QR 화면(MP-F04)이 「QR을 스캔하면 내 명함이 저장돼요」라고 약속하는 그 수신 측이다.
/// 링크가 나르는 값은 `memberId` 하나뿐이라 명함 내용은 **서버에서 받아 온다** — 페이로드를
/// 통째로 들고 오는 근거리 교환과 다른 점이다. 저장은 같은 UseCase 의 딥링크 진입점을 타므로
/// 명함첩의 중복 판정·삭제 규칙이 두 경로에서 같다.
///
/// - Important: `@MainActor` — 명함 저장소가 SwiftData `mainContext` 를 탄다.
@MainActor
@Observable
public final class CardLinkReceiveViewModel {

    // MARK: - Property

    /// 저장에 성공한 명함. 완료 화면이 이 값으로 뜬다.
    public private(set) var savedCard: ReceivedCard?

    /// 자기 QR 을 스캔한 경우처럼 저장할 게 없을 때의 안내.
    public var alertPrompt: AlertPrompt?

    /// 조회·저장이 도는 중. 같은 링크가 연달아 들어와도 한 번만 처리한다.
    public private(set) var isReceiving = false

    private let fetchPeerCard: FetchPeerCardUseCaseProtocol
    private let saveReceivedCard: SaveReceivedCardUseCaseProtocol
    private let ownerMemberIdProvider: @Sendable () -> String
    private let errorHandler: ErrorHandler

    // MARK: - Init

    /// - Parameter ownerMemberIdProvider: 내 memberId 를 읽는다. 자기 명함이 명함첩에
    ///   섞이지 않게 저장 UseCase 가 이 값으로 거른다. 로그인 저장소를 매번 다시 읽어야
    ///   해서(로그인 전에 링크가 도착할 수 있다) 값이 아니라 클로저로 받는다.
    public init(
        fetchPeerCard: FetchPeerCardUseCaseProtocol,
        saveReceivedCard: SaveReceivedCardUseCaseProtocol,
        ownerMemberIdProvider: @escaping @Sendable () -> String,
        errorHandler: ErrorHandler
    ) {
        self.fetchPeerCard = fetchPeerCard
        self.saveReceivedCard = saveReceivedCard
        self.ownerMemberIdProvider = ownerMemberIdProvider
        self.errorHandler = errorHandler
    }

    // MARK: - Function

    /// 링크의 `memberId` 로 상대 명함을 받아 명함첩에 저장한다.
    public func receive(memberId: String) async {
        guard !isReceiving else { return }
        isReceiving = true
        defer { isReceiving = false }

        do {
            let card = try await fetchPeerCard.execute(memberId: memberId)
            let saved = try await saveReceivedCard.execute(
                card: card,
                cardID: Self.cardID(memberId: memberId),
                ownerMemberId: ownerMemberIdProvider(),
                exchangeContext: Constants.exchangeContext
            )

            guard let saved else {
                // 자기 QR 을 찍은 경우다. 아무 일도 안 일어나면 스캔이 고장 났다고 읽히므로
                // 저장하지 않았다는 사실을 밝힌다.
                alertPrompt = AlertPrompt(
                    title: Constants.ownCardTitle,
                    message: Constants.ownCardMessage,
                    positiveBtnTitle: Constants.ownCardConfirm
                )
                return
            }

            savedCard = saved
        } catch is CancellationError {
            return
        } catch {
            errorHandler.handle(
                error,
                context: ErrorContext(feature: Constants.feature, action: Constants.action)
            )
        }
    }

    public func dismissCompletion() {
        savedCard = nil
    }

    // MARK: - Static Function

    /// 명함첩 키. memberId 에서 **결정적으로** 만들어 같은 사람을 여러 번 스캔해도 한 장이다.
    /// 저장소는 memberId 를 먼저 보고 이 값을 보조 키로 쓴다 — 근거리 교환으로 이미 받은
    /// 상대를 QR 로 다시 받아도 두 장이 되지 않는다.
    static func cardID(memberId: String) -> String { "QR-\(memberId)" }
}
