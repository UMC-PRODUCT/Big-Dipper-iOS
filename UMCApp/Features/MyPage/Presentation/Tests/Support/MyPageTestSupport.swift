//
//  MyPageTestSupport.swift
//  MyPagePresentationTests
//
//  Created by 김동민 on 7/13/26.
//

import Foundation
import UIKit
import UMCFoundation
import CoreDomain
import CoreNearbyExchange
import BusinessCardDomain
import BusinessCardPresentation
import MyPageDomain
@testable import MyPagePresentation

/// ViewModel 테스트에서 공용으로 던지는 센티넬 에러
///
/// repository가 던진 에러가 UseCase → ViewModel을 통해 그대로 전파되는지 확인할 때 사용합니다.
/// (Domain 테스트 타깃의 동명 타입과 동일한 역할 — 타깃이 분리되어 있어 중복 정의합니다.)
enum MyPageTestError: Error, Equatable {
    case boom
}

// MARK: - Mock Repository

/// `MyPageRepositoryProtocol`의 테스트용 Mock 구현체 (Presentation 타깃 전용).
///
/// `MyPageDomainTests`의 `MockMyPageRepository`와 동일한 컨벤션을 따릅니다:
/// 호출 메서드/인자를 기록하고(`...CallCount`, `...Received...`), 반환/던질 값을 주입합니다
/// (`...Result` / `...Error`). 반환값을 주입하지 않은 메서드는 `MockError.notStubbed`를 던져
/// ViewModel이 엉뚱한 경로를 탔을 때(오배선) 테스트가 실패하도록 합니다.
///
/// - Note: Presentation 테스트 타깃은 Domain 테스트 타깃의 Support를 참조할 수 없어
///   부득이 동일 구조를 재정의합니다.
final class MockMyPageRepository: MyPageRepositoryProtocol, @unchecked Sendable {

    enum MockError: Error, Equatable {
        /// 테스트가 반환값을 주입하지 않은 메서드가 호출됨
        case notStubbed
    }

    // MARK: - fetchMyProfile

    var fetchMyProfileResult: Result<ProfileData, Error> = .failure(MockError.notStubbed)
    private(set) var fetchMyProfileCallCount = 0
    private(set) var fetchMyProfileReceivedForceRefresh: Bool?

    func fetchMyProfile(forceRefresh: Bool) async throws -> ProfileData {
        fetchMyProfileCallCount += 1
        fetchMyProfileReceivedForceRefresh = forceRefresh
        return try fetchMyProfileResult.get()
    }

    // MARK: - addChallengerRecord

    var addChallengerRecordError: Error?
    private(set) var addChallengerRecordCallCount = 0
    private(set) var addChallengerRecordReceivedCode: String?

    func addChallengerRecord(code: String) async throws {
        addChallengerRecordCallCount += 1
        addChallengerRecordReceivedCode = code
        if let addChallengerRecordError {
            throw addChallengerRecordError
        }
    }

    // MARK: - updateProfileImage

    var updateProfileImageResult: Result<ProfileData, Error> = .failure(MockError.notStubbed)
    private(set) var updateProfileImageCallCount = 0
    private(set) var updateProfileImageReceivedImageData: Data?
    private(set) var updateProfileImageReceivedFileName: String?
    private(set) var updateProfileImageReceivedContentType: String?

    func updateProfileImage(
        imageData: Data,
        fileName: String,
        contentType: String
    ) async throws -> ProfileData {
        updateProfileImageCallCount += 1
        updateProfileImageReceivedImageData = imageData
        updateProfileImageReceivedFileName = fileName
        updateProfileImageReceivedContentType = contentType
        return try updateProfileImageResult.get()
    }

    // MARK: - updateProfileLinks

    var updateProfileLinksResult: Result<ProfileData, Error> = .failure(MockError.notStubbed)
    private(set) var updateProfileLinksCallCount = 0
    private(set) var updateProfileLinksReceivedLinks: [ProfileLink]?

    func updateProfileLinks(_ links: [ProfileLink]) async throws -> ProfileData {
        updateProfileLinksCallCount += 1
        updateProfileLinksReceivedLinks = links
        return try updateProfileLinksResult.get()
    }

    // MARK: - fetchMyPosts

    var fetchMyPostsResult: Result<MyActivePostPage, Error> = .failure(MockError.notStubbed)
    private(set) var fetchMyPostsCallCount = 0
    private(set) var fetchMyPostsReceivedQuery: MyPagePostListQuery?

