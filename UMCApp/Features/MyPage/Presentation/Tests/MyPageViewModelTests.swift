//
//  MyPageViewModelTests.swift
//  MyPagePresentationTests
//
//  Created by One on 5/24/26.
//

import Testing
import Foundation
import UMCFoundation
import AuthDomain
import CoreDI
import UMCFoundation
import CoreDomain
import MyPageDomain
@testable import MyPagePresentation

@MainActor
@Suite("MyPageViewModel — fetchProfile Loadable 상태 머신")
struct MyPageViewModelTests {

    @Test("초기 상태는 .idle")
    func initialStateIsIdle() {
        let viewModel = makeViewModel(repository: StubRepository(result: .success(makeProfileData(challengeId: 1))))
        #expect(viewModel.profileData == .idle)
    }

    @Test("fetchProfile 성공 시 .loaded(profile) — socialConnections는 member-oauth 응답으로 채워진다 (#1029)")
    func fetchProfileSuccessSyncsSocialConnections() async {
        let original = makeProfileData(
            challengeId: 7,
            socialConnections: [SocialConnection(memberOAuthId: "999", socialType: .google)]
        )
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(original)),
            oauthResult: .success([
                MemberOAuth(memberOAuthId: "1", memberId: "1", provider: .kakao),
                MemberOAuth(memberOAuthId: "2", memberId: "1", provider: .unknown("NAVER"))
            ])
        )

        await viewModel.fetchProfile()

        guard case .loaded(let loaded) = viewModel.profileData else {
            Issue.record("Expected .loaded, got \(viewModel.profileData)")
            return
        }
        #expect(loaded.challengeId == 7)
        #expect(loaded.socialConnections.map(\.socialType) == [.kakao], "모르는 provider는 제외한다")
        #expect(loaded.socialConnections.first?.memberOAuthId == "1")
    }

    @Test("member-oauth 조회 실패는 프로필 조회를 실패시키지 않고 연동 목록만 비운다")
    func oauthFailureKeepsProfileLoaded() async {
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(makeProfileData(
                challengeId: 3,
                socialConnections: [SocialConnection(memberOAuthId: "1", socialType: .kakao)]
            ))),
            oauthResult: .failure(GenericTestError.boom)
        )

        await viewModel.fetchProfile()

        #expect(viewModel.profileData.value?.challengeId == 3)
        #expect(viewModel.profileData.value?.socialConnections.isEmpty == true)
    }

    @Test("AppError 발생 시 .failed로 전이")
    func appErrorPropagatesToFailed() async {
        let error = AppError.unknown(message: "boom")
        let viewModel = makeViewModel(repository: StubRepository(result: .failure(error)))

        await viewModel.fetchProfile()

        #expect(viewModel.profileData.error == error)
    }

    @Test("일반 Error 발생 시 .failed(.unknown)으로 전이")
    func genericErrorWrappedAsUnknown() async {
        let viewModel = makeViewModel(repository: ThrowingRepository(error: GenericTestError.boom))

        await viewModel.fetchProfile()

        guard case .failed(let appError) = viewModel.profileData,
              case .unknown(let message) = appError else {
            Issue.record("Expected .failed(.unknown), got \(viewModel.profileData)")
            return
        }
        #expect(message.contains("boom") || !message.isEmpty)
    }

    @Test("CancellationError 발생 시 이전 상태(.loaded)를 복원")
    func cancellationPreservesPreviousLoadedState() async {
        let preloaded = makeProfileData(challengeId: 99)
        let viewModel = makeViewModel(
            repository: ThrowingRepository(error: CancellationError()),
            previewProfileData: preloaded
        )

        // 사전 상태 검증
        #expect(viewModel.profileData.value?.challengeId == 99)

        await viewModel.fetchProfile()

        guard case .loaded(let restored) = viewModel.profileData else {
            Issue.record("Expected restored .loaded, got \(viewModel.profileData)")
            return
        }
        #expect(restored.challengeId == 99)
    }

    @Test("NSURLErrorCancelled 발생 시 이전 상태(.loaded)를 복원")
    func urlCancellationPreservesPreviousLoadedState() async {
        let preloaded = makeProfileData(challengeId: 5)
        let cancelError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorCancelled,
            userInfo: nil
        )
        let viewModel = makeViewModel(
            repository: ThrowingRepository(error: cancelError),
            previewProfileData: preloaded
        )

        await viewModel.fetchProfile()

        #expect(viewModel.profileData.value?.challengeId == 5)
    }

    @Test("로딩 중 중복 호출은 무시 (Repository fetch 1회만 호출)")
    func duplicateFetchWhileLoadingIsIgnored() async {
        let repository = SlowStubRepository(
            profile: makeProfileData(challengeId: 1),
            delayNanoseconds: 100_000_000  // 0.1s
        )
        let viewModel = makeViewModel(repository: repository)

        let first = Task { await viewModel.fetchProfile() }
        // 첫번째 호출이 .loading 세팅까지 진행되도록 양보
        await Task.yield()

        await viewModel.fetchProfile()  // isLoading 체크로 즉시 return
        await first.value

        #expect(repository.callCount == 1)
        #expect(viewModel.profileData.value?.challengeId == 1)
    }

    @Test("fetchProfile(forceRefresh: true)는 repository까지 forceRefresh를 그대로 전달한다")
    func forceRefreshIsPassedThroughToRepository() async {
        let repository = StubRepository(result: .success(makeProfileData(challengeId: 1)))
        let viewModel = makeViewModel(repository: repository)

        await viewModel.fetchProfile(forceRefresh: true)

        #expect(repository.lastForceRefresh == true)
    }

    @Test("기본 fetchProfile()은 forceRefresh: false로 조회한다 (캐시 히트 유지)")
    func defaultFetchUsesCacheAllowedPath() async {
        let repository = StubRepository(result: .success(makeProfileData(challengeId: 1)))
        let viewModel = makeViewModel(repository: repository)

        await viewModel.fetchProfile()

        #expect(repository.lastForceRefresh == false)
    }
}

