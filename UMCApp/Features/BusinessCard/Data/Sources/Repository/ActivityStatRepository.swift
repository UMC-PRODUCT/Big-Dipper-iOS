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
/// 통합 stat API 부재로 기존 소스 3개를 조합한다. 실패는 그대로 throw — 조회 실패를
/// "0"으로 바꾸지 않는다 (#1222). 서버 stat API가 생기면 이 구현체만 교체한다.
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

    /// 커서 응답에는 총개수가 없다 — 한 페이지(50) 를 받아 항목 수를 센다.
    ///
    /// 50건을 다 채우고 `hasNext` 가 참이면 **실제 수는 더 많다.** 예전에는 그 상태에서도
    /// 그냥 "50"을 보여 줘서 51번째부터는 없는 것처럼 보였다 — 지금은 `"50+"` 로 잘렸음을
    /// 드러낸다 (#1222).
    public func fetchStudyCount() async throws -> String {
        let response = try await networkRequesting.request(
            BusinessCardRouter.getMyStudyGroups(query: StudyCountQueryDTO())
        )
        let page: StudyCountPageDTO = try decodeAbsorbingWrapper(from: response.data)
        return page.hasNext ? "\(page.itemCount)+" : "\(page.itemCount)"
    }

    /// 서버 `totalElements`를 **변환 없이 그대로** 돌려준다 (절대 규칙 #2).
    /// Int로 바꾸면 Repository 경계를 서버 정수가 Int로 건너고, `?? 0`이 비정상 값을
    /// 조용히 0으로 삼킨다. 표시 문자열은 UseCase가 그대로 쓴다.
    public func fetchBookmarkCount() async throws -> String {
        let response = try await networkRequesting.request(
            BusinessCardRouter.getScrappedPosts(query: ScrappedCountQueryDTO())
        )
        let page: ScrappedCountPageDTO = try decodeAbsorbingWrapper(from: response.data)
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

    // MARK: - Private Function

    /// `APIResponse` 래핑·raw 양쪽 응답을 흡수한다 (MyPageRepository.fetchMemberProfile 선례).
    private func decodeAbsorbingWrapper<T: Codable>(from data: Data) throws -> T {
        if let wrapped = try? decoder.decode(APIResponse<T>.self, from: data),
           let result = try? wrapped.unwrap() {
            return result
        }
        return try decoder.decode(T.self, from: data)
    }
}
