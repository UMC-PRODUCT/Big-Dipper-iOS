//
//  DeleteMemberUseCase.swift
//  MyPage
//
//  Created by 김동민 on 7/4/26.
//

import Foundation

/// 회원 탈퇴 UseCase 구현체
public final class DeleteMemberUseCase: DeleteMemberUseCaseProtocol {
    
    // MARK: - Property
    
    private let repository: MyPageRepositoryProtocol
    
    // MARK: - Function
    
    public init(repository: MyPageRepositoryProtocol) {
        self.repository = repository
    }
    
    public func execute() async throws {
        try await repository.deleteMember()
    }
}
