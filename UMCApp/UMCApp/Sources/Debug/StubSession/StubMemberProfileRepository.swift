//
//  StubMemberProfileRepository.swift
//  UMCApp
//
//  Created by jaewon Lee on 8/3/26.
//

#if DEBUG
import CoreDomain

/// 카카오 로그인 서버 미등록 기간 한정 정본 프로필 Repository stub (핵심규칙 #5).
///
/// 항상 승인된(`isApproved`) 픽스처 프로필을 반환해 부트스트랩이 `.approved`로 판정되게 한다.
/// `primeCache`/`invalidateCache`는 프로토콜 기본 구현(no-op)을 그대로 사용한다.
struct StubMemberProfileRepository: MemberProfileRepositoryProtocol {

    func fetchMyProfile() async throws -> Profile {
        StubSessionFixtures.profile
    }

    func fetchMyProfile(forceRefresh: Bool) async throws -> Profile {
        StubSessionFixtures.profile
    }
}
#endif
