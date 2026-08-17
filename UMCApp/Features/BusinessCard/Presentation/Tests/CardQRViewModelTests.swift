//
//  CardQRViewModelTests.swift
//  BusinessCardPresentationTests
//
//  Created by One on 8/18/26.
//

import CoreGraphics
import Foundation
import Testing
import UMCFoundation
import BusinessCardDomain
@testable import BusinessCardPresentation

@MainActor
@Suite("CardQRViewModel — 내 명함 QR 생성·저장")
struct CardQRViewModelTests {

    // MARK: - Load

    @Test("로드하면 명함과 QR 이 함께 준비된다")
    func loadProducesCardAndQR() async {
        let generator = StubGenerateCardQR(image: makeImage())
        let sut = makeSUT(generator: generator)

        await sut.load()

        #expect(sut.card.value?.memberId == "42")
        #expect(sut.qrImage != nil)
        #expect(generator.lastCard?.qrPayload == makeCard().qrPayload)
    }

    @Test("로드가 실패하면 failed 가 되고 QR 은 비어 있다")
    func loadFailure() async {
        let sut = makeSUT(fetch: StubFetchMyCard(error: StubError.boom))

        await sut.load()

        #expect(sut.card.error != nil)
        #expect(sut.qrImage == nil)
    }

    /// QR 만 못 만들었다고 명함까지 감출 이유가 없다. 카드는 그대로 보여주고
    /// QR 자리만 비운다.
    @Test("QR 생성이 실패해도 명함은 보여준다")
    func qrFailureKeepsCard() async {
        let sut = makeSUT(generator: StubGenerateCardQR(error: StubError.boom))

        await sut.load()

        #expect(sut.card.value != nil)
        #expect(sut.qrImage == nil)
    }

    // MARK: - Save

    @Test("이미지 저장을 누르면 생성된 QR 을 저장기로 넘긴다")
    func saveForwardsImage() async {
        let saver = StubCardImageSaver()
        let sut = makeSUT(saver: saver)
        await sut.load()

        await sut.saveQRImage()

        #expect(saver.savedCount == 1)
    }

    /// 앨범 권한이 없으면 저장이 조용히 실패한다 — 눌렀는데 아무 일도 안 일어나면
    /// 사용자는 버튼이 고장 났다고 여긴다. 설정으로 보낼 안내를 띄운다.
    @Test("앨범 권한이 없으면 안내 다이얼로그를 띄운다")
    func saveWithoutPermissionPrompts() async {
        let sut = makeSUT(saver: StubCardImageSaver(error: CardImageSaveError.permissionDenied))
        await sut.load()

        await sut.saveQRImage()

        #expect(sut.alertPrompt != nil)
    }

    @Test("QR 이 아직 없으면 저장을 시도하지 않는다")
    func saveWithoutImageDoesNothing() async {
        let saver = StubCardImageSaver()
        let sut = makeSUT(generator: StubGenerateCardQR(error: StubError.boom), saver: saver)
        await sut.load()

        await sut.saveQRImage()

        #expect(saver.savedCount == .zero)
    }
}

// MARK: - Fixture

private enum StubError: Error {
    case boom
}

private func makeCard() -> MyCard {
    MyCard(
        memberId: "42", name: "정의찬", nickname: "제옹",
        part: .front(type: .ios), generation: "12", university: "한양대학교",
        email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil
    )
}

private func makeImage() -> CGImage {
    let context = CGContext(
        data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
    // 1×1 컨텍스트 생성이 실패할 이유가 없다. 실패하면 테스트가 크래시로 알린다.
    return context!.makeImage()!
}

@MainActor
private func makeSUT(
    fetch: StubFetchMyCard = StubFetchMyCard(card: makeCard()),
    generator: StubGenerateCardQR = StubGenerateCardQR(image: makeImage()),
    saver: StubCardImageSaver = StubCardImageSaver()
) -> CardQRViewModel {
    CardQRViewModel(
        fetchMyCard: fetch,
        generateCardQR: generator,
        imageSaver: saver,
        errorHandler: ErrorHandler()
    )
}

// MARK: - Stub

private final class StubFetchMyCard: FetchMyCardUseCaseProtocol, @unchecked Sendable {

    private let card: MyCard?
    private let error: Error?

    init(card: MyCard? = nil, error: Error? = nil) {
        self.card = card
        self.error = error
    }

    func execute(forceRefresh: Bool) async throws -> MyCard {
        if let error { throw error }
        return card ?? makeCard()
    }
}

private final class StubGenerateCardQR: GenerateCardQRUseCaseProtocol, @unchecked Sendable {

    private let image: CGImage?
    private let error: Error?
    private(set) var lastCard: MyCard?

    init(image: CGImage? = nil, error: Error? = nil) {
        self.image = image
        self.error = error
    }

    func execute(for card: MyCard) throws -> CGImage {
        lastCard = card
        if let error { throw error }
        return image ?? makeImage()
    }
}

private final class StubCardImageSaver: CardImageSaving, @unchecked Sendable {

    private let error: Error?
    private(set) var savedCount = 0

    init(error: Error? = nil) {
        self.error = error
    }

    func save(_ image: CGImage) async throws {
        savedCount += 1
        if let error { throw error }
    }
}
