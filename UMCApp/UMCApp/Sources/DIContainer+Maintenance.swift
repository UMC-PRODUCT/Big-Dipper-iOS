import CoreDI
import MaintenanceData
import MaintenanceDomain

extension DIContainer {
    func registerMaintenanceDependencies() {
        register(RemoteConfigServiceProtocol.self) {
            RemoteConfigService()
        }
        register(CheckMaintenanceUseCaseProtocol.self) {
            CheckMaintenanceUseCase(service: self.resolve(RemoteConfigServiceProtocol.self))
        }
        register(CheckForceUpdateUseCaseProtocol.self) {
            CheckForceUpdateUseCase(service: self.resolve(RemoteConfigServiceProtocol.self))
        }
    }
}
