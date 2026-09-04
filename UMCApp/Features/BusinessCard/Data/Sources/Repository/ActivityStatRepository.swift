//
//  ActivityStatRepository.swift
//  BusinessCardData
//
//  Created by One on 8/16/26.
//

import Foundation
import Moya
import CoreNetwork
import CoreDomain
import BusinessCardDomain

/// 마이페이지 행 카운트 저장소 (MP-F07~F09).
///
/// 통합 stat API 부재로 기존 소스 3개를 조합한다. 실패는 소스별로 격리해 `nil` 로 남긴다
/// — 조회 실패를 "0"으로 바꾸지 않는다 (#1222).
///
/// 서버에 `GET /api/v2/member/me/stats` 가 배포되면 ``MemberStatsRepository`` 로 갈아
/// 끼우고 이 구현을 지운다. 그 전까지는 **릴리스 기본 구현**이다 — 지금 지우면 릴리스의
/// 카운트가 전부 "-"로 퇴행한다.
public final class ActivityStatRepository: ActivityStatRepositoryProtocol, @unchecked Sendable {

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

    /// 세 소스 중 **성공한 것만** 담는다. 소스별 실패를 여기서 격리하지 않으면 스터디
    /// 조회 하나가 죽었을 때 스크랩 숫자까지 같이 사라진다.
    ///
    /// `receivedCardCount` 는 `nil` 이다 — 서버에 명함첩이 없으니 셀 방법이 없고, 로컬
    /// 캐시로 메우는 판단은 UseCase가 한다.
    public func fetchMemberStats() async throws -> MemberStats {
        async let study = try? fetchStudyCount()
        async let bookmark = try? fetchBookmarkCount()
        return await MemberStats(
            receivedCardCount: nil,
            studyCount: study,
            bookmarkCount: bookmark
        )
    }

    /// 커서 응답에는 총개수가 없다 — 한 페이지(50) 를 받아 항목 수를 센다.
    ///
    /// 50건을 다 채우고 `hasNext` 가 참이면 **실제 수는 더 많다.** 예전에는 그 상태에서도
    /// 그냥 "50"을 보여 줘서 51번째부터는 없는 것처럼 보였다 — 지금은 `"50+"` 로 잘렸음을
    /// 드러낸다 (#1222).
    public func fetchStudyCount() async throws -> String {
        let response = try await networkRequesting.request(
            BusinessCardRouter.getMyStudyGroups(query: StudyCountQueryDTO())
        )
        let page = try decoder.decodeAbsorbingWrapper(StudyCountPageDTO.self, from: response.data)
        return page.hasNext ? "\(page.itemCount)+" : "\(page.itemCount)"
    }

    /// 서버 `totalElements`를 **변환 없이 그대로** 돌려준다 (핵심 규칙 #2).
    /// Int로 바꾸면 Repository 경계를 서버 정수가 Int로 건너고, `?? 0`이 비정상 값을
    /// 조용히 0으로 삼킨다. 표시 문자열은 UseCase가 그대로 쓴다.
    public func fetchBookmarkCount() async throws -> String {
        let response = try await networkRequesting.request(
            BusinessCardRouter.getScrappedPosts(query: ScrappedCountQueryDTO())
        )
        let page = try decoder.decodeAbsorbingWrapper(
            ScrappedCountPageDTO.self, from: response.data
        )
        return page.totalElements
    }

    /// 활동·프로젝트 이력 수 = 마이페이지 활동 목록의 항목 수 (추가 왕복 없음 — 프로필 캐시).
    ///
    /// 예전에는 여기서 `challengerRecords` 를 직접 세는 바람에 운영진 이력이 목록에는
    /// 보이고 숫자에는 빠졌다. 이제 목록과 같은 ``CoreDomain/Profile/activityLogs()`` 를
    /// 부른다 — 규칙이 한 곳에 있으니 다시 갈라질 수 없다 (#1222).
    public func fetchActivityCount() async throws -> Int {
        let profile = try await memberProfileRepository.fetchMyProfile(forceRefresh: false)
        return profile.activityLogs().count
    }
}
