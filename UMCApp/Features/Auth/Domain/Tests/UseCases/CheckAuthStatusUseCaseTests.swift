//
//  CheckAuthStatusUseCaseTests.swift
//  AuthDomainTests
//
//  Created by euijjang97 on 7/8/26.
//

import CoreDomain
import Foundation
import Testing
import UMCFoundation
@testable import AuthDomain

// MARK: - Helpers

private func makeIsolatedUserDefaults() -> UserDefaults {
    let suiteName = "CheckAuthStatusUseCaseTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

/// `FetchMemberProfileUseCaseProtocol`의 테스트용 Mock 구현체
final class MockFetchMemberProfileUseCase: FetchMemberProfileUseCaseProtocol, @unchecked Sendable {
    var result: Result<Profile, Error> = .failure(AuthTestError.boom)
    private(set) var executeCallCount = 0

    func execute() async throws -> Profile {
        executeCallCount += 1
        return try result.get()
    }
}

private func makeUseCase(
    repository: MockAuthRepository,
    fetchMemberProfileUseCase: MockFetchMemberProfileUseCase = MockFetchMemberProfileUseCase(),
    syncProfileStorageSpy: SyncProfileStorageSpy = SyncProfileStorageSpy(),
    userDefaults: UserDefaults = makeIsolatedUserDefaults()
) -> CheckAuthStatusUseCase {
    CheckAuthStatusUseCase(
        repository: repository,
        fetchMemberProfileUseCase: fetchMemberProfileUseCase,
        syncProfileStorageUseCase: syncProfileStorageSpy,
        userDefaults: userDefaults
    )
}

// MARK: - Tests

@Suite("CheckAuthStatusUseCase — 부트스트랩 인증 상태 판정")
struct CheckAuthStatusUseCaseTests {

    @Test("토큰이 없으면 세션 갱신·프로필 조회 없이 notLoggedIn")
    func returnsNotLoggedInWhenNoSession() async {
        let repository = MockAuthRepository()
        repository.hasSessionResult = false
        let fetchProfile = MockFetchMemberProfileUseCase()
        let syncSpy = SyncProfileStorageSpy()
        let useCase = makeUseCase(
            repository: repository,
            fetchMemberProfileUseCase: fetchProfile,
            syncProfileStorageSpy: syncSpy
        )

        let status = await useCase.execute()

        #expect(status == .notLoggedIn)
        #expect(repository.refreshSessionCallCount == 0)
        #expect(fetchProfile.executeCallCount == 0)
        #expect(syncSpy.executeCallCount == 0)
    }

    @Test("세션 갱신이 실패해도 기존 토큰으로 프로필 조회를 시도해 승인 판정")
    func fallsBackToProfileFetchWhenRefreshFails() async {
        let repository = MockAuthRepository()
        repository.hasSessionResult = true
        repository.refreshSessionError = AuthTestError.boom
        let fetchProfile = MockFetchMemberProfileUseCase()
        fetchProfile.result = .success(Profile(
            memberId: "1",
            name: "홍길동",
            nickname: "길동이",
            generations: ["11"]
        ))
        let syncSpy = SyncProfileStorageSpy()
        let useCase = makeUseCase(
            repository: repository,
            fetchMemberProfileUseCase: fetchProfile,
            syncProfileStorageSpy: syncSpy
        )

        let status = await useCase.execute()

        #expect(status == .approved)
        #expect(repository.refreshSessionCallCount == 1)
        #expect(fetchProfile.executeCallCount == 1)
        #expect(syncSpy.executeCallCount == 1)
    }

    @Test("프로필에 소속 기수가 있으면 approved이고 프로필 동기화를 1회 수행한다")
    func returnsApprovedWhenProfileHasGenerations() async {
        let repository = MockAuthRepository()
        repository.hasSessionResult = true
        let profile = Profile(
            memberId: "1",
            name: "홍길동",
            nickname: "길동이",
            generations: ["10", "11"]
        )
        let fetchProfile = MockFetchMemberProfileUseCase()
        fetchProfile.result = .success(profile)
        let syncSpy = SyncProfileStorageSpy()
        let useCase = makeUseCase(
            repository: repository,
            fetchMemberProfileUseCase: fetchProfile,
            syncProfileStorageSpy: syncSpy
        )

        let status = await useCase.execute()

        #expect(status == .approved)
        #expect(repository.refreshSessionCallCount == 1)
        #expect(fetchProfile.executeCallCount == 1)
        #expect(syncSpy.executeCallCount == 1)
        #expect(syncSpy.receivedProfile == profile)
    }

    @Test("프로필 조회는 성공했지만 소속 기수가 없고 canAutoLogin이 true면 pendingApproval, 동기화는 없음")
    func returnsPendingApprovalWhenProfileHasNoGenerations() async {
        let repository = MockAuthRepository()
        repository.hasSessionResult = true
        let fetchProfile = MockFetchMemberProfileUseCase()
        fetchProfile.result = .success(Profile(
            memberId: "1",
            name: "홍길동",
            nickname: "길동이",
            generations: []
        ))
        let syncSpy = SyncProfileStorageSpy()
        let userDefaults = makeIsolatedUserDefaults()
        userDefaults.set(true, forKey: AppStorageKey.canAutoLogin)
        let useCase = makeUseCase(
            repository: repository,
            fetchMemberProfileUseCase: fetchProfile,
            syncProfileStorageSpy: syncSpy,
            userDefaults: userDefaults
        )

        let status = await useCase.execute()

        #expect(status == .pendingApproval)
        #expect(repository.refreshSessionCallCount == 1)
        #expect(fetchProfile.executeCallCount == 1)
        #expect(syncSpy.executeCallCount == 0)
    }

    @Test("소속 기수가 없고 canAutoLogin이 false이면 notLoggedIn (회귀 테스트)")
    func returnsNotLoggedInWhenNoGenerationsAndCanAutoLoginIsFalse() async {
        let repository = MockAuthRepository()
        repository.hasSessionResult = true
        let fetchProfile = MockFetchMemberProfileUseCase()
        fetchProfile.result = .success(Profile(
            memberId: "1",
            name: "홍길동",
            nickname: "길동이",
            generations: []
        ))
        let syncSpy = SyncProfileStorageSpy()
        // canAutoLogin 미설정(false) 상태의 격리 UserDefaults.
        let useCase = makeUseCase(
            repository: repository,
            fetchMemberProfileUseCase: fetchProfile,
            syncProfileStorageSpy: syncSpy
        )

        let status = await useCase.execute()

        #expect(status == .notLoggedIn)
        #expect(syncSpy.executeCallCount == 0)
    }

    @Test("프로필 조회 자체가 실패하면 notLoggedIn")
    func returnsNotLoggedInWhenProfileFetchFails() async {
        let repository = MockAuthRepository()
        repository.hasSessionResult = true
        let fetchProfile = MockFetchMemberProfileUseCase()
        fetchProfile.result = .failure(AuthTestError.boom)
        let syncSpy = SyncProfileStorageSpy()
        let useCase = makeUseCase(
            repository: repository,
            fetchMemberProfileUseCase: fetchProfile,
            syncProfileStorageSpy: syncSpy
        )

        let status = await useCase.execute()

        #expect(status == .notLoggedIn)
        #expect(repository.refreshSessionCallCount == 1)
        #expect(fetchProfile.executeCallCount == 1)
        #expect(syncSpy.executeCallCount == 0)
    }

    @Test("프로필 조회 실패 + canAutoLogin이 true이면 로그아웃을 1회 수행한다")
    func logsOutWhenProfileFetchFailsAndCanAutoLoginIsTrue() async {
        let repository = MockAuthRepository()
        repository.hasSessionResult = true
        let fetchProfile = MockFetchMemberProfileUseCase()
        fetchProfile.result = .failure(AuthTestError.boom)
        let userDefaults = makeIsolatedUserDefaults()
        userDefaults.set(true, forKey: AppStorageKey.canAutoLogin)
        let useCase = makeUseCase(
            repository: repository,
            fetchMemberProfileUseCase: fetchProfile,
            userDefaults: userDefaults
        )

        let status = await useCase.execute()

        #expect(status == .notLoggedIn)
        #expect(repository.logoutCallCount == 1)
    }

    @Test("프로필 조회 실패 + canAutoLogin이 false이면 로그아웃을 호출하지 않는다")
    func doesNotLogOutWhenProfileFetchFailsAndCanAutoLoginIsFalse() async {
        let repository = MockAuthRepository()
        repository.hasSessionResult = true
        let fetchProfile = MockFetchMemberProfileUseCase()
        fetchProfile.result = .failure(AuthTestError.boom)
        let useCase = makeUseCase(repository: repository, fetchMemberProfileUseCase: fetchProfile)

        let status = await useCase.execute()

        #expect(status == .notLoggedIn)
        #expect(repository.logoutCallCount == 0)
    }
}
