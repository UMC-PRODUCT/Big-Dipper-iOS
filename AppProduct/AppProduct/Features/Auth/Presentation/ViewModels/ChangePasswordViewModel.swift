//
//  ChangePasswordViewModel.swift
//  AppProduct
//

import Foundation

@Observable
@MainActor
final class ChangePasswordViewModel {

    // MARK: - Property

    private let changePasswordUseCase: ChangePasswordUseCaseProtocol

    var currentPasswordInput: String = ""
    var newPasswordInput: String = ""

    private(set) var changePasswordState: Loadable<Bool> = .idle

    // MARK: - Init

    init(changePasswordUseCase: ChangePasswordUseCaseProtocol) {
        self.changePasswordUseCase = changePasswordUseCase
    }

    // MARK: - Validation

    var isNewPasswordValid: Bool {
        newPasswordInput.count >= 8
    }

    var canSubmit: Bool {
        !currentPasswordInput.isEmpty &&
        isNewPasswordValid &&
        newPasswordInput != currentPasswordInput
    }

    // MARK: - Function

    func changePassword() async {
        guard canSubmit else { return }
        changePasswordState = .loading
        do {
            try await changePasswordUseCase.execute(
                currentPassword: currentPasswordInput,
                newPassword: newPasswordInput
            )
            changePasswordState = .loaded(true)
        } catch let error as AppError {
            changePasswordState = .failed(error)
        } catch let error as AuthError {
            changePasswordState = .failed(.auth(error))
        } catch let error as RepositoryError {
            changePasswordState = .failed(.repository(error))
        } catch let error as NetworkError {
            changePasswordState = .failed(.network(error))
        } catch {
            changePasswordState = .failed(
                .unknown(message: error.localizedDescription)
            )
        }
    }
}
