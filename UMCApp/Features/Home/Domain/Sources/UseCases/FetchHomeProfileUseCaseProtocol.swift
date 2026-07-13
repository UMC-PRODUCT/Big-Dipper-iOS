//
//  FetchHomeProfileUseCaseProtocol.swift
//  HomeDomain
//
//  Created by euijjang97 on 7/9/26.
//

/// 홈 화면 내 프로필 조회 UseCase 인터페이스
public protocol FetchHomeProfileUseCaseProtocol {
    /// - Returns: 시즌/세대 카드 구성에 필요한 내 프로필 정보
    func execute() async throws -> HomeProfileResult
}
