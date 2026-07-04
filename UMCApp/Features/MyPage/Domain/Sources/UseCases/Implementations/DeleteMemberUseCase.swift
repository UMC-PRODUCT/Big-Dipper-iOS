//
//  DeleteMemberUseCase.swift
//  MyPage
//
//  Created by 김동민 on 7/4/26.
//

import Foundation

public final class DeleteMemberUseCase: DeleteMemberUseCaseProtocol {
    private let repository: MyPageRepositoryProtocol
    
    public init(repository: MyPageRepositoryProtocol) {
        self.repository = repository
    }
    
    public func execute() async throws {
        try await repository.deleteMember()
    }
}
