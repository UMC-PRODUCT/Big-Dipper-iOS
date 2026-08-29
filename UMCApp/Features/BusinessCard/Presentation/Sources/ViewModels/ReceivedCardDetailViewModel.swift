//
//  ReceivedCardDetailViewModel.swift
//  BusinessCardPresentation
//
//  Created by One on 8/28/26.
//

import CoreGraphics
import Foundation
import BusinessCardDomain
import UMCFoundation

// MARK: - Constants

private enum Constants {
    static let feature = "BusinessCard"

    static let deleteTitle = "명함을 삭제할까요?"
    static let deleteConfirm = "삭제"
    static let deleteCancel = "취소"

    static func deleteMessage(name: String) -> String {
        "\(name) 님의 명함을 명함첩에서 지웁니다. 다시 교환하기 전까지 되돌릴 수 없어요."
    }
}

/// 받은 명함 상세 (#1227).
///
/// 명함첩 그리드에서 받은 ``ReceivedCard`` 를 그대로 들고 시작한다 — 로컬 저장소에서
/// 다시 읽어도 같은 값이라 진입 시 재조회를 하지 않는다. 편집·삭제 결과만 이 안에서
/// 갱신하고, 목록은 돌아올 때 스스로 맞춘다.
///
/// - Important: `@MainActor` — 명함첩 저장소가 SwiftData `mainContext` 를 탄다.
@MainActor
@Observable
public final class ReceivedCardDetailViewModel {

    // MARK: - Property

    public private(set) var card: ReceivedCard

    /// 명함 뒷면(그 사람의 링크 QR + 외부 링크) 표시 여부.
    public var isFlipped = false

    /// 교환 맥락 메모 입력 바인딩.
    public var contextDraft: String

    public var alertPrompt: AlertPrompt?

    /// 상대 명함 링크 QR. 생성 실패는 화면을 막지 않는다 — 뒷면 QR 자리가 빌 뿐이다.
    public private(set) var qrImage: CGImage?

    /// 삭제가 끝났다. 화면이 이 값을 보고 스스로 닫는다.
    public private(set) var isDeleted = false

    private let deleteReceivedCard: DeleteReceivedCardUseCaseProtocol
    private let updateExchangeContext: UpdateExchangeContextUseCaseProtocol
    private let generateCardQR: GenerateCardQRUseCaseProtocol
    private let errorHandler: ErrorHandler

    // MARK: - Init

    public init(
        card: ReceivedCard,
        deleteReceivedCard: DeleteReceivedCardUseCaseProtocol,
        updateExchangeContext: UpdateExchangeContextUseCaseProtocol,
        generateCardQR: GenerateCardQRUseCaseProtocol,
        errorHandler: ErrorHandler
    ) {
        self.card = card
        self.contextDraft = card.exchangeContext ?? ""
        self.deleteReceivedCard = deleteReceivedCard
        self.updateExchangeContext = updateExchangeContext
        self.generateCardQR = generateCardQR
        self.errorHandler = errorHandler
    }

    // MARK: - Function

    /// 뒷면 QR 은 뒤집을 때가 아니라 진입할 때 미리 만든다 — 생성이 동기라 뒤집는 순간
    /// 만들면 그 프레임에서 애니메이션이 걸린다.
    public func prepare() {
        guard qrImage == nil else { return }
        qrImage = try? generateCardQR.execute(for: card.profile)
    }

    /// 편집 화면을 따로 두지 않는다 — 메모 한 줄이라 포커스가 빠질 때 저장한다.
    /// 값이 그대로면 저장소를 건드리지 않는다.
    public func commitContext() async {
        let trimmed = contextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != (card.exchangeContext ?? "") else { return }

        do {
            card = try await updateExchangeContext.execute(card: card, context: trimmed)
            contextDraft = card.exchangeContext ?? ""
        } catch {
            errorHandler.handle(
                error,
                context: ErrorContext(feature: Constants.feature, action: "updateExchangeContext")
            )
        }
    }

    /// 명함첩은 서버 사본이 없다 — 지우면 다시 교환하기 전까지 복구할 수 없어서
    /// 확인을 한 번 받는다 (그리드 컨텍스트 메뉴와 같은 규칙).
    public func requestDelete() {
        alertPrompt = AlertPrompt(
            title: Constants.deleteTitle,
            message: Constants.deleteMessage(name: card.profile.name),
            positiveBtnTitle: Constants.deleteConfirm,
            positiveBtnAction: { [weak self] in
                Task { await self?.delete() }
            },
            negativeBtnTitle: Constants.deleteCancel,
            isPositiveBtnDestructive: true
        )
    }

    // MARK: - Private Function

    private func delete() async {
        do {
            try await deleteReceivedCard.execute(id: card.id)
            isDeleted = true
        } catch {
            errorHandler.handle(
                error,
                context: ErrorContext(feature: Constants.feature, action: "deleteReceivedCard")
            )
        }
    }
}
