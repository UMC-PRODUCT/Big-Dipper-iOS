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

    static let ownCardTitle = "내 명함이에요"
    static let ownCardMessage = "다른 사람의 QR을 스캔하면 그 명함이 명함첩에 저장돼요."
    static let ownCardConfirm = "확인"

    static let expiredTitle = "만료된 QR이에요"
    static let expiredMessage = "상대에게 QR을 다시 띄워 달라고 해 주세요."
    static let expiredConfirm = "확인"

    static let consentMessage = "명함첩에 저장돼요. 저장하지 않으면 아무것도 남지 않아요."
    static let consentSave = "저장"
    static let consentCancel = "취소"
}

/// QR·공유 링크로 들어온 상대 명함을 명함첩에 넣는다.
///
/// QR 화면(MP-F04)이 「QR을 스캔하면 내 명함이 저장돼요」라고 약속하는 그 수신 측이다.
/// 링크가 나르는 값은 `memberId` 하나뿐이라 명함 내용은 **서버에서 받아 온다** — 페이로드를
/// 통째로 들고 오는 근거리 교환과 다른 점이다. 저장은 같은 UseCase 의 딥링크 진입점을 타므로
/// 명함첩의 중복 판정·삭제 규칙이 두 경로에서 같다.
///
/// 딥링크와 인앱 스캐너가 **둘 다 여기로 모인다** — 만료 확인과 저장 동의(#1226)를 여기
/// 한 곳에만 두면 두 경로가 자동으로 같은 규칙을 따른다.
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

    /// 동의 버튼이 띄운 저장 작업. 버튼 액션이 동기라 Task 로 나가는데, 붙잡아 두지 않으면
    /// 완료 시점을 아무도 알 수 없다 — 테스트가 이 값을 기다린다.
    private(set) var saveTask: Task<Void, Never>?

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

    /// 링크가 가리키는 상대 명함을 조회하고, **사용자 동의를 받은 뒤** 명함첩에 저장한다.
    ///
    /// 조회까지만 자동으로 하고 저장은 확인을 받는다 (#1226) — 남의 QR 이 찍히는 순간
    /// 연락처가 말없이 쌓이지 않게. 이름을 물어보려면 명함을 먼저 받아야 해서 조회가 앞선다.
    public func receive(link: CardLink) async {
        guard !isReceiving else { return }
        isReceiving = true
        defer { isReceiving = false }

        guard !link.isExpired() else {
            alertPrompt = AlertPrompt(
                title: Constants.expiredTitle,
                message: Constants.expiredMessage,
                positiveBtnTitle: Constants.expiredConfirm
            )
            return
        }

        // 자기 QR 이면 동의를 물을 일이 아니다. 저장 UseCase 도 같은 판정을 하지만(그게 정본),
        // 「내 명함을 저장할까요?」를 띄우지 않으려면 여기서 먼저 갈라야 한다.
        guard link.memberId != ownerMemberIdProvider() else {
            alertPrompt = ownCardPrompt()
            return
        }

        do {
            let card = try await fetchPeerCard.execute(memberId: link.memberId)
            alertPrompt = consentPrompt(for: card)
        } catch is CancellationError {
            return
        } catch {
            handle(error)
        }
    }

    public func dismissCompletion() {
        savedCard = nil
    }

    // MARK: - Private Function

    private func consentPrompt(for card: MyCard) -> AlertPrompt {
        AlertPrompt(
            title: "\(card.name)님의 명함을 저장할까요?",
            message: Constants.consentMessage,
            positiveBtnTitle: Constants.consentSave,
            positiveBtnAction: { [weak self] in
                // 버튼 액션은 동기라 저장을 Task 로 넘긴다. `@MainActor` 컨텍스트에서
                // 만들어져 액터를 물려받으므로 명함 저장소의 mainContext 규약을 지킨다.
                self?.saveTask = Task { await self?.save(card) }
            },
            negativeBtnTitle: Constants.consentCancel
        )
    }

    /// 동의를 받은 뒤의 실제 저장. 취소하면 이 경로를 아예 타지 않는다.
    private func save(_ card: MyCard) async {
        guard !isReceiving else { return }
        isReceiving = true
        defer { isReceiving = false }

        do {
            let saved = try await saveReceivedCard.execute(
                card: card,
                cardID: Self.cardID(memberId: card.memberId),
                ownerMemberId: ownerMemberIdProvider(),
                // 출처는 ``ExchangeMethod`` 가 타입으로 들고 간다 (#1227). 맥락 메모 칸에
                // "QR 링크" 를 적어 두면 사용자가 메모를 고치는 순간 출처가 사라진다.
                exchangeContext: nil,
                exchangeMethod: .qrLink
            )

            guard let saved else {
                // 소유자 판정이 UseCase 안에서 갈린 경우 — 위 사전 확인이 놓친 자기 명함이다.
                alertPrompt = ownCardPrompt()
                return
            }

            savedCard = saved
        } catch is CancellationError {
            return
        } catch {
            handle(error)
        }
    }

    /// 아무 일도 안 일어나면 스캔이 고장 났다고 읽히므로 저장하지 않았다는 사실을 밝힌다.
    private func ownCardPrompt() -> AlertPrompt {
        AlertPrompt(
            title: Constants.ownCardTitle,
            message: Constants.ownCardMessage,
            positiveBtnTitle: Constants.ownCardConfirm
        )
    }

    private func handle(_ error: Error) {
        errorHandler.handle(
            error,
            context: ErrorContext(feature: Constants.feature, action: Constants.action)
        )
    }

    // MARK: - Static Function

    /// 명함첩 키. memberId 에서 **결정적으로** 만들어 같은 사람을 여러 번 스캔해도 한 장이다.
    /// 저장소는 memberId 를 먼저 보고 이 값을 보조 키로 쓴다 — 근거리 교환으로 이미 받은
    /// 상대를 QR 로 다시 받아도 두 장이 되지 않는다.
    static func cardID(memberId: String) -> String { "QR-\(memberId)" }
}
