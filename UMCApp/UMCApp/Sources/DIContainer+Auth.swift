import AuthData
import AuthDomain
import CoreDI
import CoreDomain
import CoreNetwork

extension DIContainer {
    func registerAuthDependencies() {
        register(AuthRepositoryProtocol.self) {
            AuthRepository(
                adapter: self.resolve(MoyaNetworkAdapter.self),
                networkClient: self.resolve(NetworkClient.self),
                tokenStore: self.resolve(TokenStore.self)
            )
        }
        // `AuthRegistrationRepositoryProtocol`도 동일한 `AuthRepository` 구현체가 준수한다(ISP, Q7).
        register(AuthRegistrationRepositoryProtocol.self) {
            AuthRepository(
                adapter: self.resolve(MoyaNetworkAdapter.self),
                networkClient: self.resolve(NetworkClient.self),
                tokenStore: self.resolve(TokenStore.self)
            )
        }
        // Notice 등 여러 Feature가 공유하는 전역 역할 상태(#957 후속) — 싱글톤으로 등록한다.
        register(UserSessionManager.self) {
            UserSessionManager()
        }
        register(FetchMyProfileUseCaseProtocol.self) {
            FetchMyProfileUseCase(repository: self.resolve(AuthRepositoryProtocol.self))
        }
        register(SyncProfileStorageUseCaseProtocol.self) {
            SyncProfileStorageUseCase(userSessionManager: self.resolve(UserSessionManager.self))
        }
        register(CheckAuthStatusUseCaseProtocol.self) {
            CheckAuthStatusUseCase(
                repository: self.resolve(AuthRepositoryProtocol.self),
                fetchMyProfileUseCase: self.resolve(FetchMyProfileUseCaseProtocol.self),
                syncProfileStorageUseCase: self.resolve(SyncProfileStorageUseCaseProtocol.self)
            )
        }
        register(LoginUseCaseProtocol.self) {
            LoginUseCase(repository: self.resolve(AuthRepositoryProtocol.self))
        }

        // MARK: - 회원가입(SignUp) 관련 UseCase (#944)

        register(FetchSignUpDataUseCaseProtocol.self) {
            FetchSignUpDataUseCase(
                repository: self.resolve(AuthRegistrationRepositoryProtocol.self)
            )
        }
        register(SendEmailVerificationUseCaseProtocol.self) {
            SendEmailVerificationUseCase(
                repository: self.resolve(AuthRegistrationRepositoryProtocol.self)
            )
        }
        register(VerifyEmailCodeUseCaseProtocol.self) {
            VerifyEmailCodeUseCase(
                repository: self.resolve(AuthRegistrationRepositoryProtocol.self)
            )
        }
        register(ResendEmailVerificationUseCaseProtocol.self) {
            ResendEmailVerificationUseCase(
                repository: self.resolve(AuthRegistrationRepositoryProtocol.self)
            )
        }
        register(CheckEmailAvailabilityUseCaseProtocol.self) {
            CheckEmailAvailabilityUseCase(
                repository: self.resolve(AuthRegistrationRepositoryProtocol.self)
            )
        }
        register(RegisterUseCaseProtocol.self) {
            RegisterUseCase(
                repository: self.resolve(AuthRegistrationRepositoryProtocol.self)
            )
        }
        register(RegisterByEmailUseCaseProtocol.self) {
            RegisterByEmailUseCase(
                repository: self.resolve(AuthRegistrationRepositoryProtocol.self)
            )
        }
        register(RegisterCredentialUseCaseProtocol.self) {
            RegisterCredentialUseCase(
                repository: self.resolve(AuthRegistrationRepositoryProtocol.self)
            )
        }
        register(RegisterExistingChallengerUseCaseProtocol.self) {
            RegisterExistingChallengerUseCase(
                repository: self.resolve(AuthRegistrationRepositoryProtocol.self)
            )
        }

        // MARK: - 비밀번호 재설정(ResetPassword) 관련 UseCase (#947)

        register(ResetPasswordUseCaseProtocol.self) {
            ResetPasswordUseCase(
                repository: self.resolve(AuthRegistrationRepositoryProtocol.self)
            )
        }
    }
}
