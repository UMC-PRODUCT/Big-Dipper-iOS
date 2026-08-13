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

    /// `PATCH /threads/{threadId}` — **부분 수정**.
    ///
    /// `nil` 인 파라미터는 본문에서 키째로 빠져 서버가 건드리지 않는다. 즉 특징만 바꾸면
    /// 카테고리는 그대로 남는다(자동 재분류 없음).
    ///
    /// 호출은 `OWNER`/`ADMIN` 만 가능하다 — 위반 시 403 `COMMUNITY-0040`.
    ///
    /// - Returns: 갱신된 스레드 상세.
    func updateThread(
        threadId: String,
        title: String?,
        description: String?,
        category: String?,
        icon: String?
    ) async throws -> CommunityThread

    /// `DELETE /threads/{threadId}`.
    ///
    /// `OWNER`/`ADMIN` 만 가능하고 되돌릴 수 없다 — 호출 전에 반드시 확인을 받는다.
    func deleteThread(threadId: String) async throws

    /// - Parameter before: **배타적** 커서. `nil` 이면 최신부터.
    /// - Returns: 서버가 최신순으로 주므로 표시 직전에 뒤집어야 한다.
    func fetchMessages(
        threadId: String,
        before: String?,
        limit: Int
    ) async throws -> ThreadMessagePage

    func setPinned(threadId: String, isPinned: Bool) async throws
    func setMuted(threadId: String, isMuted: Bool) async throws

    /// `GET /threads/{threadId}/members`.
    ///
    /// 참여자 목록·초대(#1136)·`@`멘션 자동완성(#1140)이 함께 쓰는 진입점이다.
    func fetchMembers(threadId: String) async throws -> [ThreadMember]

    /// `GET /threads/{threadId}/invitable`.
    ///
    /// 서버가 이미 참여 중인 멤버를 걸러낸 **동아리 전체** 후보를 내려준다 (#1131 결정 3).
    /// 범위 필터 파라미터는 없다 — 클라이언트가 권한 스코프를 계산하지 않는다.
    func fetchInvitableMembers(threadId: String) async throws -> [ThreadMember]

    /// `POST /threads/{threadId}/invite`.
    ///
    /// `OWNER`/`ADMIN` 만 호출할 수 있다. 빈 배열은 400 이고 한 번에 최대 99명, 중복은 거절된다.
    func inviteMembers(threadId: String, memberIds: [String]) async throws

    /// `DELETE /threads/{threadId}/members/{memberId}`.
    ///
    /// `OWNER`/`ADMIN` 만 호출할 수 있고 `OWNER` 는 대상이 될 수 없다(409 `COMMUNITY-0042`).
    func kickMember(threadId: String, memberId: String) async throws

    /// `PATCH /threads/{threadId}/members/{memberId}/role`.
    ///
    /// `OWNER` 를 넘기면 서버가 소유권을 **원자적으로 스왑**한다 — 대상이 `OWNER` 가 되고
    /// 호출자는 `ADMIN` 으로 내려온다. 호출은 `OWNER` 만 가능하다.
    ///
    /// - Parameter role: ``ThreadMemberRole`` 의 rawValue
    func changeMemberRole(threadId: String, memberId: String, role: String) async throws

    /// `POST /threads/{threadId}/leave`.
    ///
    /// `OWNER` 는 거절된다(409 `COMMUNITY-0041`) — 소유권 이전이 선행돼야 한다.
    func leaveThread(threadId: String) async throws

    /// `POST /messages/{messageId}/report`.
    ///
    /// 경로가 `/threads/...` 하위가 아니라 `threadId` 를 받지 않는다 — messageId 하나로 신고한다.
    ///
    /// - Parameter reason: ``ThreadMessageReportReason`` 의 rawValue
    func reportMessage(messageId: String, reason: String) async throws
}
