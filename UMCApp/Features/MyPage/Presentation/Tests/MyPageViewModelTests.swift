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
import BusinessCardDomain
import BusinessCardPresentation
import CoreDI
import CoreGraphics
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
        // 첫번째 호출이 인플라이트 플래그 세팅까지 진행되도록 양보
        await Task.yield()

        await viewModel.fetchProfile()  // 인플라이트 가드로 즉시 return
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

/// 리뷰 지적(Important): `myCard`는 프로필 응답 도착 즉시 `.loaded`라 카드가 그려지는데,
/// `profileData`는 `/member-oauth/me` 왕복까지 끝나야 `.loaded`라 그 사이 「명함 편집」 탭이
/// 조용히 씹히는 창이 매 진입마다 생겼다. `isCardEditPending`이 그 창을 뷰에 알려 행을
/// 비활성화(+진행 표시)하게 한다 — 이 스위트는 `profileData`의 4개 상태 전이마다
/// `isCardEditPending`이 옳은 값을 내는지 고정한다.
@MainActor
@Suite("MyPageViewModel — isCardEditPending (명함 편집 무반응 창 방지)")
struct MyPageViewModelCardEditPendingTests {

    @Test("초기 상태(.idle)에서는 pending")
    func idleIsPending() {
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(makeProfileData(challengeId: 1)))
        )
        #expect(viewModel.isCardEditPending == true)
    }

    @Test("fetchProfile 진행 중(.loading)에도 pending")
    func loadingIsPending() async {
        let repository = SlowStubRepository(
            profile: makeProfileData(challengeId: 1),
            delayNanoseconds: 100_000_000  // 0.1s
        )
        let viewModel = makeViewModel(repository: repository)

        let task = Task { await viewModel.fetchProfile() }
        // fetchProfile이 .loading 세팅까지 진행되도록 양보
        await Task.yield()

        #expect(viewModel.profileData.isLoading == true)
        #expect(viewModel.isCardEditPending == true)

        await task.value
    }

    @Test("fetchProfile 성공(.loaded) 후에는 pending 해제")
    func loadedResolvesPending() async {
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(makeProfileData(challengeId: 1)))
        )

        await viewModel.fetchProfile()

        #expect(viewModel.isCardEditPending == false)
    }

    @Test("fetchProfile 실패(.failed) 후에는 pending 해제(무한 스피너를 두지 않는다)")
    func failedResolvesPending() async {
        let viewModel = makeViewModel(repository: ThrowingRepository(error: GenericTestError.boom))

        await viewModel.fetchProfile()

        #expect(viewModel.isCardEditPending == false)
    }

    @Test("이미 로드된 뒤의 재조회(pop 복귀)는 pending을 다시 켜지 않는다")
    func reloadOnPopKeepsPendingResolved() async {
        let repository = SlowStubRepository(
            profile: makeProfileData(challengeId: 1),
            delayNanoseconds: 100_000_000  // 0.1s
        )
        let viewModel = makeViewModel(
            repository: repository,
            previewProfileData: makeProfileData(challengeId: 1)
        )

        let task = Task { await viewModel.fetchProfile() }
        await Task.yield()

        #expect(viewModel.isCardEditPending == false, "재조회 중에도 로드된 프로필을 유지한다")

        await task.value
        #expect(viewModel.isCardEditPending == false)
    }
}

@MainActor
@Suite("MyPageViewModel — loadBusinessCard")
struct MyPageViewModelLoadBusinessCardTests {

