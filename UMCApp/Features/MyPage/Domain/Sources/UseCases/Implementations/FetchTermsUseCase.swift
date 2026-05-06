//
//  FetchTermsUseCase.swift
//  MyPageData
//
//  Created by One on 5/6/26.
//

import Foundation

public final class FetchTermsUseCase: FetchTermsUseCaseProtocol {
    private let repository: MyPageRepositoryProtocol
    
    init(repository: MyPageRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(termsType: String) async throws -> MyPageTerms {
        try await repository.fetchTerms(termsType: termsType)
    }
    
    
}