// MARK: - Helpers

private enum GenericTestError: Error { case boom }

@MainActor
private func makeViewModel(
    repository: MyPageRepositoryProtocol,
    oauthResult: Result<[MemberOAuth], Error> = .success([]),
    previewProfileData: ProfileData? = nil
) -> MyPageViewModel {
    let container = DIContainer()
    container.register(MyPageRepositoryProtocol.self) { repository }
    container.register(MyPageUseCaseProviding.self) {
        MyPageUseCaseProvider(repository: container.resolve(MyPageRepositoryProtocol.self))
    }
    container.register(FetchMyOAuthUseCaseProtocol.self) {
        StubFetchMyOAuthUseCase(result: oauthResult)
    }
    container.register(AddMemberOAuthUseCaseProtocol.self) {
        StubAddMemberOAuthUseCase(result: oauthResult)
    }
    container.register(LoginUseCaseProtocol.self) { StubLoginUseCase() }
    #if DEBUG
    if let preview = previewProfileData {
        return MyPageViewModel(container: container, previewProfileData: preview)
    }
    #endif
    return MyPageViewModel(container: container)
}

private func makeProfileData(
    challengeId: Int,
    socialConnections: [SocialConnection] = []
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
        profileLink: []
    )
}

// MARK: - Stub UseCases (소셜 연동)

private struct StubFetchMyOAuthUseCase: FetchMyOAuthUseCaseProtocol {
    let result: Result<[MemberOAuth], Error>

    func execute() async throws -> [MemberOAuth] {
        try result.get()
    }
}

private struct StubAddMemberOAuthUseCase: AddMemberOAuthUseCaseProtocol {
    let result: Result<[MemberOAuth], Error>

    func execute(oAuthVerificationToken: String) async throws -> [MemberOAuth] {
        try result.get()
    }
}

