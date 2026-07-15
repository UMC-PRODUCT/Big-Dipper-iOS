//
//  FetchMemberProfileUseCase.swift
//  CoreDomain
//
//  Created by euijjang97 on 7/11/26.
//

/// 정본 내 프로필 조회 UseCase 구현체.
public struct FetchMemberProfileUseCase: FetchMemberProfileUseCaseProtocol {

    // MARK: - Property

    private let repository: MemberProfileRepositoryProtocol

    // MARK: - Init

    public init(repository: MemberProfileRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute() async throws -> Profile {
        try await repository.fetchMyProfile()
    }
}
