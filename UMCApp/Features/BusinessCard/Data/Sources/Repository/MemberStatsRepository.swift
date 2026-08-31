//
//  MemberStatsRepository.swift
//  BusinessCardData
//
//  Created by euijjang97 on 8/30/26.
//

import Foundation
import Moya
import CoreNetwork
import CoreDomain
import BusinessCardDomain

/// 서버 통합 카운트 저장소 (`GET /api/v2/member/me/stats`).
///
/// 소스 3개를 앱에서 조합하던 ``ActivityStatRepository`` 를 한 왕복으로 대체한다. 다만
/// 서버에 이 경로가 아직 없어서(2026-08-30 확인) **릴리스 기본 구현은 여전히 조합 쪽**이다
/// — 여기서 갈아 끼우면 릴리스의 카운트가 전부 "-"로 퇴행한다.
///
/// 「나의 활동·프로젝트」 수만 서버에 요구하지 않는다. 그 값은 마이페이지 활동 목록과
/// 같은 배열에서 나와야 하고, 원천 데이터가 이미 프로필 응답으로 캐시돼 있어 왕복이 0회다.
public final class MemberStatsRepository: ActivityStatRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let networkRequesting: any BusinessCardNetworkRequesting
    private let memberProfileRepository: MemberProfileRepositoryProtocol
    private let decoder = JSONDecoder()

    // MARK: - Init

    /// 운영 이니셜라이저.
    public convenience init(
        adapter: MoyaNetworkAdapter,
        memberProfileRepository: MemberProfileRepositoryProtocol
    ) {
        self.init(networkRequesting: adapter, memberProfileRepository: memberProfileRepository)
    }

    /// 테스트 seam 주입용 (baseURL fatalError 회피 — MyPage 선례).
    init(
        networkRequesting: any BusinessCardNetworkRequesting,
        memberProfileRepository: MemberProfileRepositoryProtocol
    ) {
        self.networkRequesting = networkRequesting
        self.memberProfileRepository = memberProfileRepository
    }

    // MARK: - Function

    /// 서버가 세 값을 non-null 로 준다 — 「0건」과 「못 셌다」를 서버가 섞지 않는다.
    /// 조회 자체가 실패하면 그대로 던지고, 「전부 못 셌다」 판단은 UseCase가 한다.
    public func fetchMemberStats() async throws -> MemberStats {
        let response = try await networkRequesting.request(BusinessCardRouter.getMemberStats)
        let stats = try decoder.decodeAbsorbingWrapper(
            MemberStatsResponseDTO.self, from: response.data
        )
        return MemberStats(
            receivedCardCount: stats.receivedCardCount,
            studyCount: stats.studyCount,
            bookmarkCount: stats.scrapCount
        )
    }

    /// 활동·프로젝트 이력 수 = 마이페이지 활동 목록의 항목 수 (추가 왕복 없음 — 프로필 캐시).
    public func fetchActivityCount() async throws -> Int {
        let profile = try await memberProfileRepository.fetchMyProfile(forceRefresh: false)
        return profile.activityLogs().count
    }
}
