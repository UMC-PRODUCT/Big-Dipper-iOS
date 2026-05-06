//
//  FetchTermsUseCase.swift
//  MyPageData
//
//  Created by One on 5/6/26.
//

import Foundation

/// 마이페이지 이용약관 조회 UseCase 구현체
public final class FetchTermsUseCase: FetchTermsUseCaseProtocol {
    
    // MARK: - Property
    
    private let repository: MyPageRepositoryProtocol
    
    // MARK: - Init
    
    init(repository: MyPageRepositoryProtocol) {
        self.repository = repository
    }
    
    // MARK: - Function
    
    public func execute(termsType: String) async throws -> MyPageTerms {
        try await repository.fetchTerms(termsType: termsType)
    }
    
    
}
