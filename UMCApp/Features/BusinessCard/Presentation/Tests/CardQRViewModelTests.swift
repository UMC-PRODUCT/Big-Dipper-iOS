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

    // MARK: - Retry / Refresh

    /// 인코딩만 실패한 경우다. 명함은 이미 손에 있으니 재조회 없이 그 단계만 다시 돈다 —
    /// 카드까지 다시 받아오면 왕복이 한 번 더 붙고 화면이 스켈레톤으로 되돌아간다.
    @Test("QR 재시도는 명함을 다시 받아오지 않고 생성만 다시 한다")
    func retryRegeneratesWithoutRefetching() async {
        let fetch = StubFetchMyCard(card: makeCard())
        let generator = StubGenerateCardQR(image: makeImage(), error: StubError.boom)
        let sut = makeSUT(fetch: fetch, generator: generator)

        await sut.load()
        #expect(sut.qrImage == nil)
        #expect(fetch.callCount == 1)

        generator.error = nil
        sut.retryQRGeneration()

        #expect(sut.qrImage != nil)
        #expect(fetch.callCount == 1, "재시도가 명함을 다시 받아오면 안 된다")
    }

    /// 명함조차 없으면 되살릴 재료가 없다 — 조용히 아무것도 하지 않아야 한다.
    @Test("명함이 없으면 QR 재시도는 아무 일도 하지 않는다")
    func retryWithoutCardDoesNothing() async {
        let generator = StubGenerateCardQR(image: makeImage())
        let sut = makeSUT(fetch: StubFetchMyCard(error: StubError.boom), generator: generator)
        await sut.load()

        sut.retryQRGeneration()

        #expect(sut.qrImage == nil)
        #expect(generator.callCount == .zero)
    }

    /// 당겨서 새로고침인데 캐시를 그대로 돌려주면 아무것도 하지 않는 제스처가 된다.
    @Test("새로고침은 캐시를 건너뛰고 로딩 상태로 되돌아가지 않는다")
    func refreshForcesRefetchAndKeepsContent() async {
        let fetch = StubFetchMyCard(card: makeCard())
        let sut = makeSUT(fetch: fetch)
        await sut.load()
        #expect(fetch.lastForceRefresh == false)

        await sut.refresh()

        #expect(fetch.lastForceRefresh == true)
        #expect(sut.card.value != nil)
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
    private(set) var callCount = 0
    private(set) var lastForceRefresh: Bool?

    init(card: MyCard? = nil, error: Error? = nil) {
        self.card = card
        self.error = error
    }

    func execute(forceRefresh: Bool) async throws -> MyCard {
        callCount += 1
        lastForceRefresh = forceRefresh
        if let error { throw error }
        return card ?? makeCard()
    }
}

private final class StubGenerateCardQR: GenerateCardQRUseCaseProtocol, @unchecked Sendable {

    private let image: CGImage?
    /// 재시도 경로를 재현하려면 「실패한 뒤 성공」이 필요해 도중에 바꿀 수 있게 둔다.
    var error: Error?
    private(set) var lastCard: MyCard?
    private(set) var callCount = 0

    init(image: CGImage? = nil, error: Error? = nil) {
        self.image = image
        self.error = error
    }

    func execute(for card: MyCard) throws -> CGImage {
        callCount += 1
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
