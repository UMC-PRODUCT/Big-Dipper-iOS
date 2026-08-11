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
    func startRealtime() async
    func signals() async -> AsyncStream<CommunityRealtimeSignal>
}

public struct CommunityThreadRoomUseCase: CommunityThreadRoomUseCaseProtocol {

    // MARK: - Property

    public static let pageSize = 30
    /// 서버 TEXT 상한. **code point 기준**이라 `String.count`(그래파임)로 세면 안 된다.
    public static let messageMaxLength = 2_000

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

    public func startRealtime() async {
        await realtime.start()
    }

    public func signals() async -> AsyncStream<CommunityRealtimeSignal> {
        await realtime.signals()
    }
}
