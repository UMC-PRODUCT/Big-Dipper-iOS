import CoreDI
import CoreDomain
import CoreNetwork
import HomeData
import HomeDomain

extension DIContainer {
    func registerHomeDependencies() {
        register(HomeRepositoryProtocol.self) {
            HomeRepository(
                adapter: self.resolve(MoyaNetworkAdapter.self),
                memberProfileRepository: self.resolve(MemberProfileRepositoryProtocol.self)
            )
        }
        register(FetchHomeProfileUseCaseProtocol.self) {
            FetchHomeProfileUseCase(repository: self.resolve(HomeRepositoryProtocol.self))
        }
    }
}