    @Test("초기 상태는 .idle, activityStat은 .empty")
    func initialStateIsIdle() {
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(makeProfileData(challengeId: 1)))
        )
        #expect(viewModel.myCard == .idle)
        #expect(viewModel.activityStat == .empty)
    }

    @Test("성공 시 .loaded(card)와 activityStat이 함께 채워진다")
    func loadSuccessFillsCardAndStat() async {
        let card = makeMyCard(memberId: "7")
        let stat = ActivityStat(
            receivedCardCount: "12", studyCount: "3", activityCount: "1", bookmarkCount: "0"
        )
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(makeProfileData(challengeId: 1))),
            businessCardProvider: StubBusinessCardUseCaseProvider(
                fetchMyCardResult: .success(card),
                activityStat: stat
            )
        )

        await viewModel.loadBusinessCard()

        #expect(viewModel.myCard.value == card)
        #expect(viewModel.activityStat == stat)
    }

    @Test("성공 시 로드한 카드로 QR을 생성해 노출한다")
    func loadSuccessGeneratesQRImage() async {
        let card = makeMyCard(memberId: "7")
        let qrImage = makeStubCGImage()
        let recorder = RecordingGenerateCardQRUseCase(result: .success(qrImage))
        var provider = StubBusinessCardUseCaseProvider(fetchMyCardResult: .success(card))
        provider.generateCardQRUseCaseOverride = recorder
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(makeProfileData(challengeId: 1))),
            businessCardProvider: provider
        )

        await viewModel.loadBusinessCard()

        #expect(viewModel.qrImage === qrImage)
        #expect(recorder.lastCard == card)
    }

    @Test("QR 생성 실패해도 카드는 그대로 loaded — qrImage만 nil")
    func qrGenerationFailureKeepsCardLoaded() async {
        let card = makeMyCard(memberId: "7")
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(makeProfileData(challengeId: 1))),
            businessCardProvider: StubBusinessCardUseCaseProvider(
                fetchMyCardResult: .success(card),
                generateCardQRResult: .failure(GenericTestError.boom)
            )
        )

        await viewModel.loadBusinessCard()

        #expect(viewModel.myCard.value == card)
        #expect(viewModel.qrImage == nil)
    }

    @Test("AppError 발생 시 .failed로 전이")
    func appErrorPropagatesToFailed() async {
        let error = AppError.unknown(message: "boom")
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(makeProfileData(challengeId: 1))),
            businessCardProvider: StubBusinessCardUseCaseProvider(
                fetchMyCardResult: .failure(error)
            )
        )

        await viewModel.loadBusinessCard()

        #expect(viewModel.myCard.error == error)
    }

    @Test("일반 Error 발생 시 .failed(.unknown)으로 전이")
    func genericErrorWrappedAsUnknown() async {
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(makeProfileData(challengeId: 1))),
            businessCardProvider: StubBusinessCardUseCaseProvider(
                fetchMyCardResult: .failure(GenericTestError.boom)
            )
        )

        await viewModel.loadBusinessCard()

        guard case .failed(let appError) = viewModel.myCard,
              case .unknown(let message) = appError else {
            Issue.record("Expected .failed(.unknown), got \(viewModel.myCard)")
            return
        }
        #expect(message.contains("boom") || !message.isEmpty)
    }

    @Test("forceRefresh: true는 UseCase까지 그대로 전달한다")
    func forceRefreshIsPassedThroughToUseCase() async {
        let card = makeMyCard(memberId: "1")
        let recorder = RecordingFetchMyCardUseCase(result: .success(card))
        var provider = StubBusinessCardUseCaseProvider(fetchMyCardResult: .success(card))
        provider.fetchMyCardUseCaseOverride = recorder
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(makeProfileData(challengeId: 1))),
            businessCardProvider: provider
        )

        await viewModel.loadBusinessCard(forceRefresh: true)

        #expect(recorder.lastForceRefresh == true)
    }

    @Test("로딩 중 중복 호출은 무시 (UseCase 1회만 호출)")
    func duplicateLoadWhileLoadingIsIgnored() async {
        let card = makeMyCard(memberId: "1")
        let recorder = SlowFetchMyCardUseCase(
            result: .success(card), delayNanoseconds: 100_000_000
        )
        var provider = StubBusinessCardUseCaseProvider(fetchMyCardResult: .success(card))
        provider.fetchMyCardUseCaseOverride = recorder
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(makeProfileData(challengeId: 1))),
            businessCardProvider: provider
        )

        let first = Task { await viewModel.loadBusinessCard() }
        await Task.yield()

        await viewModel.loadBusinessCard()
        await first.value

        #expect(recorder.callCount == 1)
        #expect(viewModel.myCard.value == card)
    }
}

/// 리뷰 지적(Important): `MyPageView`의 카드 retry가 `loadBusinessCard`만 재실행하면,
/// 진입 시 네트워크 장애로 `profileData`·`myCard`가 함께 `.failed`였을 때 카드만 복구되고
/// `profileData`는 `.failed`로 남아 「명함 편집」 행이 활성 외관인 채 무반응이 된다
/// (``MyPageViewModel/isCardEditPending``이 `profileData`만 본다). `MyPageView.retryCardAndProfile`이
/// 두 로드를 함께 `forceRefresh`로 재시도하는지 뷰 렌더링 없이 고정한다.
@MainActor
@Suite("MyPageView.retryCardAndProfile — 카드 retry 시 프로필도 재조회")
struct MyPageViewRetryCardAndProfileTests {

