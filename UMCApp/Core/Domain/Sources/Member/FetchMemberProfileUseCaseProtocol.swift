//
//  FetchMemberProfileUseCaseProtocol.swift
//  CoreDomain
//
//  Created by euijjang97 on 7/11/26.
//

/// 정본 내 프로필 조회 UseCase 인터페이스.
public protocol FetchMemberProfileUseCaseProtocol: Sendable {

    /// - Returns: 내 프로필 정보
    func execute() async throws -> Profile
}
