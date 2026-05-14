//
//  LoginByIdPwViewModel.swift
//  AppProduct
//
//  Created by euijjang97 on 5/14/26.
//

import Foundation

/// ID/PW 로그인 화면의 상태 및 액션을 관리하는 ViewModel
@Observable
final class LoginByIdPwViewModel {

    // MARK: - Property

    private let loginByIdPwUseCase: LoginByIdPwUseCaseProtocol
    private let fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol
    private let tokenStore: TokenStore
    private let errorHandler: ErrorHandler

    /// ID/PW 로그인 진행 상태
    private(set) var loginByIdPwState: Loadable<LoginByIdPwResult> = .idle
    /// 인라인 에러 메시지 (도메인/유효성 오류)
    private(set) var loginByIdPwErrorMessage: String?
    /// 아이디 필드 유효성 가이드 메시지
    private(set) var loginIdGuideMessage: String?
    /// 비밀번호 필드 유효성 가이드 메시지
    private(set) var passwordGuideMessage: String?
    /// 로그인 완료 후 이동할 목적지
    private(set) var destination: IdPwLoginDestination?

    /// 로그인 ID 입력값
    var loginIdInput: String = ""
    /// 비밀번호 입력값
    var passwordInput: String = ""
    /// 자동로그인 활성화 여부
    var isAutoLoginEnabled: Bool = false

    // MARK: - Init

    init(
        loginByIdPwUseCase: LoginByIdPwUseCaseProtocol,
        fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol,
        tokenStore: TokenStore,
        errorHandler: ErrorHandler
    ) {
        self.loginByIdPwUseCase = loginByIdPwUseCase
        self.fetchMyProfileUseCase = fetchMyProfileUseCase
        self.tokenStore = tokenStore
        self.errorHandler = errorHandler
    }

    // MARK: - Function

    func clearLoginIdGuide() {
        loginIdGuideMessage = nil
    }

    func clearPasswordGuide() {
        passwordGuideMessage = nil
    }

    /// ID/PW 로그인 실행
    @MainActor
    func loginWithIdPw() async {
        let trimmedId = loginIdInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPw = passwordInput

        loginIdGuideMessage = trimmedId.isEmpty ? "아이디를 입력해 주세요." : nil
        passwordGuideMessage = trimmedPw.isEmpty ? "비밀번호를 입력해 주세요." : nil

        guard !trimmedId.isEmpty, !trimmedPw.isEmpty else {
            return
        }

        loginByIdPwState = .loading
        loginByIdPwErrorMessage = nil
        loginIdGuideMessage = nil
        passwordGuideMessage = nil
        destination = nil

        do {
            let result = try await loginByIdPwUseCase.execute(
                loginId: trimmedId,
                password: trimmedPw
            )
            try await ensureTokensStored(result.tokenPair)
            loginByIdPwState = .loaded(result)

            let profile = try await fetchMyProfileUseCase.execute()
            let isApproved = isApprovedProfile(profile)

            // 자동로그인은 승인된 계정 AND 사용자가 체크박스를 선택한 경우에만 저장
            UserDefaults.standard.set(
                isApproved && isAutoLoginEnabled,
                forKey: AppStorageKey.canAutoLogin
            )
            destination = isApproved ? .main : .pendingApproval
        } catch let error as RepositoryError {
            handleIdPwError(error)
        } catch let error as AppError {
            switch error {
            case .repository(let repositoryError):
                handleIdPwError(repositoryError)
            default:
                loginByIdPwState = .idle
                errorHandler.handle(error, context: .init(
                    feature: "Auth",
                    action: "loginWithIdPw",
                    retryAction: { [weak self] in
                        await self?.loginWithIdPw()
                    }
                ))
            }
        } catch {
            loginByIdPwState = .idle
            errorHandler.handle(error, context: .init(
                feature: "Auth",
                action: "loginWithIdPw",
                retryAction: { [weak self] in
                    await self?.loginWithIdPw()
                }
            ))
        }
    }
}

// MARK: - Private

private extension LoginByIdPwViewModel {
    /// ID/PW 로그인 도메인 에러를 인라인 메시지로 변환합니다.
    @MainActor
    func handleIdPwError(_ error: RepositoryError) {
        if case .serverError(_, let message) = error,
           let message,
           !message.isEmpty {
            loginByIdPwErrorMessage = message
        } else {
            loginByIdPwErrorMessage = "아이디 또는 비밀번호가 올바르지 않습니다."
        }
        loginByIdPwState = .failed(.repository(error))
    }

    func ensureTokensStored(_ tokenPair: TokenPair) async throws {
        let accessToken = tokenPair.accessToken.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let refreshToken = tokenPair.refreshToken.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !accessToken.isEmpty, !refreshToken.isEmpty else { return }

        let savedAccessToken = await tokenStore.getAccessToken()
        let savedRefreshToken = await tokenStore.getRefreshToken()

        guard savedAccessToken != accessToken || savedRefreshToken != refreshToken else {
            return
        }

        try await tokenStore.save(accessToken: accessToken, refreshToken: refreshToken)
    }

    func isApprovedProfile(_ profile: HomeProfileResult) -> Bool {
        if !profile.generations.isEmpty { return true }
        for seasonType in profile.seasonTypes {
            if case .gens(let generations) = seasonType, !generations.isEmpty {
                return true
            }
        }
        return false
    }
}

// MARK: - IdPwLoginDestination

/// ID/PW 로그인 완료 후 이동할 화면 목적지
enum IdPwLoginDestination: Equatable {
    case main
    case pendingApproval
}
