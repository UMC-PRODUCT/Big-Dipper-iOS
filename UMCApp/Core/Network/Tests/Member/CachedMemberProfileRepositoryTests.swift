//
//  CachedMemberProfileRepositoryTests.swift
//  CoreNetworkTests
//
//  Created by euijjang97 on 7/11/26.
//
//  캐시 히트/미스, `primeCache`/`invalidateCache` 무효화 트리거, 동시 호출 병합
//  (in-flight coalescing)을 검증한다.
//

import CoreDomain
import Foundation
import Testing
@testable import CoreNetwork

@Suite("CachedMemberProfileRepository — 세션 단위 캐싱")
struct CachedMemberProfileRepositoryTests {

    // MARK: - 캐시 히트/미스

    @Test("최초 호출은 원격에서 조회하고, 이후 호출은 캐시를 반환해 원격 호출이 1회로 유지된다")
    func secondCallHitsCache() async throws {
        let profile = Fixture.profile(memberId: "1")
        let remote = FakeRemoteMemberProfileRepository(result: .success(profile))
        let sut = CachedMemberProfileRepository(remote: remote)

        let first = try await sut.fetchMyProfile()
        let second = try await sut.fetchMyProfile()

        #expect(first == profile)
        #expect(second == profile)
        #expect(await remote.callCount == 1)
    }

    @Test("forceRefresh: true는 캐시가 있어도 원격을 다시 호출하고 캐시를 최신 값으로 교체한다")
    func forceRefreshBypassesCache() async throws {
        let remote = FakeRemoteMemberProfileRepository(result: .success(Fixture.profile(memberId: "1")))
        let sut = CachedMemberProfileRepository(remote: remote)
        _ = try await sut.fetchMyProfile()

        await remote.setResult(.success(Fixture.profile(memberId: "2")))
        let refreshed = try await sut.fetchMyProfile(forceRefresh: true)
        let cachedAfterRefresh = try await sut.fetchMyProfile()

        #expect(refreshed.memberId == "2")
        #expect(cachedAfterRefresh.memberId == "2")
        #expect(await remote.callCount == 2)
    }

    @Test("원격 조회가 실패하면 캐시에 남기지 않고, 다음 호출은 다시 원격을 조회한다")
    func failureIsNotCached() async throws {
        let remote = FakeRemoteMemberProfileRepository(result: .failure(FakeRemoteMemberProfileRepository.FakeError.boom))
        let sut = CachedMemberProfileRepository(remote: remote)

        await #expect(throws: FakeRemoteMemberProfileRepository.FakeError.boom) {
            _ = try await sut.fetchMyProfile()
        }

        await remote.setResult(.success(Fixture.profile(memberId: "1")))
        let recovered = try await sut.fetchMyProfile()

        #expect(recovered.memberId == "1")
        #expect(await remote.callCount == 2)
    }

    // MARK: - 무효화 트리거

    @Test("primeCache — 원격 호출 없이 캐시를 채우고, 이후 fetchMyProfile()은 원격을 호출하지 않는다")
    func primeCacheWarmsCacheWithoutNetworkCall() async throws {
        let remote = FakeRemoteMemberProfileRepository(
            result: .failure(FakeRemoteMemberProfileRepository.FakeError.boom)
        )
        let sut = CachedMemberProfileRepository(remote: remote)
        let profile = Fixture.profile(memberId: "primed")

        await sut.primeCache(with: profile)
        let result = try await sut.fetchMyProfile()

        #expect(result == profile)
        #expect(await remote.callCount == 0)
    }

    @Test("invalidateCache — 캐시를 비워 다음 fetchMyProfile() 호출이 원격을 다시 조회한다")
    func invalidateCacheClearsCachedProfile() async throws {
        let remote = FakeRemoteMemberProfileRepository(result: .success(Fixture.profile(memberId: "1")))
        let sut = CachedMemberProfileRepository(remote: remote)
        _ = try await sut.fetchMyProfile()

        await sut.invalidateCache()
        await remote.setResult(.success(Fixture.profile(memberId: "2")))
        let afterInvalidate = try await sut.fetchMyProfile()

        #expect(afterInvalidate.memberId == "2")
        #expect(await remote.callCount == 2)
    }

    // MARK: - 동시 호출 병합 (in-flight coalescing)

    @Test("겹치는 동시 호출은 진행 중인 요청 하나로 병합되어 원격 호출이 1회만 발생한다")
    func concurrentCallsCoalesceIntoSingleNetworkRequest() async throws {
        let gate = Gate()
        let profile = Fixture.profile(memberId: "1")
        let remote = FakeRemoteMemberProfileRepository(result: .success(profile))
        await remote.setGate(gate)
        let sut = CachedMemberProfileRepository(remote: remote)

        async let first = sut.fetchMyProfile()
        async let second = sut.fetchMyProfile()

        try await waitUntil { await remote.callCount == 1 }
        await gate.release()

        let (firstResult, secondResult) = try await (first, second)

        #expect(firstResult == profile)
        #expect(secondResult == profile)
        #expect(await remote.callCount == 1)
    }
}

// MARK: - Fixture

private enum Fixture {
    static func profile(memberId: String) -> Profile {
        Profile(memberId: memberId, name: "홍길동", nickname: "길동이", generations: ["11"])
    }
}

// MARK: - Test Doubles

private actor FakeRemoteMemberProfileRepository: MemberProfileRepositoryProtocol {
    enum FakeError: Error, Equatable {
        case boom
    }

    private(set) var callCount = 0
    private var result: Result<Profile, Error>
    private var gate: Gate?

    init(result: Result<Profile, Error>) {
        self.result = result
    }

    func setResult(_ result: Result<Profile, Error>) {
        self.result = result
    }

    /// 특정 시점까지 반환을 붙잡아두는 게이트를 설정한다 (동시 호출 병합 검증용).
    func setGate(_ gate: Gate) {
        self.gate = gate
    }

    func fetchMyProfile() async throws -> Profile {
        callCount += 1
        if let gate {
            await gate.waitUntilReleased()
        }
        return try result.get()
    }
}

/// 두 개 이상의 동시 호출이 실제로 겹친 상태에서 결과를 함께 흘려보내기 위한 신호 게이트.
private actor Gate {
    private var isReleased = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func release() {
        isReleased = true
        continuations.forEach { $0.resume() }
        continuations.removeAll()
    }

    func waitUntilReleased() async {
        if isReleased { return }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }
}

/// 폴링 기반 조건 대기 (다른 테스트 파일들과 동일한 패턴).
private func waitUntil(
    timeout: Duration = .seconds(2),
    _ condition: () async -> Bool
) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while await !condition() {
        if ContinuousClock.now >= deadline {
            Issue.record("waitUntil 타임아웃")
            return
        }
        await Task.yield()
    }
}
