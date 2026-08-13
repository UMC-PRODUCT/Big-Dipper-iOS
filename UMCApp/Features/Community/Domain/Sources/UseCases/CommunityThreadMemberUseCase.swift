//
//  CommunityThreadMemberUseCase.swift
//  CommunityDomain
//

import Foundation

/// 참여자 목록 화면이 쓰는 멤버 관리 계약.
///
/// 나가기는 리스트 화면(``CommunityThreadListUseCaseProtocol/leave(threadId:)``)에도 있지만
/// 같은 REST 호출을 각 화면이 자기 UseCase 로 부르는 게 이 모듈의 기존 구성이라
/// (`loadThread` 도 리스트·채팅방이 각자 가진다) 여기서도 그대로 노출한다.
public protocol CommunityThreadMemberUseCaseProtocol: Sendable {
    func loadMembers(threadId: String) async throws -> [ThreadMember]
    func kick(threadId: String, memberId: String) async throws

    /// 개설자 위임. 서버가 소유권을 원자적으로 스왑하므로 호출 뒤에는 목록을 다시 읽어야
    /// 두 행(새 개설자·나)의 역할이 함께 맞는다.
    func transferOwnership(threadId: String, to memberId: String) async throws

    func leave(threadId: String) async throws
}

public struct CommunityThreadMemberUseCase: CommunityThreadMemberUseCaseProtocol {

    // MARK: - Property

    private let repository: CommunityThreadRepositoryProtocol

    // MARK: - Init

    public init(repository: CommunityThreadRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    /// 개설자를 맨 위로 올린다. 서버 정렬 계약이 없어 순서를 여기서 확정하지 않으면
    /// 위임 전후로 목록이 뒤바뀐 것처럼 보인다.
    public func loadMembers(threadId: String) async throws -> [ThreadMember] {
        try await repository.fetchMembers(threadId: threadId).sorted { lhs, rhs in
            guard (lhs.role == .owner) == (rhs.role == .owner) else { return lhs.role == .owner }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    public func kick(threadId: String, memberId: String) async throws {
        try await repository.kickMember(threadId: threadId, memberId: memberId)
    }

    public func transferOwnership(threadId: String, to memberId: String) async throws {
        try await repository.changeMemberRole(
            threadId: threadId,
            memberId: memberId,
            role: ThreadMemberRole.owner.rawValue
        )
    }

    public func leave(threadId: String) async throws {
        try await repository.leaveThread(threadId: threadId)
    }
}
