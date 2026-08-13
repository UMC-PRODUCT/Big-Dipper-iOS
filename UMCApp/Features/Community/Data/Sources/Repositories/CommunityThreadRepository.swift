//
//  CommunityThreadRepository.swift
//  CommunityData
//

import Foundation
import CommunityDomain
import CoreNetwork
import UMCFoundation

/// `/api/v1/community` REST 구현체.
///
/// 모든 응답은 서버 공통 envelope(`success`/`code`/`message`/`result`)로 감싸여 오므로
/// `APIResponse<T>.unwrap()` 으로 벗긴 뒤 DTO 의 `toDomain` 에 넘긴다.
///
/// - Note: `MoyaNetworkAdapter` 가 아직 `Sendable` 을 채택하지 않아 프로토콜이 요구하는
///   `Sendable` 을 `@unchecked` 로 만족시킨다(`AuthRepository`·`MyPageRepository` 와 동일 패턴).
///   저장 프로퍼티가 불변 값 하나뿐이라 데이터 경쟁 위험은 없다.
public struct CommunityThreadRepository: CommunityThreadRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let networkRequesting: any CommunityThreadNetworkRequesting

    // MARK: - Init

    /// 운영(DI) 진입점.
    public init(adapter: MoyaNetworkAdapter) {
        self.init(networkRequesting: adapter)
    }

    /// 네트워크 추상화를 직접 주입하는 지정 이니셜라이저 (모듈 내부 · 테스트 전용).
    init(networkRequesting: any CommunityThreadNetworkRequesting) {
        self.networkRequesting = networkRequesting
    }

    // MARK: - Function

    public func fetchThreads(
        filter: String,
        query: String?,
        offset: Int,
        limit: Int
    ) async throws -> CommunityThreadPage {
        try await payload(
            CommunityThreadListDTO.self,
            from: .getThreads(
                query: ThreadListQuery(
                    filter: filter,
                    query: query,
                    offset: offset,
                    limit: clamped(limit)
                )
            )
        ).toDomain
    }

    public func fetchThread(threadId: String) async throws -> CommunityThread {
        try await payload(CommunityThreadDTO.self, from: .getThread(threadId: threadId)).toDomain
    }

    public func createThread(
        title: String,
        description: String,
        category: String,
        icon: String
    ) async throws -> CommunityThread {
        // 201 응답 본문이 상세와 같은 스키마라 `fetchThread` 와 같은 DTO 를 쓴다.
        try await payload(
            CommunityThreadDTO.self,
            from: .createThread(
                body: CreateThreadBody(
                    title: title,
                    description: description,
                    category: category,
                    icon: icon
                )
            )
        ).toDomain
    }

    /// 보낼 필드가 하나도 없으면 요청 자체를 생략하고 서버 재조회로 최신 상태만 돌려준다 —
    /// `{}` 를 보내면 `updatedAt` 만 흔들고 얻는 게 없다.
    public func updateThread(
        threadId: String,
        title: String?,
        description: String?,
        category: String?,
        icon: String?
    ) async throws -> CommunityThread {
        let body = UpdateThreadBody(
            title: title,
            description: description,
            category: category,
            icon: icon
        )
        guard !body.isEmpty else { return try await fetchThread(threadId: threadId) }

        // 200 응답 본문이 상세와 같은 스키마라 `fetchThread` 와 같은 DTO 를 쓴다.
        return try await payload(
            CommunityThreadDTO.self,
            from: .updateThread(threadId: threadId, body: body)
        ).toDomain
    }

    public func deleteThread(threadId: String) async throws {
        _ = try await payload(EmptyResult.self, from: .deleteThread(threadId: threadId))
    }

    public func fetchMessages(
        threadId: String,
        before: String?,
        limit: Int
    ) async throws -> ThreadMessagePage {
        // `hasMore` 는 서버 값을 그대로 쓴다. 깨진 원소는 버려질 수 있어 받은 개수로 추론하면 틀린다.
        try await payload(
            ThreadMessagePageDTO.self,
            from: .getMessages(
                threadId: threadId,
                query: ThreadMessageQuery(before: before, limit: clamped(limit))
            )
        ).toDomain
    }

    public func setPinned(threadId: String, isPinned: Bool) async throws {
        _ = try await payload(
            EmptyResult.self,
            from: .setPin(threadId: threadId, isPinned: isPinned)
        )
    }

    public func setMuted(threadId: String, isMuted: Bool) async throws {
        _ = try await payload(
            EmptyResult.self,
            from: .setMute(threadId: threadId, isMuted: isMuted)
        )
    }

    public func fetchMembers(threadId: String) async throws -> [ThreadMember] {
        try await payload(
            ThreadMemberListDTO.self,
            from: .getMembers(threadId: threadId)
        ).toDomain
    }

    public func kickMember(threadId: String, memberId: String) async throws {
        _ = try await payload(
            EmptyResult.self,
            from: .kickMember(threadId: threadId, memberId: memberId)
        )
    }

    public func changeMemberRole(
        threadId: String,
        memberId: String,
        role: String
    ) async throws {
        _ = try await payload(
            EmptyResult.self,
            from: .changeMemberRole(
                threadId: threadId,
                memberId: memberId,
                body: ThreadMemberRoleBody(role: role)
            )
        )
    }

    public func leaveThread(threadId: String) async throws {
        _ = try await payload(EmptyResult.self, from: .leave(threadId: threadId))
    }

    public func reportMessage(messageId: String, reason: String) async throws {
        _ = try await payload(
            EmptyResult.self,
            from: .reportMessage(
                messageId: messageId,
                body: ReportMessageBody(reason: reason)
            )
        )
    }

    // MARK: - Private Function

    /// 공통 envelope 을 벗겨 `result` 페이로드만 돌려준다.
    ///
    /// 토글·나가기처럼 `result` 가 없는 성공 응답은 `EmptyResult` 로 받으면 `unwrap()` 이 복구한다.
    private func payload<T: Codable>(
        _ type: T.Type,
        from target: CommunityThreadRouter
    ) async throws -> T {
        let response = try await networkRequesting.request(target)
        do {
            return try JSONDecoder().decode(APIResponse<T>.self, from: response.data).unwrap()
        } catch let decodingError as DecodingError {
            throw RepositoryError.decodingError(detail: "\(target.path): \(decodingError)")
        }
    }

    /// 서버 상한을 벗어난 page size 는 400 이라 전송 직전에 맞춘다.
    /// 검색어(`q`) 상한은 트리밍과 한 몸이라 `CommunityThreadListUseCase` 가 그대로 소유한다.
    private func clamped(_ limit: Int) -> Int {
        min(max(limit, Constants.limitRange.lowerBound), Constants.limitRange.upperBound)
    }
}

// MARK: - Constants

fileprivate enum Constants {
    /// `GET /threads`·`GET /messages` 가 받는 page size 범위.
    static let limitRange = 1...100
}
