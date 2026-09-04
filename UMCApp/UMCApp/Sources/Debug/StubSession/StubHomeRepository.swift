//
//  StubHomeRepository.swift
//  UMCApp
//
//  Created by jaewon Lee on 8/3/26.
//

#if DEBUG
import HomeDomain

/// 카카오 로그인 서버 미등록 기간 한정 홈 프로필 Repository stub (핵심규칙 #5).
///
/// 시즌 카드/세대별 상벌점 카드 픽스처를 반환한다.
struct StubHomeRepository: HomeRepositoryProtocol {

    func fetchMyProfile(forceRefresh: Bool) async throws -> HomeProfileResult {
        StubSessionFixtures.homeProfileResult
    }

    /// stub 세션에는 등록할 서버가 없으므로 no-op.
    func registerFCMToken(fcmToken: String) async throws {}
}
#endif
