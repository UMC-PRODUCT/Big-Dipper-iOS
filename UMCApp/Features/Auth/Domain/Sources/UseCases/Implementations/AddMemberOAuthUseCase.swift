//
//  AddMemberOAuthUseCase.swift
//  AuthDomain
//
//  Created by euijjang97 on 8/10/26.
//

/// OAuth 수단 추가 연동 UseCase 구현체
public final class AddMemberOAuthUseCase: AddMemberOAuthUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRepositoryProtocol

    // MARK: - Init

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(oAuthVerificationToken: String) async throws -> [MemberOAuth] {
        try await repository.addMemberOAuth(oAuthVerificationToken: oAuthVerificationToken)
    }
}
