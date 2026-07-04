//
//  UpdateMyPageProfileLinksUseCase.swift
//  MyPage
//
//  Created by 김동민 on 7/4/26.
//

import Foundation

/// 프로필 링크 변경 구현체
public final class UpdateMyPageProfileLinksUseCase: UpdateMyPageProfileLinksUseCaseProtocol {
    
    // MARK: - Property
    
    private let repository: MyPageRepositoryProtocol
    
    // MARK: - Function
    
    public init(repository: MyPageRepositoryProtocol) {
        self.repository = repository
    }
    
    public func execute(profileLinks: [ProfileLink]) async throws -> ProfileData {
        try await repository.updateProfileLinks(profileLinks)
    }
}
