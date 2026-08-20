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
import UMCFoundation
import BusinessCardDomain

/// 마이페이지 행 카운트 저장소 (MP-F07~F09).
///
/// 통합 stat API 부재로 기존 소스 3개를 조합한다. 실패는 그대로 throw — "0" 폴백은
/// UseCase 정책. 서버 stat API가 생기면 이 구현체만 교체한다.
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

    public func fetchStudyCount() async throws -> Int {
        let response = try await networkRequesting.request(
            BusinessCardRouter.getMyStudyGroups(query: StudyCountQueryDTO())
        )
        let page: StudyCountPageDTO = try decodeAbsorbingWrapper(from: response.data)
        return page.itemCount
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

    /// 활동·프로젝트 이력 수 = admin 제외 챌린저 기수 기록 수 (추가 왕복 없음 — 프로필 캐시).
    ///
    /// 설계서가 적은 소스 `activityLogs`는 CoreDomain.Profile에 없는 필드다(MyPageDomain
    /// 파생 모델 소유 — 크로스 피처 import 금지로 참조 불가). 그래서 정본
    /// Profile.challengerRecords에서 재파생한다. MP-F08 우측 숫자의 의미는
    /// "챌린저 이력 수"다 (운영진 항목 포함 여부에서 MyPage activityLogs와 갈릴 수 있음).
    public func fetchActivityCount() async throws -> Int {
        let profile = try await memberProfileRepository.fetchMyProfile(forceRefresh: false)
        return profile.challengerRecords
            .filter { UMCPartType(apiValue: $0.part) != .admin }
            .count
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
