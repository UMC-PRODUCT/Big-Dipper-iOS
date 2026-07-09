#if DEBUG
import AuthData
import AuthDomain
import CoreDI
import CoreNetwork

extension DIContainer {

    /// `SignUpByIdPwView` 디버그 진입점 전용 의존성 등록.
    ///
    /// 이메일(ID/PW) 가입 화면의 프로덕션 네비게이션 배선은 후속 이슈(Task 6)에서
    /// `DIContainer+Auth.swift`를 통해 이뤄진다. 그 전까지 QA/리뷰어가 이 화면을
    /// 확인할 수 있도록, 릴리스 빌드에서 완전히 제외되는 이 파일에서만 필요한
    /// UseCase를 추가로 등록한다 (`registerAuthDependencies()`는 건드리지 않는다).
    func registerSignUpByIdPwDebugDependencies() {
        guard resolveIfRegistered(AuthRegistrationRepositoryProtocol.self) == nil else { return }

        register(AuthRegistrationRepositoryProtocol.self) {
            AuthRepository(
                adapter: self.resolve(MoyaNetworkAdapter.self),
                networkClient: self.resolve(NetworkClient.self),
                tokenStore: self.resolve(TokenStore.self)
            )
        }
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
        register(RegisterByEmailUseCaseProtocol.self) {
            RegisterByEmailUseCase(
                repository: self.resolve(AuthRegistrationRepositoryProtocol.self)
            )
        }
    }
}
#endif
