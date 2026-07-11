//
//  CachedMemberProfileRepository.swift
//  CoreNetwork
//
//  Created by euijjang97 on 7/11/26.
//

import CoreDomain
import Foundation

/// 정본 프로필 조회 파이프라인(``MemberProfileRepository``)에 세션 단위 캐싱을 적용하는 데코레이터.
///
/// `MemberProfileRepositoryProtocol` 소비부(Auth/Home/MyPage)의 공개 계약은 그대로 두고, 동일 세션
/// 내 반복되는 `GET /api/v1/member/me` 왕복을 캐시 히트로 흡수한다. 캐시 수명은 이 인스턴스의
/// 수명과 같다 — `DIContainer`가 싱글턴으로 캐싱하므로 로그아웃/세션 만료 시 `DIContainer.resetCache()`가
/// 인스턴스 자체를 폐기하면 자연히 초기화된다. 그와 별개로 ``invalidateCache()``를 명시적으로 호출하는
/// 경로(로그아웃·세션 만료 흐름)도 함께 두어, 인스턴스가 아직 살아있는 동안의 진행 중인 요청까지
/// 방어적으로 정리한다.
///
/// `actor`로 격리해 캐시 상태(`cachedProfile`/`inFlightTask`)에 대한 동시 접근을 직렬화하고,
/// 동시에 들어오는 여러 `fetchMyProfile()` 호출은 진행 중인 네트워크 요청 하나로 병합한다
/// (in-flight coalescing).
public actor CachedMemberProfileRepository: MemberProfileRepositoryProtocol {

    // MARK: - Property

    private let remote: MemberProfileRepositoryProtocol
    private var cachedProfile: Profile?
    private var inFlightTask: Task<Profile, Error>?

    /// 캐시가 마지막으로 리셋(무효화/강제 프라임)된 시점을 나타내는 세대 번호.
    ///
    /// 진행 중인 네트워크 요청이 완료됐을 때, 그 사이 캐시가 무효화/갱신됐다면(세대가 바뀌었다면)
    /// 뒤늦게 도착한 결과로 캐시를 덮어쓰지 않기 위한 가드다.
    private var generation = 0

    // MARK: - Init

    public init(remote: MemberProfileRepositoryProtocol) {
        self.remote = remote
    }

    // MARK: - Function

    public func fetchMyProfile() async throws -> Profile {
        try await fetchMyProfile(forceRefresh: false)
    }

    public func fetchMyProfile(forceRefresh: Bool) async throws -> Profile {
        if !forceRefresh, let cachedProfile {
            return cachedProfile
        }

        if let inFlightTask {
            return try await inFlightTask.value
        }

        let requestGeneration = generation
        let task = Task { try await self.remote.fetchMyProfile() }
        inFlightTask = task

        do {
            let profile = try await task.value
            if generation == requestGeneration {
                cachedProfile = profile
                inFlightTask = nil
            }
            return profile
        } catch {
            if generation == requestGeneration {
                inFlightTask = nil
            }
            throw error
        }
    }

    public func primeCache(with profile: Profile) async {
        generation += 1
        cachedProfile = profile
        inFlightTask = nil
    }

    public func invalidateCache() async {
        generation += 1
        cachedProfile = nil
        inFlightTask = nil
    }
}
