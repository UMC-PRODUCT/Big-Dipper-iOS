//
//  BusinessCardRepositoryProtocol.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation

/// 내 명함 저장소 경계 (MP-F01·F02).
///
/// 구현은 정본 프로필 파이프라인(`MemberProfileRepositoryProtocol`) 위임 —
/// 편집 저장 후 primeCache 갱신이 그대로 전파돼 MP-F06이 성립한다.
public protocol BusinessCardRepositoryProtocol: Sendable {
    func fetchMyCard(forceRefresh: Bool) async throws -> MyCard
}
