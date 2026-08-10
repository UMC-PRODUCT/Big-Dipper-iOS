//
//  DeleteMemberOAuthUseCase.swift
//  AuthDomain
//
//  Created by euijjang97 on 8/10/26.
//

/// OAuth 수단 연동 해제 UseCase 구현체
public final class DeleteMemberOAuthUseCase: DeleteMemberOAuthUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRepositoryProtocol

    // MARK: - Init

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(
        memberOAuthId: String,
        googleAccessToken: String?,
        kakaoAccessToken: String?
    ) async throws {
        try await repository.deleteMemberOAuth(
            memberOAuthId: memberOAuthId,
            googleAccessToken: googleAccessToken,
            kakaoAccessToken: kakaoAccessToken
        )
    }
}
