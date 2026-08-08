//
//  DIContainer+Authorization.swift
//  UMCApp
//
//  Created by euijjang97 on 8/8/26.
//

import CoreDI
import CoreDomain
import CoreNetwork

extension DIContainer {
    /// 공용 리소스 권한 조회 파이프라인을 등록한다.
    ///
    /// 권한 판정은 Notice·Activity 등 여러 Feature가 공유하므로 Feature DI가 아닌 공용 등록으로 둔다.
    func registerAuthorizationDependencies() {
        register(AuthorizationRepositoryProtocol.self) {
            AuthorizationRepository(adapter: self.resolve(MoyaNetworkAdapter.self))
        }
        register(AuthorizationUseCaseProtocol.self) {
            AuthorizationUseCase(
                repository: self.resolve(AuthorizationRepositoryProtocol.self)
            )
        }
    }
}
