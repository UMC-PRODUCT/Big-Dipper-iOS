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
import SwiftData
import UMCFoundation

extension DIContainer {
    /// `ModelContext` 는 ``DIContainer/configured(modelContext:)`` 가 등록한 공유 인프라이므로
    /// `MoyaNetworkAdapter` 와 같이 `resolve` 로만 재사용한다.
    func registerNoticeDependencies() {
        register(StorageRepositoryProtocol.self) {
            StorageRepository(adapter: self.resolve(MoyaNetworkAdapter.self))
        }
        register(NoticeRepositoryProtocol.self) {
            NoticeRepository(adapter: self.resolve(MoyaNetworkAdapter.self))
        }
        register(NoticeReadRepositoryProtocol.self) {
            NoticeReadRepository(modelContext: self.resolve(ModelContext.self))
        }
        register(NoticeUseCaseProtocol.self) {
            NoticeUseCase(
                repository: self.resolve(NoticeRepositoryProtocol.self),
                storageRepository: self.resolve(StorageRepositoryProtocol.self)
            )
        }
        register(NoticeEditorTargetRepositoryProtocol.self) {
            NoticeEditorTargetRepository(adapter: self.resolve(MoyaNetworkAdapter.self))
        }
        register(NoticeEditorTargetUseCaseProtocol.self) {
            NoticeEditorTargetUseCase(
                repository: self.resolve(NoticeEditorTargetRepositoryProtocol.self)
            )
        }
    }
}
