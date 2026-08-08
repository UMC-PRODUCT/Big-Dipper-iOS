//
//  AuthorizationUseCase.swift
//  CoreDomain
//
//  Created by euijjang97 on 8/8/26.
//

/// 공용 리소스 권한 UseCase 구현체
public struct AuthorizationUseCase: AuthorizationUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthorizationRepositoryProtocol

    // MARK: - Init

    public init(repository: AuthorizationRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func getResourcePermission(
        resourceType: AuthorizationResourceType,
        resourceId: String
    ) async throws -> ResourcePermission {
        try await repository.getResourcePermission(
            resourceType: resourceType,
            resourceId: resourceId
        )
    }
}
