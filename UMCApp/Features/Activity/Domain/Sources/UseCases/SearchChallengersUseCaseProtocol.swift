//
//  SearchChallengersUseCaseProtocol.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 8/3/26.
//

import Foundation

/// 챌린저 검색 도메인 진입점
///
/// 스터디 그룹 생성·인원 추가 화면이 이름/닉네임 키워드로 챌린저를 찾을 때 사용합니다.
/// 커서 페이지네이션이라 첫 페이지는 `cursor` 를 `nil` 로 호출하고, 이후에는 직전 응답의
/// ``ChallengerSearchPage/nextCursor`` 를 그대로 넘깁니다.
///
/// - SeeAlso: ``SearchChallengersUseCase``, ``MemberRepositoryProtocol``
public protocol SearchChallengersUseCaseProtocol {

    /// 키워드로 챌린저를 검색합니다.
    ///
    /// - Parameters:
    ///   - keyword: 이름 또는 닉네임 통합 검색어. `nil` 이면 전체 검색.
    ///   - cursor: 이전 페이지의 마지막 챌린저 ID (첫 페이지는 `nil`)
    ///   - size: 한 페이지에 조회할 항목 수
    func execute(
        keyword: String?,
        cursor: Int?,
        size: Int
    ) async throws -> ChallengerSearchPage
}
