//
//  DIContainer+Notice.swift
//  CoreDI
//
//  Created by 이예지 on 5/30/26.
//

import CoreDI
import CoreNetwork
import NoticeDomain
import NoticeData
import UMCFoundation

extension DIContainer {
    func registerNoticeDependencies() {
        register(StorageRepositoryProtocol.self) {
            StorageRepository(adapter: self.resolve(MoyaNetworkAdapter.self))
        }
        register(NoticeRepositoryProtocol.self) {
            NoticeRepository(adapter: self.resolve(MoyaNetworkAdapter.self))
        }
        register(NoticeUseCaseProtocol.self) {
            NoticeUseCase(
                repository: self.resolve(NoticeRepositoryProtocol.self),
                storageRepository: self.resolve(StorageRepositoryProtocol.self)
            )
        }
    }
}
