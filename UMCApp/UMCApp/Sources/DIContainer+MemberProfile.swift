//
//  DIContainer+MemberProfile.swift
//  UMCApp
//
//  Created by euijjang97 on 7/10/26.
//

import CoreDI
import CoreDomain
import CoreNetwork

extension DIContainer {
    func registerMemberProfileDependencies() {
        register(MemberProfileRepositoryProtocol.self) {
            MemberProfileRepository(adapter: self.resolve(MoyaNetworkAdapter.self))
        }
        register(FetchMemberProfileUseCaseProtocol.self) {
            FetchMemberProfileUseCase(
                repository: self.resolve(MemberProfileRepositoryProtocol.self)
            )
        }
    }
}
