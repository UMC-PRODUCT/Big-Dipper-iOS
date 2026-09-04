//
//  ChangePasswordViewModel.swift
//  AuthPresentation
//
//  Created by euijjang97 on 8/10/26.
//

import AuthDomain
import CoreDI
import Foundation
import UMCFoundation

/// 비밀번호 변경 화면의 상태 및 액션을 관리하는 ViewModel.
///
/// 핵심규칙 #1에 따라 `@Observable`을 사용한다. 현재 비밀번호 불일치는 화면 안에서 다시
/// 입력해 해결할 수 있는 상태라 `EmailLoginViewModel`과 동일하게 인라인 메시지로 표시하고,
/// 그 밖의 실패(네트워크·세션 등)만 흐름 중단형으로 보고 `ErrorHandler`에 넘긴다.
@Observable
final class ChangePasswordViewModel {

    // MARK: - Constant

    private enum Constants {
        static let minimumPasswordLength: Int = 8
        static let changeFailedMessage: String = "비밀번호를 변경하지 못했습니다. 현재 비밀번호를 확인해 주세요."
        static let action: String = "changePassword"
    }

    // MARK: - Property

    private let changePasswordUseCase: ChangePasswordUseCaseProtocol
    private let errorHandler: ErrorHandler

    /// 현재 비밀번호 입력값
    var currentPassword: String = ""

    /// 새 비밀번호 입력값
    var newPassword: String = ""

    /// 비밀번호 변경 진행 상태
    private(set) var changePasswordState: Loadable<Bool> = .idle

    /// 변경 실패 인라인 메시지
    private(set) var changePasswordErrorMessage: String?

    // MARK: - Init

    init(container: DIContainer, errorHandler: ErrorHandler) {
        self.changePasswordUseCase = container.resolve(ChangePasswordUseCaseProtocol.self)
        self.errorHandler = errorHandler
    }

    // MARK: - Computed Property

    /// 새 비밀번호 최소 길이(8자) 충족 여부
    var isNewPasswordValid: Bool {
        newPassword.count >= Constants.minimumPasswordLength
    }

    /// 변경 제출 가능 여부 — 현재 비밀번호와 같은 값으로는 변경할 수 없다.
    var canSubmit: Bool {
        !currentPassword.isEmpty && isNewPasswordValid && newPassword != currentPassword
    }

    // MARK: - Function

    /// 비밀번호 변경 실행
    @MainActor
    func changePassword() async {
        guard !changePasswordState.isLoading, canSubmit else { return }

        changePasswordState = .loading
        changePasswordErrorMessage = nil

        do {
            try await changePasswordUseCase.execute(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            changePasswordState = .loaded(true)
        } catch let error as RepositoryError {
            handleChangeFailure(error)
        } catch let error as AppError {
            guard case .repository(let repositoryError) = error else {
                handleUnexpectedFailure(error)
                return
            }
            handleChangeFailure(repositoryError)
        } catch {
            handleUnexpectedFailure(error)
        }
    }

    // MARK: - Private Function

    /// 서버가 거절한 변경 요청을 인라인 메시지로 변환한다.
    @MainActor
    private func handleChangeFailure(_ error: RepositoryError) {
        if case .serverError(_, let message) = error, let message, !message.isEmpty {
            changePasswordErrorMessage = message
        } else {
            changePasswordErrorMessage = Constants.changeFailedMessage
        }
        changePasswordState = .failed(.repository(error))
    }

    @MainActor
    private func handleUnexpectedFailure(_ error: Error) {
        changePasswordState = .idle
        errorHandler.handle(error, context: ErrorContext(
            feature: "Auth",
            action: Constants.action,
            retryAction: { [weak self] in await self?.changePassword() }
        ))
    }
}
