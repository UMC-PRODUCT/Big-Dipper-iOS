//
//  CommunityThreadRoomUseCase.swift
//  CommunityDomain
//

import Foundation
import UMCFoundation

public protocol CommunityThreadRoomUseCaseProtocol: Sendable {
    func loadThread(threadId: String) async throws -> CommunityThread
    func loadMessages(threadId: String, before: String?) async throws -> ThreadMessagePage
    func send(threadId: String, clientMessageId: String, content: String) async throws
    func markRead(threadId: String, lastReadMessageId: String) async throws
    func addReaction(threadId: String, messageId: String, emoji: String) async throws
    func removeReaction(threadId: String, messageId: String, emoji: String) async throws
    func deleteMessage(threadId: String, messageId: String) async throws
    func startRealtime() async
    func signals() async -> AsyncStream<CommunityRealtimeSignal>
}

public struct CommunityThreadRoomUseCase: CommunityThreadRoomUseCaseProtocol {

    // MARK: - Property

    public static let pageSize = 30
    /// 서버 TEXT 상한. **code point 기준**이라 `String.count`(그래파임)로 세면 안 된다.
    public static let messageMaxLength = 2_000
    /// 반응 이모지 상한. 서버가 code point 로 세므로 여기서도 같은 단위로 센다.
    public static let reactionEmojiMaxLength = 32

    private let repository: CommunityThreadRepositoryProtocol
    private let realtime: CommunityThreadRealtimeProtocol

    // MARK: - Init

    public init(
        repository: CommunityThreadRepositoryProtocol,
        realtime: CommunityThreadRealtimeProtocol
    ) {
        self.repository = repository
        self.realtime = realtime
    }

    // MARK: - Static Function

    /// 서버 TEXT 검증을 선반영한다. 왕복 한 번을 아끼고 실패 UX 를 즉시 준다.
    public static func validateText(_ content: String) throws {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.validation(.empty(field: "메시지"))
        }
        guard content.unicodeScalars.count <= messageMaxLength else {
            throw AppError.validation(.tooLong(field: "메시지", maxLength: messageMaxLength))
        }
    }

    /// 서버 이모지 검증을 선반영한다. 거절은 `/user/queue/errors` 로만 오는데 그 프레임에는
    /// 어떤 반응이 실패했는지가 없어, 여기서 막지 않으면 화면이 되돌릴 대상을 못 찾는다.
    public static func validateReactionEmoji(_ emoji: String) throws {
        guard !emoji.isEmpty else {
            throw AppError.validation(.empty(field: "이모지"))
        }
        guard emoji.unicodeScalars.count <= reactionEmojiMaxLength else {
            throw AppError.validation(
                .tooLong(field: "이모지", maxLength: reactionEmojiMaxLength)
            )
        }
        // 서버는 grapheme cluster 하나만 받는다. 공백은 `count == 1` 을 통과하므로 따로 막는다.
        guard emoji.count == 1,
              emoji.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            throw AppError.validation(
                .invalidValue(field: "이모지", reason: "이모지 하나만 보낼 수 있어요")
            )
        }
    }

    // MARK: - Function

    public func loadThread(threadId: String) async throws -> CommunityThread {
        try await repository.fetchThread(threadId: threadId)
    }

    public func loadMessages(threadId: String, before: String?) async throws -> ThreadMessagePage {
        try await repository.fetchMessages(
            threadId: threadId,
            before: before,
            limit: Self.pageSize
        )
    }

    public func send(threadId: String, clientMessageId: String, content: String) async throws {
        try Self.validateText(content)
        try await realtime.sendMessage(
            threadId: threadId,
            clientMessageId: clientMessageId,
            content: content,
            fileMetadataIds: []
        )
    }

    public func markRead(threadId: String, lastReadMessageId: String) async throws {
        try await realtime.updateReadWatermark(
            threadId: threadId,
            lastReadMessageId: lastReadMessageId
        )
    }

    public func addReaction(threadId: String, messageId: String, emoji: String) async throws {
        try Self.validateReactionEmoji(emoji)
        try await realtime.addReaction(threadId: threadId, messageId: messageId, emoji: emoji)
    }

    public func removeReaction(threadId: String, messageId: String, emoji: String) async throws {
        try Self.validateReactionEmoji(emoji)
        try await realtime.removeReaction(threadId: threadId, messageId: messageId, emoji: emoji)
    }

    public func deleteMessage(threadId: String, messageId: String) async throws {
        try await realtime.deleteMessage(threadId: threadId, messageId: messageId)
    }

    public func startRealtime() async {
        await realtime.start()
    }

    public func signals() async -> AsyncStream<CommunityRealtimeSignal> {
        await realtime.signals()
    }
}