    func fetchMyPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        fetchMyPostsCallCount += 1
        fetchMyPostsReceivedQuery = query
        return try fetchMyPostsResult.get()
    }

    // MARK: - fetchCommentedPosts

    var fetchCommentedPostsResult: Result<MyActivePostPage, Error> = .failure(MockError.notStubbed)
    private(set) var fetchCommentedPostsCallCount = 0
    private(set) var fetchCommentedPostsReceivedQuery: MyPagePostListQuery?

    func fetchCommentedPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        fetchCommentedPostsCallCount += 1
        fetchCommentedPostsReceivedQuery = query
        return try fetchCommentedPostsResult.get()
    }

    // MARK: - fetchScrappedPosts

    var fetchScrappedPostsResult: Result<MyActivePostPage, Error> = .failure(MockError.notStubbed)
    private(set) var fetchScrappedPostsCallCount = 0
    private(set) var fetchScrappedPostsReceivedQuery: MyPagePostListQuery?

    func fetchScrappedPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        fetchScrappedPostsCallCount += 1
        fetchScrappedPostsReceivedQuery = query
        return try fetchScrappedPostsResult.get()
    }

    // MARK: - Unused (본 ViewModel들이 호출하지 않음)

    var fetchMemberProfileResult: Result<MemberProfileSummary, Error> = .failure(MockError.notStubbed)
    private(set) var fetchMemberProfileCallCount = 0

    func fetchMemberProfile(memberId: Int) async throws -> MemberProfileSummary {
        fetchMemberProfileCallCount += 1
        return try fetchMemberProfileResult.get()
    }

    var fetchTermsResult: Result<MyPageTerms, Error> = .failure(MockError.notStubbed)
    private(set) var fetchTermsCallCount = 0

    func fetchTerms(termsType: String) async throws -> MyPageTerms {
        fetchTermsCallCount += 1
        return try fetchTermsResult.get()
    }

    var deleteMemberError: Error?
    private(set) var deleteMemberCallCount = 0

    func deleteMember() async throws {
        deleteMemberCallCount += 1
        if let deleteMemberError {
            throw deleteMemberError
        }
    }
}

// MARK: - Fixtures

/// 테스트에서 반환값으로 재사용할 ProfileData 픽스처
/// (Domain 테스트의 `makeStubProfileData`와 동일 컨벤션 — 파라미터만 확장)
func makeStubProfileData(
    challengeId: Int = 1,
    socialConnections: [SocialConnection] = [],
    profileLink: [ProfileLink] = []
) -> ProfileData {
    ProfileData(
        challengeId: challengeId,
        challengerInfo: ChallengerInfo(
            memberId: "1",
            challengerId: "1",
            gen: "11",
            name: "테스트",
            nickname: "tester",
            schoolName: "UMC",
            profileImage: nil,
            part: .pm
        ),
        socialConnections: socialConnections,
        activityLogs: [],
        profileLink: profileLink
    )
}

/// 커뮤니티 게시글 아이템 픽스처
func makeStubCommunityItem(
    postId: String,
    title: String = "제목"
) -> CommunityItemModel {
    CommunityItemModel(
        postId: postId,
        userId: "u1",
        category: .free,
        title: title,
        content: "내용",
        profileImage: nil,
        userName: "이름",
        userNickname: nil,
        part: .pm,
        createdAt: Date(timeIntervalSince1970: 0),
        likeCount: 0,
        commentCount: 0,
        scrapCount: 0,
        isAuthor: false,
        lightningInfo: nil
    )
}

/// 게시글 목록 페이지 픽스처
func makeStubPostPage(
    items: [CommunityItemModel],
    page: Int = 0,
    hasNext: Bool = false
) -> MyActivePostPage {
    MyActivePostPage(items: items, page: page, hasNext: hasNext)
}

/// jpegData 인코딩이 nil이 아님을 보장하는 1x1 단색 이미지.
/// 빈 `UIImage()`는 jpegData가 nil을 반환해 이미지 업데이트 경로가 트리거되지 않습니다.
func makeStubImage() -> UIImage {
    let size = CGSize(width: 1, height: 1)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
        UIColor.red.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
}

/// QR 생성 스텁이 반환할 1x1 더미 CGImage. `UIGraphicsImageRenderer`가 만든 `UIImage`는
/// 항상 `cgImage`를 갖는다 (nil이 되는 경우는 벡터 전용 컨텍스트뿐, 여기선 해당 없음).
func makeStubCGImage() -> CGImage {
    guard let image = makeStubImage().cgImage else {
        fatalError("UIGraphicsImageRenderer 결과에는 항상 cgImage가 있다")
    }
    return image
}

// MARK: - Provider Helper

/// Mock Repository를 실제 UseCase Provider에 주입합니다.
func makeUseCaseProvider(_ repository: MockMyPageRepository) -> MyPageUseCaseProvider {
    MyPageUseCaseProvider(repository: repository)
}

// MARK: - Stub BusinessCard UseCase Provider

