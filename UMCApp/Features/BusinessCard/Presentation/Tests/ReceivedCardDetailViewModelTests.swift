//
//  ReceivedCardDetailViewModelTests.swift
//  BusinessCardPresentationTests
//
//  Created by One on 8/28/26.
//

import CoreGraphics
import Foundation
import Testing
import UMCFoundation
import BusinessCardDomain
@testable import BusinessCardPresentation

@MainActor
@Suite("ReceivedCardDetailViewModel — 교환 맥락 메모·삭제")
struct ReceivedCardDetailViewModelTests {

    // MARK: - Context

    @Test("메모를 적고 확정하면 저장되고 화면 값도 따라 바뀐다")
    func commitContextSaves() async {
        let update = StubUpdateExchangeContext()
        let sut = makeSUT(update: update)

        sut.contextDraft = "OT에서 교환"
        await sut.commitContext()

        #expect(update.lastContext == "OT에서 교환")
        #expect(sut.card.exchangeContext == "OT에서 교환")
    }

    /// 화면을 뜰 때마다 무조건 저장하면 아무것도 안 고친 사용자까지 저장소를 긁는다.
    @Test("값이 그대로면 저장소를 건드리지 않는다")
    func commitContextSkipsWhenUnchanged() async {
        let update = StubUpdateExchangeContext()
        let sut = makeSUT(card: makeCard(context: "OT에서 교환"), update: update)

        await sut.commitContext()

        #expect(update.callCount == .zero)
    }

    @Test("앞뒤 공백만 남은 메모는 저장 대상이 아니다")
    func blankContextIsNotSaved() async {
        let update = StubUpdateExchangeContext()
        let sut = makeSUT(update: update)

        sut.contextDraft = "   "
        await sut.commitContext()

        #expect(update.callCount == .zero)
    }

    // MARK: - Delete

    /// 명함첩은 서버 사본이 없다 — 지우면 다시 교환하기 전까지 복구할 수 없다.
    @Test("삭제를 요청하면 곧바로 지우지 않고 확인 다이얼로그를 띄운다")
    func requestDeleteAsksFirst() {
        let delete = StubDeleteReceivedCard()
        let sut = makeSUT(delete: delete)

        sut.requestDelete()

        #expect(sut.alertPrompt?.isPositiveBtnDestructive == true)
        #expect(delete.deletedIDs.isEmpty)
        #expect(sut.isDeleted == false)
    }

    @Test("확인을 누르면 삭제하고 화면을 닫으라고 알린다")
    func confirmDeletesAndSignalsDismiss() async {
        let delete = StubDeleteReceivedCard()
        let sut = makeSUT(delete: delete)

        sut.requestDelete()
        sut.alertPrompt?.positiveBtnAction?()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(delete.deletedIDs == ["card-1"])
        #expect(sut.isDeleted)
    }

    /// 실패했는데 화면을 닫으면 사용자는 지워진 줄 알고 목록으로 돌아가 되살아난
    /// 명함을 본다. 실패는 화면을 그대로 두고 알리기만 한다.
    @Test("삭제가 실패하면 화면을 닫지 않고 에러를 알린다")
    func deleteFailureKeepsScreen() async {
        let errorHandler = ErrorHandler()
        let sut = makeSUT(
            delete: StubDeleteReceivedCard(error: StubError.boom),
            errorHandler: errorHandler
        )

        sut.requestDelete()
        sut.alertPrompt?.positiveBtnAction?()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(sut.isDeleted == false)
        #expect(errorHandler.currentError != nil)
    }
}

// MARK: - Fixture

private enum StubError: Error {
    case boom
}

private func makeCard(context: String? = nil) -> ReceivedCard {
    ReceivedCard(
        id: "card-1",
        profile: MyCard(
            memberId: "1", name: "제옹", nickname: "제옹",
            part: .front(type: .ios), generation: "11", university: "중앙대학교",
            email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil
        ),
        exchangedAt: Date(timeIntervalSince1970: 0),
        exchangeContext: context,
        exchangeMethod: .nearby
    )
}

@MainActor
private func makeSUT(
    card: ReceivedCard = makeCard(),
    delete: StubDeleteReceivedCard = StubDeleteReceivedCard(),
    update: StubUpdateExchangeContext = StubUpdateExchangeContext(),
    errorHandler: ErrorHandler = ErrorHandler()
) -> ReceivedCardDetailViewModel {
    ReceivedCardDetailViewModel(
        card: card,
        deleteReceivedCard: delete,
        updateExchangeContext: update,
        generateCardQR: StubGenerateCardQR(),
        errorHandler: errorHandler
    )
}

// MARK: - Stub

private final class StubDeleteReceivedCard:
    DeleteReceivedCardUseCaseProtocol, @unchecked Sendable {

    private let error: Error?
    private(set) var deletedIDs: [String] = []

    init(error: Error? = nil) {
        self.error = error
    }

    func execute(id: String) async throws {
        deletedIDs.append(id)
        if let error { throw error }
    }
}

private final class StubUpdateExchangeContext:
    UpdateExchangeContextUseCaseProtocol, @unchecked Sendable {

    private(set) var lastContext: String?
    private(set) var callCount = 0

    func execute(card: ReceivedCard, context: String?) async throws -> ReceivedCard {
        callCount += 1
        lastContext = context
        return card.updatingExchangeContext(context)
    }
}

private final class StubGenerateCardQR: GenerateCardQRUseCaseProtocol, @unchecked Sendable {

    func execute(for card: MyCard) throws -> CGImage {
        throw StubError.boom
    }
}
