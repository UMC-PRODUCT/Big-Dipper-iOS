//
//  FetchMyPageProfileUseCase.swift
//  MyPageDomain
//
//  Created by Claude on 5/23/26.
//

import Foundation
import CoreDomain

/// 내 프로필 조회 UseCase 구현체
///
/// `MyPageRepositoryProtocol.fetchMyProfile()`에 그대로 위임합니다.
public final class FetchMyPageProfileUseCase: FetchMyPageProfileUseCaseProtocol {

    // MARK: - Property

    private let repository: MyPageRepositoryProtocol

    // MARK: - Init

    public init(repository: MyPageRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute() async throws -> ProfileData {
        try await repository.fetchMyProfile()
    }
}
