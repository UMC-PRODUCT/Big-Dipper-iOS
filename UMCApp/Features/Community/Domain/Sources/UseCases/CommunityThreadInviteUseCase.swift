//
//  CommunityThreadInviteUseCase.swift
//  CommunityDomain
//

import Foundation

/// 초대 시트가 한 번에 그려야 하는 값.
///
/// 후보와 정원은 서로 다른 엔드포인트에서 오지만 화면에서는 한 상태다 — 후보만 먼저 그리면
/// 정원이 도착하기 전에 고른 선택이 상한을 넘어 버린다.
public struct ThreadInviteCandidates: Equatable, Sendable {

    // MARK: - Property

    public let candidates: [ThreadMember]
    /// 정원까지 더 받을 수 있는 인원. `nil` 이면 서버 정원 값이 없어 상한을 두지 않는다.
    public let remainingSlots: Int?

    // MARK: - Init

    public init(candidates: [ThreadMember], remainingSlots: Int?) {
        self.candidates = candidates
        self.remainingSlots = remainingSlots
    }
}

/// 기존 스레드에 멤버를 추가 초대하는 계약.
///
/// 생성 시점 초대는 `POST /threads` 의 `memberIds` 가 함께 처리하므로(#1132) 여기 없다.
public protocol CommunityThreadInviteUseCaseProtocol: Sendable {

    /// 초대 후보와 남은 정원을 함께 읽는다.
    func loadCandidates(threadId: String) async throws -> ThreadInviteCandidates

    func invite(threadId: String, memberIds: [String]) async throws
}

public struct CommunityThreadInviteUseCase: CommunityThreadInviteUseCaseProtocol {

    // MARK: - Property

    private let repository: CommunityThreadRepositoryProtocol

    // MARK: - Init

    public init(repository: CommunityThreadRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    /// 후보와 스레드 상세를 병렬로 읽는다. 정원(`maxMembers`)·현재 인원은 스레드 상세에만 있고
    /// 후보 목록과 서로를 기다릴 이유가 없다.
    ///
    /// 이름순 정렬은 여기서 확정한다 — 서버 정렬 계약이 없어 화면마다 순서가 달라진다.
    public func loadCandidates(threadId: String) async throws -> ThreadInviteCandidates {
        async let candidateRequest = repository.fetchInvitableMembers(threadId: threadId)
        async let threadRequest = repository.fetchThread(threadId: threadId)
        let (candidates, thread) = try await (candidateRequest, threadRequest)

        return ThreadInviteCandidates(
            candidates: candidates.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            },
            remainingSlots: Self.remainingSlots(of: thread)
        )
    }

    public func invite(threadId: String, memberIds: [String]) async throws {
        // 빈 배열은 서버가 400 으로 거절한다. 버튼도 잠겨 있지만 왕복을 만들 이유가 없다.
        guard !memberIds.isEmpty else { return }
        try await repository.inviteMembers(threadId: threadId, memberIds: memberIds)
    }

    // MARK: - Static Function

    /// 남은 정원. 서버가 정수를 String 으로 주므로 이 계산 시점에만 Int 로 바꾼다.
    ///
    /// 정원이 없거나 0 이면 상한이 없는 것으로 본다 — 있지도 않은 상한으로 선택을 막으면
    /// 초대 경로 자체가 사라진다. 최종 판정은 어차피 서버가 한다.
    public static func remainingSlots(of thread: CommunityThread) -> Int? {
        guard let maxMembers = Int(thread.maxMembers), maxMembers > 0 else { return nil }
        return max(maxMembers - (Int(thread.memberCount) ?? 0), 0)
    }
}
