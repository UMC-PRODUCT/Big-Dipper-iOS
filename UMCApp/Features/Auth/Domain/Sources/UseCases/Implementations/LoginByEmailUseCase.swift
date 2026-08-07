//
//  LoginByEmailUseCase.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/31/26.
//

/// 이메일(ID/PW) 로그인 UseCase 구현체
///
/// 토큰 저장은 Repository(Data 레이어)가 내부적으로 처리하므로, 이 UseCase는
/// Repository 결과를 그대로 전달하는 얇은 통과(pass-through) 계층이다.
public final class LoginByEmailUseCase: LoginByEmailUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRepositoryProtocol

    // MARK: - Init

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(email: String, password: String) async throws -> LoginByIdPwResult {
        try await repository.loginByEmail(email: email, password: password)
    }
}