/// `BusinessCardUseCaseProviding`의 테스트용 스텁 (Presentation 타깃 전용).
///
/// `MyPageViewModel.loadBusinessCard`가 실제로 호출하는 두 UseCase만 동작하는 스텁으로
/// 채운다. 나머지(교환·QR·명함첩 등)는 명함 화면 전용이라 이 경로에서 호출될 일이 없어
/// `fatalError`로 오배선을 드러낸다 (``MockMyPageRepository``와 같은 컨벤션).
struct StubBusinessCardUseCaseProvider: BusinessCardUseCaseProviding {
    var fetchMyCardResult: Result<MyCard, Error> = .failure(StubBusinessCardError.notStubbed)
    var activityStat: ActivityStat = .empty
    /// 기본값은 실패 — `loadBusinessCard`가 `try?`로 삼키므로 QR을 신경 쓰지 않는 테스트는
    /// `qrImage == nil`인 채로 통과한다. QR을 검증하는 테스트만 `.success`로 override한다.
    var generateCardQRResult: Result<CGImage, Error> = .failure(StubBusinessCardError.notStubbed)
    /// 호출 기록(횟수·인자)이 필요한 테스트가 기본 스텁 대신 주입한다.
    var fetchMyCardUseCaseOverride: FetchMyCardUseCaseProtocol?
    var generateCardQRUseCaseOverride: GenerateCardQRUseCaseProtocol?

    var fetchMyCardUseCase: FetchMyCardUseCaseProtocol {
        fetchMyCardUseCaseOverride ?? StubFetchMyCardUseCase(result: fetchMyCardResult)
    }
    var fetchActivityStatUseCase: FetchActivityStatUseCaseProtocol {
        StubFetchActivityStatUseCase(stat: activityStat)
    }
    var generateCardQRUseCase: GenerateCardQRUseCaseProtocol {
        generateCardQRUseCaseOverride ?? StubGenerateCardQRUseCase(result: generateCardQRResult)
    }

    var fetchPeerCardUseCase: FetchPeerCardUseCaseProtocol { NotStubbedFetchPeerCardUseCase() }
    var fetchReceivedCardsUseCase: FetchReceivedCardsUseCaseProtocol {
        NotStubbedFetchReceivedCardsUseCase()
    }
    var saveReceivedCardUseCase: SaveReceivedCardUseCaseProtocol {
        NotStubbedSaveReceivedCardUseCase()
    }
    var deleteReceivedCardUseCase: DeleteReceivedCardUseCaseProtocol {
        NotStubbedDeleteReceivedCardUseCase()
    }
    var exchangeCardsUseCase: ExchangeCardsUseCaseProtocol { NotStubbedExchangeCardsUseCase() }
}

enum StubBusinessCardError: Error, Equatable {
    case notStubbed
}

private struct StubFetchMyCardUseCase: FetchMyCardUseCaseProtocol {
    let result: Result<MyCard, Error>

    func execute(forceRefresh: Bool) async throws -> MyCard {
        try result.get()
    }
}

private struct StubFetchActivityStatUseCase: FetchActivityStatUseCaseProtocol {
    let stat: ActivityStat

    func execute() async -> ActivityStat {
        stat
    }
}

private struct StubGenerateCardQRUseCase: GenerateCardQRUseCaseProtocol {
    let result: Result<CGImage, Error>

    func execute(for card: MyCard) throws -> CGImage {
        try result.get()
    }
}

private struct NotStubbedFetchPeerCardUseCase: FetchPeerCardUseCaseProtocol {
    func execute(memberId: String) async throws -> MyCard {
        fatalError("MyPageViewModel 테스트에서 호출되지 않아야 하는 UseCase")
    }
}

private struct NotStubbedFetchReceivedCardsUseCase: FetchReceivedCardsUseCaseProtocol {
    func execute(query: String?) async throws -> [ReceivedCard] {
        fatalError("MyPageViewModel 테스트에서 호출되지 않아야 하는 UseCase")
    }
}

private struct NotStubbedSaveReceivedCardUseCase: SaveReceivedCardUseCaseProtocol {
    func execute(
        payload: ExchangePayload,
        ownerMemberId: String,
        exchangeContext: String?
    ) async throws -> ReceivedCard? {
        fatalError("MyPageViewModel 테스트에서 호출되지 않아야 하는 UseCase")
    }

    func execute(
        card: MyCard,
        cardID: String,
        ownerMemberId: String,
        exchangeContext: String?
    ) async throws -> ReceivedCard? {
        fatalError("MyPageViewModel 테스트에서 호출되지 않아야 하는 UseCase")
    }
}

private struct NotStubbedDeleteReceivedCardUseCase: DeleteReceivedCardUseCaseProtocol {
    func execute(id: String) async throws {
        fatalError("MyPageViewModel 테스트에서 호출되지 않아야 하는 UseCase")
    }

    func executeAll() async throws {
        fatalError("MyPageViewModel 테스트에서 호출되지 않아야 하는 UseCase")
    }
}

private final class NotStubbedExchangeCardsUseCase:
    ExchangeCardsUseCaseProtocol, @unchecked Sendable {
    func start(myCard: MyCard) -> AsyncStream<ExchangeEvent> {
        fatalError("MyPageViewModel 테스트에서 호출되지 않아야 하는 UseCase")
    }

    func send(myCard: MyCard, to peer: DiscoveredPeer) async throws {
        fatalError("MyPageViewModel 테스트에서 호출되지 않아야 하는 UseCase")
    }

    func stop() async {
        fatalError("MyPageViewModel 테스트에서 호출되지 않아야 하는 UseCase")
    }
}