private struct StubLoginUseCase: LoginUseCaseProtocol {
    func executeKakao(accessToken: String, email: String) async throws -> OAuthLoginResult {
        .newMember(verificationToken: "stub-token")
    }

    func executeApple(
        authorizationCode: String,
        email: String?,
        fullName: String?
    ) async throws -> OAuthLoginResult {
        .newMember(verificationToken: "stub-token")
    }

    func executeGoogle(accessToken: String) async throws -> OAuthLoginResult {
        .newMember(verificationToken: "stub-token")
    }
}

// MARK: - Stub Repositories

private final class StubRepository: MyPageRepositoryProtocol, @unchecked Sendable {
    private let result: Result<ProfileData, AppError>
    private(set) var lastForceRefresh: Bool?

    init(result: Result<ProfileData, AppError>) {
        self.result = result
    }

    func fetchMyProfile(forceRefresh: Bool) async throws -> ProfileData {
        lastForceRefresh = forceRefresh
        return try result.get()
    }

    func fetchMemberProfile(memberId: Int) async throws -> MemberProfileSummary { fatalError("unused") }
    func fetchMyPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage { fatalError("unused") }
    func fetchCommentedPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage { fatalError("unused") }
    func fetchScrappedPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage { fatalError("unused") }
    func fetchTerms(termsType: String) async throws -> MyPageTerms { fatalError("unused") }
    func addChallengerRecord(code: String) async throws { fatalError("unused") }
    func updateProfileImage(imageData: Data, fileName: String, contentType: String) async throws -> ProfileData { fatalError("unused") }
    func updateProfileLinks(_ links: [ProfileLink]) async throws -> ProfileData { fatalError("unused") }
    func deleteMember() async throws { fatalError("unused") }
}

private final class ThrowingRepository: MyPageRepositoryProtocol, @unchecked Sendable {
    private let error: Error

    init(error: Error) {
        self.error = error
    }

    func fetchMyProfile(forceRefresh: Bool) async throws -> ProfileData {
        throw error
    }

    func fetchMemberProfile(memberId: Int) async throws -> MemberProfileSummary { fatalError("unused") }
    func fetchMyPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage { fatalError("unused") }
    func fetchCommentedPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage { fatalError("unused") }
    func fetchScrappedPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage { fatalError("unused") }
    func fetchTerms(termsType: String) async throws -> MyPageTerms { fatalError("unused") }
    func addChallengerRecord(code: String) async throws { fatalError("unused") }
    func updateProfileImage(imageData: Data, fileName: String, contentType: String) async throws -> ProfileData { fatalError("unused") }
    func updateProfileLinks(_ links: [ProfileLink]) async throws -> ProfileData { fatalError("unused") }
    func deleteMember() async throws { fatalError("unused") }
}

private final class SlowStubRepository: MyPageRepositoryProtocol, @unchecked Sendable {
    private let profile: ProfileData
    private let delayNanoseconds: UInt64
    private let lock = NSLock()
    private var _callCount = 0

    var callCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _callCount
    }

    init(profile: ProfileData, delayNanoseconds: UInt64) {
        self.profile = profile
        self.delayNanoseconds = delayNanoseconds
    }

    func fetchMyProfile(forceRefresh: Bool) async throws -> ProfileData {
        lock.lock()
        _callCount += 1
        lock.unlock()
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return profile
    }

    func fetchMemberProfile(memberId: Int) async throws -> MemberProfileSummary { fatalError("unused") }
    func fetchMyPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage { fatalError("unused") }
    func fetchCommentedPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage { fatalError("unused") }
    func fetchScrappedPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage { fatalError("unused") }
    func fetchTerms(termsType: String) async throws -> MyPageTerms { fatalError("unused") }
    func addChallengerRecord(code: String) async throws { fatalError("unused") }
    func updateProfileImage(imageData: Data, fileName: String, contentType: String) async throws -> ProfileData { fatalError("unused") }
    func updateProfileLinks(_ links: [ProfileLink]) async throws -> ProfileData { fatalError("unused") }
    func deleteMember() async throws { fatalError("unused") }
}