    @Test("retry는 fetchProfile과 loadBusinessCard를 forceRefresh로 함께 재실행한다")
    func retryRefetchesBothProfileAndCard() async {
        let repository = StubRepository(result: .success(makeProfileData(challengeId: 1)))
        let card = makeMyCard(memberId: "1")
        let cardRecorder = RecordingFetchMyCardUseCase(result: .success(card))
        var provider = StubBusinessCardUseCaseProvider(fetchMyCardResult: .success(card))
        provider.fetchMyCardUseCaseOverride = cardRecorder
        let viewModel = makeViewModel(repository: repository, businessCardProvider: provider)

        await MyPageView.retryCardAndProfile(viewModel: viewModel)

        #expect(repository.lastForceRefresh == true, "카드만 재시도하면 프로필은 실패 상태로 남는다")
        #expect(cardRecorder.lastForceRefresh == true)
        #expect(viewModel.profileData.value?.challengeId == 1)
        #expect(viewModel.myCard.value == card)
    }
}

/// 리뷰 지적(후속): retry 스피너가 카드 로드 단계만 표시된다 — `retryCardAndProfile`은
/// 프로필 재조회를 먼저 기다리는데, 그 구간에는 `myCard`가 여전히 `.failed`라
/// `myCard.isLoading`만 보는 뷰에는 아무 진행 표시가 없다(재시도 버튼이 씹힌 것처럼 보인다).
/// `isCardRetryInFlight`가 두 로드 중 어느 쪽이 돌아도 켜지는지 고정한다.
@MainActor
@Suite("MyPageViewModel — isCardRetryInFlight (retry 스피너 공백 방지)")
struct MyPageViewModelCardRetryInFlightTests {

    @Test("초기 상태에서는 꺼져 있다")
    func idleIsNotInFlight() {
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(makeProfileData(challengeId: 1)))
        )
        #expect(viewModel.isCardRetryInFlight == false)
    }

    @Test("retry의 프로필 재조회 구간 — 카드 로드가 시작되기 전에도 켜져 있다")
    func profilePhaseKeepsSpinnerOn() async {
        let repository = SlowStubRepository(
            profile: makeProfileData(challengeId: 1),
            delayNanoseconds: 100_000_000  // 0.1s
        )
        let provider = StubBusinessCardUseCaseProvider(
            fetchMyCardResult: .failure(GenericTestError.boom)
        )
        let viewModel = makeViewModel(repository: repository, businessCardProvider: provider)
        await viewModel.loadBusinessCard()  // 진입 실패 상태(.failed) 재현

        let task = Task { await MyPageView.retryCardAndProfile(viewModel: viewModel) }
        await Task.yield()

        #expect(viewModel.myCard.isLoading == false, "카드 로드는 아직 시작 전이다")
        #expect(viewModel.isCardRetryInFlight == true)

        await task.value
    }

    @Test("카드 로드 구간에도 켜져 있다")
    func cardPhaseKeepsSpinnerOn() async {
        let card = makeMyCard(memberId: "1")
        let slow = SlowFetchMyCardUseCase(result: .success(card), delayNanoseconds: 100_000_000)
        var provider = StubBusinessCardUseCaseProvider(fetchMyCardResult: .success(card))
        provider.fetchMyCardUseCaseOverride = slow
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(makeProfileData(challengeId: 1))),
            businessCardProvider: provider
        )

        let task = Task { await viewModel.loadBusinessCard() }
        await Task.yield()

        #expect(viewModel.isCardRetryInFlight == true)

        await task.value
    }

    @Test("retry 완료 후에는 꺼진다")
    func settledTurnsOff() async {
        let card = makeMyCard(memberId: "1")
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(makeProfileData(challengeId: 1))),
            businessCardProvider: StubBusinessCardUseCaseProvider(
                fetchMyCardResult: .success(card)
            )
        )

        await MyPageView.retryCardAndProfile(viewModel: viewModel)

        #expect(viewModel.isCardRetryInFlight == false)
    }
}

