//
//  CommunityThreadRepositoryProtocol.swift
//  CommunityDomain
//

import Foundation

/// `/api/v1/community` REST 계약.
///
/// 메시지 생성·수정·삭제·리액션·읽음은 **REST 에 없다**(STOMP 전용). 여기 없는 게 정상이다.
public protocol CommunityThreadRepositoryProtocol: Sendable {

    /// - Parameters:
    ///   - filter: `all` / `unread` / 카테고리 rawValue
    ///   - query: 제목·설명 부분 일치 검색어. 최대 80 code point. `nil` 이면 검색하지 않는다.
    ///   - offset: 0부터 시작하는 오프셋
    ///   - limit: 1~100, 기본 20
    /// - Returns: `query` 가 있으면 `pinned` 는 항상 비어 있다.
    func fetchThreads(
        filter: String,
        query: String?,
        offset: Int,
        limit: Int
    ) async throws -> CommunityThreadPage

    func fetchThread(threadId: String) async throws -> CommunityThread

    /// `POST /threads`. 개설자는 서버가 자동으로 `OWNER` 로 넣는다.
    ///
    /// - Parameters:
    ///   - category: ``CommunityThreadCategory`` 의 rawValue
    ///   - icon: grapheme cluster 하나. 서버가 `@SingleGrapheme` 으로 막는다.
    /// - Returns: 생성된 스레드 상세. 리스트에 그대로 꽂을 수 있다.
    func createThread(
        title: String,
        description: String,
        category: String,
        icon: String
    ) async throws -> CommunityThread

    /// - Parameter before: **배타적** 커서. `nil` 이면 최신부터.
    /// - Returns: 서버가 최신순으로 주므로 표시 직전에 뒤집어야 한다.
    func fetchMessages(
        threadId: String,
        before: String?,
        limit: Int
    ) async throws -> ThreadMessagePage

    func setPinned(threadId: String, isPinned: Bool) async throws
    func setMuted(threadId: String, isMuted: Bool) async throws
    func leaveThread(threadId: String) async throws
}
