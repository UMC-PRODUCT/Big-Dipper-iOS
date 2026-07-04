//
//  AddChallengerRecordUseCase.swift
//  MyPage
//
//  Created by 김동민 on 7/4/26.
//

import Foundation

/// 챌린저 기록 추가 UseCase 구현체
public final class AddChallengerRecordUseCase: AddChallengerRecordUseCaseProtocol {
    
    // MARK: - Property
    
    private let repository: MyPageRepositoryProtocol
    
    // MARK: - Function
    
    public init(repository: MyPageRepositoryProtocol) {
        self.repository = repository
    }
    
    public func execute(code: String) async throws {
        try await repository.addChallengerRecord(code: code)
    }
}