/// 리뷰 지적(후속) 2건: ① 취소 경로가 `myCard`만 복원하고 `qrImage`는 진입 시 비운 `nil`
/// 그대로 남긴다 — 카드는 돌아왔는데 뒷면 QR만 빈다. ② pop 복귀 재조회가 로드된 카드를
/// `.loading`으로 밀어 카드 전체가 사라졌다 나타난다(깜빡임). 로드된 카드가 있으면 그대로
/// 보여 둔 채 재조회하고(stale-while-revalidate), 그 결과 취소도 카드·QR을 함께 보존한다.
@MainActor
@Suite("MyPageViewModel — loadBusinessCard 재조회·취소 상태 보존")
struct MyPageViewModelReloadPreservationTests {

    @Test("재조회가 취소돼도 카드와 QR이 함께 남는다")
    func cancellationKeepsCardAndQR() async {
        let card = makeMyCard(memberId: "1")
        let qr = makeStubCGImage()
        let sequenced = SequencedFetchMyCardUseCase(results: [
            .success(card),
            .failure(CancellationError()),
        ])
        var provider = StubBusinessCardUseCaseProvider(generateCardQRResult: .success(qr))
        provider.fetchMyCardUseCaseOverride = sequenced
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(makeProfileData(challengeId: 1))),
            businessCardProvider: provider
        )
        await viewModel.loadBusinessCard()

        await viewModel.loadBusinessCard(forceRefresh: true)

        #expect(viewModel.myCard.value == card)
        #expect(viewModel.qrImage === qr, "카드만 복원되고 QR이 빈 채 남으면 안 된다")
    }

    @Test("로드된 카드가 있는 동안의 재조회는 카드를 숨기지 않는다(깜빡임 방지)")
    func reloadKeepsLoadedCardVisible() async {
        let card = makeMyCard(memberId: "1")
        let qr = makeStubCGImage()
        let slow = SlowFetchMyCardUseCase(result: .success(card), delayNanoseconds: 100_000_000)
        var provider = StubBusinessCardUseCaseProvider(generateCardQRResult: .success(qr))
        provider.fetchMyCardUseCaseOverride = slow
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(makeProfileData(challengeId: 1))),
            businessCardProvider: provider
        )
        await viewModel.loadBusinessCard()

        let task = Task { await viewModel.loadBusinessCard(forceRefresh: true) }
        await Task.yield()

        #expect(viewModel.myCard.value == card, "재조회 중에도 카드가 그대로 보여야 한다")
        #expect(viewModel.qrImage === qr, "재조회 중에도 QR이 그대로 보여야 한다")

        await task.value
        #expect(viewModel.myCard.value == card)
    }

    @Test("로드된 카드가 있으면 재조회가 AppError로 실패해도 카드를 버리지 않는다")
    func reloadFailureKeepsLoadedCard() async {
        let card = makeMyCard(memberId: "1")
        let qr = makeStubCGImage()
        let sequenced = SequencedFetchMyCardUseCase(results: [
            .success(card),
            .failure(AppError.unknown(message: "재조회 실패")),
        ])
        var provider = StubBusinessCardUseCaseProvider(generateCardQRResult: .success(qr))
        provider.fetchMyCardUseCaseOverride = sequenced
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(makeProfileData(challengeId: 1))),
            businessCardProvider: provider
        )
        await viewModel.loadBusinessCard()

        await viewModel.loadBusinessCard(forceRefresh: true)

        #expect(viewModel.myCard.value == card, "갱신이 실패한 것이지 카드가 사라진 게 아니다")
        #expect(viewModel.myCard.error == nil, "화면 전체가 재시도 뷰로 바뀌면 안 된다")
        #expect(viewModel.qrImage === qr)
    }

    @Test("보여줄 카드가 없으면 실패는 그대로 .failed로 전이한다(재시도 경로 보존)")
    func firstLoadFailureStillSurfacesError() async {
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(makeProfileData(challengeId: 1))),
            businessCardProvider: StubBusinessCardUseCaseProvider(
                fetchMyCardResult: .failure(AppError.unknown(message: "첫 조회 실패"))
            )
        )

        await viewModel.loadBusinessCard()

        #expect(viewModel.myCard.error != nil)
        #expect(viewModel.myCard.value == nil)
    }

    @Test("로드된 카드가 있으면 일반 Error 재조회 실패도 카드를 남긴다")
    func reloadGenericFailureKeepsLoadedCard() async {
        let card = makeMyCard(memberId: "1")
        let sequenced = SequencedFetchMyCardUseCase(results: [
            .success(card),
            .failure(GenericTestError.boom),
        ])
        var provider = StubBusinessCardUseCaseProvider(fetchMyCardResult: .success(card))
        provider.fetchMyCardUseCaseOverride = sequenced
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(makeProfileData(challengeId: 1))),
            businessCardProvider: provider
        )
        await viewModel.loadBusinessCard()

        await viewModel.loadBusinessCard(forceRefresh: true)

        #expect(viewModel.myCard.value == card)
    }

    @Test("로드된 상태의 재조회도 중복 호출은 무시된다 (UseCase 호출 수 유지)")
    func reloadStillDeduplicatesConcurrentCalls() async {
        let card = makeMyCard(memberId: "1")
        let slow = SlowFetchMyCardUseCase(result: .success(card), delayNanoseconds: 100_000_000)
        var provider = StubBusinessCardUseCaseProvider(fetchMyCardResult: .success(card))
        provider.fetchMyCardUseCaseOverride = slow
        let viewModel = makeViewModel(
            repository: StubRepository(result: .success(makeProfileData(challengeId: 1))),
            businessCardProvider: provider
        )
        await viewModel.loadBusinessCard()          // 1회

        let reload = Task { await viewModel.loadBusinessCard(forceRefresh: true) }  // 2회
        await Task.yield()
        await viewModel.loadBusinessCard()          // 진행 중 — 무시돼야 한다
        await reload.value

        #expect(slow.callCount == 2)
    }
}

