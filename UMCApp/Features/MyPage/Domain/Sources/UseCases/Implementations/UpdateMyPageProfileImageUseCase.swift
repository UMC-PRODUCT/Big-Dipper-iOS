//
//  UpdateMyPageProfileImageUseCase.swift
//  MyPage
//
//  Created by 김동민 on 7/4/26.
//

import Foundation

/// 프로필 이미지 변경 UseCase 구현체
public final class UpdateMyPageProfileImageUseCase: UpdateMyPageProfileImageUseCaseProtocol {
    
    // MARK: - Property
    
    private let repository: MyPageRepositoryProtocol
    
    // MARK: - Function
    
    public init(repository: MyPageRepositoryProtocol) {
        self.repository = repository
    }
    
    public func execute(
        imageData: Data,
        fileName: String,
        contentType: String
    ) async throws -> ProfileData {
        try await repository.updateProfileImage(
            imageData: imageData,
            fileName: fileName,
            contentType: contentType
        )
    }
}
