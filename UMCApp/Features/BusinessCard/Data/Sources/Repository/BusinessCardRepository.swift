//
//  BusinessCardRepository.swift
//  BusinessCardData
//
//  Created by One on 8/16/26.
//

import Foundation
import CoreDomain
import BusinessCardDomain

/// 내 명함 저장소 (MP-F01·F02) — 자체 네트워킹 없음.
///
/// 정본 프로필 파이프라인(`CachedMemberProfileRepository`)에 위임만 한다. 명함이 별도
/// 조회를 하면 편집 직후 프로필과 어긋난다. 편집 저장 → primeCache → 여기서 재조회 시
/// 최신 스냅샷이 오므로 MP-F06(캐시 무효화 즉시 갱신)이 추가 코드 없이 성립한다.
public final class BusinessCardRepository: BusinessCardRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let memberProfileRepository: MemberProfileRepositoryProtocol

    // MARK: - Init

    public init(memberProfileRepository: MemberProfileRepositoryProtocol) {
        self.memberProfileRepository = memberProfileRepository
    }

    // MARK: - Function

    public func fetchMyCard(forceRefresh: Bool) async throws -> MyCard {
        try await memberProfileRepository.fetchMyProfile(forceRefresh: forceRefresh).toMyCard()
    }
}