// MARK: - Helpers

private enum GenericTestError: Error { case boom }

private func makeMyCard(memberId: String) -> MyCard {
    MyCard(
        memberId: memberId,
        name: "테스트",
        nickname: "tester",
        part: .pm,
        generation: "12",
        university: "UMC대학교",
        email: nil,
        github: nil,
        linkedIn: nil,
        blog: nil,
        avatarURL: nil
    )
}

/// 호출 순서대로 준비된 결과를 꺼내 쓰는 스텁 — "1회차 성공 → 2회차 취소" 같은
/// 재조회 시나리오를 만든다.
private final class SequencedFetchMyCardUseCase: FetchMyCardUseCaseProtocol, @unchecked Sendable {
    private var results: [Result<MyCard, Error>]

    init(results: [Result<MyCard, Error>]) {
        self.results = results
    }

    func execute(forceRefresh: Bool) async throws -> MyCard {
        try results.removeFirst().get()
    }
}

private final class RecordingFetchMyCardUseCase: FetchMyCardUseCaseProtocol, @unchecked Sendable {
    private let result: Result<MyCard, Error>
    private(set) var lastForceRefresh: Bool?

    init(result: Result<MyCard, Error>) {
        self.result = result
    }

    func execute(forceRefresh: Bool) async throws -> MyCard {
        lastForceRefresh = forceRefresh
        return try result.get()
    }
}

private final class RecordingGenerateCardQRUseCase:
    GenerateCardQRUseCaseProtocol, @unchecked Sendable {
    private let result: Result<CGImage, Error>
    private(set) var lastCard: MyCard?

    init(result: Result<CGImage, Error>) {
        self.result = result
    }

    func execute(for card: MyCard) throws -> CGImage {
        lastCard = card
        return try result.get()
    }
}

private final class SlowFetchMyCardUseCase: FetchMyCardUseCaseProtocol, @unchecked Sendable {
    private let result: Result<MyCard, Error>
    private let delayNanoseconds: UInt64
    private let lock = NSLock()
    private var _callCount = 0

    var callCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _callCount
    }

    init(result: Result<MyCard, Error>, delayNanoseconds: UInt64) {
        self.result = result
        self.delayNanoseconds = delayNanoseconds
    }

    func execute(forceRefresh: Bool) async throws -> MyCard {
        lock.lock()
        _callCount += 1
        lock.unlock()
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return try result.get()
    }
}

@MainActor
private func makeViewModel(
    repository: MyPageRepositoryProtocol,
    oauthResult: Result<[MemberOAuth], Error> = .success([]),
    previewProfileData: ProfileData? = nil,
    businessCardProvider: BusinessCardUseCaseProviding = StubBusinessCardUseCaseProvider()
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
    container.register(BusinessCardUseCaseProviding.self) { businessCardProvider }
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
