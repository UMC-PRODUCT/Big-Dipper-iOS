//
//  RegisterCredentialUseCase.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/9/26.
//

/// OAuth 회원의 이메일/비밀번호 로그인 수단 추가 등록 UseCase 구현체
public final class RegisterCredentialUseCase: RegisterCredentialUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRegistrationRepositoryProtocol

    // MARK: - Init

    public init(repository: AuthRegistrationRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(rawPassword: String) async throws {
        try await repository.registerCredential(rawPassword: rawPassword)
    }
}
