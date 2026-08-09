//
//  DIContainer+Maintenance.swift
//  UMCApp
//
//  Created by euijjang97 on 7/10/26.
//

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
        register(AppStoreVersionServiceProtocol.self) {
            AppStoreVersionService()
        }
        register(CheckForceUpdateUseCaseProtocol.self) {
            CheckForceUpdateUseCase(
                service: self.resolve(RemoteConfigServiceProtocol.self),
                appStoreVersionService: self.resolve(AppStoreVersionServiceProtocol.self)
            )
        }
    }
}
