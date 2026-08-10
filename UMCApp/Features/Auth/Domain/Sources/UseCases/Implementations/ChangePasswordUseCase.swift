//
//  ChangePasswordUseCase.swift
//  AuthDomain
//
//  Created by euijjang97 on 8/10/26.
//

/// 비밀번호 변경 UseCase 구현체
public final class ChangePasswordUseCase: ChangePasswordUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRepositoryProtocol

    // MARK: - Init

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(currentPassword: String, newPassword: String) async throws {
        try await repository.changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword
        )
    }
}
