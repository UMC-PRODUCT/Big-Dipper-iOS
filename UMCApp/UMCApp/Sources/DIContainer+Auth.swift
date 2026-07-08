import AuthData
import AuthDomain
import CoreDI
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
        register(FetchMyProfileUseCaseProtocol.self) {
            FetchMyProfileUseCase(repository: self.resolve(AuthRepositoryProtocol.self))
        }
        register(CheckAuthStatusUseCaseProtocol.self) {
            CheckAuthStatusUseCase(
                repository: self.resolve(AuthRepositoryProtocol.self),
                fetchMyProfileUseCase: self.resolve(FetchMyProfileUseCaseProtocol.self)
            )
        }
        register(LoginUseCaseProtocol.self) {
            LoginUseCase(repository: self.resolve(AuthRepositoryProtocol.self))
        }
    }
}
