//
//  FetchMyOAuthUseCase.swift
//  AuthDomain
//
//  Created by euijjang97 on 8/10/26.
//

/// 내 OAuth 연동 정보 조회 UseCase 구현체
public final class FetchMyOAuthUseCase: FetchMyOAuthUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRepositoryProtocol

    // MARK: - Init

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute() async throws -> [MemberOAuth] {
        try await repository.fetchMyOAuth()
    }
}
