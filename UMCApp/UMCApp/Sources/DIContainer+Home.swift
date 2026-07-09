import CoreDI
import CoreNetwork
import HomeData
import HomeDomain

extension DIContainer {
    func registerHomeDependencies() {
        register(HomeRepositoryProtocol.self) {
            HomeRepository(adapter: self.resolve(MoyaNetworkAdapter.self))
        }
        register(FetchMyProfileUseCaseProtocol.self) {
            FetchMyProfileUseCase(repository: self.resolve(HomeRepositoryProtocol.self))
        }
    }
}
