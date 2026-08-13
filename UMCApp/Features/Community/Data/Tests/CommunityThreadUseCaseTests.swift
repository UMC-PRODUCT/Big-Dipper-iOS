//
//  CommunityThreadUseCaseTests.swift
//  CommunityDataTests
//

import Foundation
import Testing
import UMCFoundation

import CommunityDomain

@Suite("커뮤니티 스레드 리스트 UseCase")
struct CommunityThreadListUseCaseTests {

    // MARK: - Load

    @Test("필터는 서버 쿼리 값으로, 페이지 크기는 UseCase 상수로 내려간다")
    func passesFilterQueryValueAndPageSize() async throws {
        let repository = FakeThreadRepository()
        let useCase = CommunityThreadListUseCase(repository: repository)

        _ = try await useCase.loadThreads(filter: .category(.study), query: nil, offset: 40)

        let call = try #require(await repository.fetchThreadsCalls.first)
        #expect(call.filter == "STUDY")
        #expect(call.offset == 40)
        #expect(call.limit == CommunityThreadListUseCase.pageSize)
    }

    @Test("검색어는 앞뒤 공백을 털어서 내려간다")
    func trimsQueryWhitespace() async throws {
        let repository = FakeThreadRepository()
        let useCase = CommunityThreadListUseCase(repository: repository)

        _ = try await useCase.loadThreads(filter: .all, query: "  iOS 스터디\n", offset: 0)

        let call = try #require(await repository.fetchThreadsCalls.first)
        #expect(call.query == "iOS 스터디")
    }

    @Test("공백뿐이거나 빈 검색어는 검색하지 않는다 — nil 로 내려간다")
    func dropsBlankQuery() async throws {
        let repository = FakeThreadRepository()
        let useCase = CommunityThreadListUseCase(repository: repository)

        _ = try await useCase.loadThreads(filter: .all, query: "   \n\t ", offset: 0)
        _ = try await useCase.loadThreads(filter: .all, query: "", offset: 0)
        _ = try await useCase.loadThreads(filter: .all, query: nil, offset: 0)

        let queries = await repository.fetchThreadsCalls.map(\.query)
        #expect(queries == [nil, nil, nil])
    }

    @Test("상한을 넘는 검색어는 80 code point 로 잘라 보낸다")
    func truncatesOverlongQuery() async throws {
        let repository = FakeThreadRepository()
        let useCase = CommunityThreadListUseCase(repository: repository)

        let query = String(repeating: "가", count: 100)
        _ = try await useCase.loadThreads(filter: .all, query: query, offset: 0)

        let call = try #require(await repository.fetchThreadsCalls.first)
        #expect(call.query?.unicodeScalars.count == CommunityThreadListUseCase.queryMaxLength)
        #expect(call.query == String(repeating: "가", count: 80))

        // 그래파임으로 자르면 code point 140개가 그대로 나가 서버가 400 을 준다.
        _ = try await useCase.loadThreads(
            filter: .all,
            query: String(repeating: "👨‍👩‍👧‍👦", count: 20),
            offset: 0
        )

        let emojiCall = try #require(await repository.fetchThreadsCalls.last)
        #expect(emojiCall.query?.unicodeScalars.count == CommunityThreadListUseCase.queryMaxLength)
    }

    @Test("페이지는 가공 없이 그대로 돌려준다")
    func returnsRepositoryPageUnchanged() async throws {
        let page = CommunityThreadPage(
            pinned: [makeThread(id: "pinned-thread")],
            threads: [makeThread(id: "thread-1"), makeThread(id: "thread-2")],
            nextOffset: "20",
            total: "42"
        )
        let repository = FakeThreadRepository(threadPage: page)
        let useCase = CommunityThreadListUseCase(repository: repository)

        let loaded = try await useCase.loadThreads(filter: .unread, query: nil, offset: 0)

        #expect(loaded == page)
    }

    @Test("Repository 에러는 삼키지 않고 그대로 올린다")
    func propagatesRepositoryError() async {
        let repository = FakeThreadRepository(error: FakeFailure())
        let useCase = CommunityThreadListUseCase(repository: repository)

        await #expect(throws: FakeFailure.self) {
            _ = try await useCase.loadThreads(filter: .all, query: nil, offset: 0)
        }
    }

    // MARK: - Toggle

    @Test("고정 토글은 켜기·끄기를 구분해 Repository 로 넘긴다")
    func forwardsPinToggle() async throws {
        let repository = FakeThreadRepository()
        let useCase = CommunityThreadListUseCase(repository: repository)

        try await useCase.togglePin(threadId: "thread-1", isPinned: true)
        try await useCase.togglePin(threadId: "thread-2", isPinned: false)

        let calls = await repository.pinCalls
        #expect(calls == [
            FakeThreadRepository.ToggleCall(threadId: "thread-1", isOn: true),
            FakeThreadRepository.ToggleCall(threadId: "thread-2", isOn: false),
        ])
        #expect(await repository.muteCalls.isEmpty)
    }

    @Test("알림 토글은 고정과 섞이지 않는다")
    func forwardsMuteToggle() async throws {
        let repository = FakeThreadRepository()
        let useCase = CommunityThreadListUseCase(repository: repository)

        try await useCase.toggleMute(threadId: "thread-1", isMuted: true)

        #expect(await repository.muteCalls == [
            FakeThreadRepository.ToggleCall(threadId: "thread-1", isOn: true),
        ])
        #expect(await repository.pinCalls.isEmpty)
    }

    @Test("나가기는 해당 스레드로 Repository 를 호출한다")
    func forwardsLeave() async throws {
        let repository = FakeThreadRepository()
        let useCase = CommunityThreadListUseCase(repository: repository)

        try await useCase.leave(threadId: "thread-9")

        #expect(await repository.leaveCalls == ["thread-9"])
    }
}

@Suite("커뮤니티 스레드 생성 UseCase")
struct CommunityThreadCreateUseCaseTests {

    @Test("제목·특징은 앞뒤 공백을 털고 카테고리는 rawValue 로 내려간다")
    func trimsAndSendsCategoryRawValue() async throws {
        let repository = FakeThreadRepository()
        let useCase = CommunityThreadCreateUseCase(repository: repository)

        _ = try await useCase.create(
            title: "  iOS 스터디\n",
            description: " 매주 화요일 8시 ",
            category: .study,
            icon: "📚"
        )

        let call = try #require(await repository.createThreadCalls.first)
        #expect(call.title == "iOS 스터디")
        #expect(call.description == "매주 화요일 8시")
        #expect(call.category == "STUDY")
        #expect(call.icon == "📚")
    }

    @Test("상한을 넘긴 제목·특징은 코드포인트 기준으로 잘라 보낸다")
    func clampsOverlongText() async throws {
        let repository = FakeThreadRepository()
        let useCase = CommunityThreadCreateUseCase(repository: repository)

        _ = try await useCase.create(
            title: String(repeating: "가", count: 100),
            description: String(repeating: "나", count: 600),
            category: .free,
            icon: "💬"
        )

        let call = try #require(await repository.createThreadCalls.first)
        #expect(call.title.unicodeScalars.count == CommunityThreadCreateRule.titleMaxLength)
        #expect(
            call.description.unicodeScalars.count == CommunityThreadCreateRule.descriptionMaxLength
        )
    }

    @Test("아이콘이 비었으면 카테고리 기본 이모지로 채운다 — 서버가 필수로 받는다")
    func fallsBackToCategoryIcon() async throws {
        let repository = FakeThreadRepository()
        let useCase = CommunityThreadCreateUseCase(repository: repository)

        _ = try await useCase.create(title: "질문방", description: "무엇이든", category: .qna, icon: "")

        let call = try #require(await repository.createThreadCalls.first)
        #expect(call.icon == CommunityThreadCategory.qna.defaultIcon)
    }

    @Test("여러 글자·이모지가 아닌 입력은 grapheme 하나로 줄이거나 기본값으로 떨어진다")
    func normalizesIconToSingleGrapheme() async throws {
        // 서버 @SingleGrapheme 는 두 글자 이상을 400 으로 막는다.
        let cases: [(input: String, expected: String)] = [
            ("📚🚀", "🚀"),
            ("👨‍👩‍👧", "👨‍👩‍👧"),
            ("❤️", "❤️"),
            ("a", CommunityThreadCategory.project.defaultIcon),
            ("7", CommunityThreadCategory.project.defaultIcon),
            ("스터디", CommunityThreadCategory.project.defaultIcon)
        ]

        for (input, expected) in cases {
            let repository = FakeThreadRepository()
            let useCase = CommunityThreadCreateUseCase(repository: repository)

            _ = try await useCase.create(
                title: "제목",
                description: "특징",
                category: .project,
                icon: input
            )

            let call = try #require(await repository.createThreadCalls.first)
            #expect(call.icon == expected, "입력 \(input)")
        }
    }
}

@Suite("커뮤니티 스레드 채팅방 UseCase")
struct CommunityThreadRoomUseCaseTests {

    // MARK: - Read

    @Test("스레드 상세는 REST 로 간다")
    func loadsThreadFromRepository() async throws {
        let repository = FakeThreadRepository(thread: makeThread(id: "thread-7"))
        let useCase = makeUseCase(repository: repository)

        let thread = try await useCase.loadThread(threadId: "thread-7")

        #expect(thread.id == "thread-7")
        #expect(await repository.fetchThreadCalls == ["thread-7"])
    }

    @Test("메시지 조회는 커서와 UseCase 페이지 크기를 함께 내려보낸다")
    func passesCursorAndPageSize() async throws {
        let page = ThreadMessagePage(
            messages: [makeMessage(id: "message-1")],
            hasMore: true,
            nextBefore: "message-1"
        )
        let repository = FakeThreadRepository(messagePage: page)
        let useCase = makeUseCase(repository: repository)

        let loaded = try await useCase.loadMessages(threadId: "thread-1", before: "message-9")

        let call = try #require(await repository.fetchMessagesCalls.first)
        #expect(call.threadId == "thread-1")
        #expect(call.before == "message-9")
        #expect(call.limit == CommunityThreadRoomUseCase.pageSize)
        #expect(loaded == page)
    }

    // MARK: - Send

    @Test("전송은 REST 가 아니라 실시간 채널로 간다 — clientMessageId 를 그대로 싣는다")
    func routesSendToRealtime() async throws {
        let repository = FakeThreadRepository()
        let realtime = FakeThreadRealtime()
        let useCase = makeUseCase(repository: repository, realtime: realtime)

        try await useCase.send(
            threadId: "thread-1",
            clientMessageId: "3f0a1b2c-0000-4000-8000-000000000000",
            content: "안녕하세요",
            replyToId: nil,
            mentionedMemberIds: []
        )

        #expect(await realtime.sendCalls == [
            FakeThreadRealtime.SendCall(
                threadId: "thread-1",
                clientMessageId: "3f0a1b2c-0000-4000-8000-000000000000",
                content: "안녕하세요",
                fileMetadataIds: [],
                replyToId: nil,
                mentionedMemberIds: []
            ),
        ])
    }

    @Test("답장 대상과 멘션 대상은 손대지 않고 실시간 채널로 넘어간다")
    func forwardsReplyAndMentions() async throws {
        let realtime = FakeThreadRealtime()
        let useCase = makeUseCase(realtime: realtime)

        try await useCase.send(
            threadId: "thread-1",
            clientMessageId: "client-1",
            content: "@김유엠 확인했습니다",
            replyToId: "42",
            mentionedMemberIds: ["7", "9"]
        )

        let call = try #require(await realtime.sendCalls.first)
        #expect(call.replyToId == "42")
        #expect(call.mentionedMemberIds == ["7", "9"])
    }

    @Test("검증에 걸린 본문은 실시간 채널에 닿기 전에 막힌다")
    func rejectsInvalidContentBeforeSending() async {
        let realtime = FakeThreadRealtime()
        let useCase = makeUseCase(realtime: realtime)

        await #expect(throws: AppError.validation(.empty(field: "메시지"))) {
            try await useCase.send(
                threadId: "thread-1",
                clientMessageId: "client-1",
                content: " ",
                replyToId: nil,
                mentionedMemberIds: []
            )
        }
        await #expect(
            throws: AppError.validation(.tooLong(field: "메시지", maxLength: 2_000))
        ) {
            try await useCase.send(
                threadId: "thread-1",
                clientMessageId: "client-1",
                content: String(repeating: "가", count: 2_001),
                replyToId: nil,
                mentionedMemberIds: []
            )
        }

        #expect(await realtime.sendCalls.isEmpty)
    }

    @Test("실시간 전송 실패는 그대로 올라온다")
    func propagatesRealtimeSendError() async {
        let realtime = FakeThreadRealtime(sendError: FakeFailure())
        let useCase = makeUseCase(realtime: realtime)

        await #expect(throws: FakeFailure.self) {
            try await useCase.send(
                threadId: "thread-1",
                clientMessageId: "client-1",
                content: "안녕하세요",
                replyToId: nil,
                mentionedMemberIds: []
            )
        }
    }

    // MARK: - Read Watermark

    @Test("읽음 갱신도 REST 가 아니라 실시간 채널로 간다")
    func routesReadWatermarkToRealtime() async throws {
        let repository = FakeThreadRepository()
        let realtime = FakeThreadRealtime()
        let useCase = makeUseCase(repository: repository, realtime: realtime)

        try await useCase.markRead(threadId: "thread-1", lastReadMessageId: "message-42")

        #expect(await realtime.readCalls == [
            FakeThreadRealtime.ReadCall(threadId: "thread-1", lastReadMessageId: "message-42"),
        ])
        #expect(await repository.fetchThreadCalls.isEmpty)
    }

    // MARK: - Reaction

    @Test("반응은 add/remove 를 구분해 실시간 채널로 내려보낸다")
    func routesReactionToRealtime() async throws {
        let realtime = FakeThreadRealtime()
        let useCase = makeUseCase(realtime: realtime)

        try await useCase.addReaction(threadId: "thread-1", messageId: "message-1", emoji: "👍")
        try await useCase.removeReaction(threadId: "thread-1", messageId: "message-1", emoji: "👍")

        #expect(await realtime.addReactionCalls == [
            FakeThreadRealtime.ReactionCall(
                threadId: "thread-1",
                messageId: "message-1",
                emoji: "👍"
            ),
        ])
        #expect(await realtime.removeReactionCalls == [
            FakeThreadRealtime.ReactionCall(
                threadId: "thread-1",
                messageId: "message-1",
                emoji: "👍"
            ),
        ])
    }

    @Test("여러 코드포인트로 이뤄진 이모지도 grapheme cluster 하나면 통과한다")
    func acceptsMultiScalarSingleClusterEmoji() async throws {
        let realtime = FakeThreadRealtime()
        let useCase = makeUseCase(realtime: realtime)

        try await useCase.addReaction(
            threadId: "thread-1",
            messageId: "message-1",
            emoji: "👨‍👩‍👧‍👦"
        )

        #expect(await realtime.addReactionCalls.count == 1)
    }

    @Test("빈 값·공백·이모지 여러 개는 실시간 채널에 닿기 전에 막힌다")
    func rejectsInvalidReactionEmoji() async {
        let realtime = FakeThreadRealtime()
        let useCase = makeUseCase(realtime: realtime)

        await #expect(throws: AppError.validation(.empty(field: "이모지"))) {
            try await useCase.addReaction(threadId: "thread-1", messageId: "m", emoji: "")
        }
        let invalid = AppError.validation(
            .invalidValue(field: "이모지", reason: "이모지 하나만 보낼 수 있어요")
        )
        await #expect(throws: invalid) {
            try await useCase.addReaction(threadId: "thread-1", messageId: "m", emoji: " ")
        }
        await #expect(throws: invalid) {
            try await useCase.addReaction(threadId: "thread-1", messageId: "m", emoji: "👍👍")
        }
        await #expect(throws: invalid) {
            try await useCase.removeReaction(threadId: "thread-1", messageId: "m", emoji: "👍 ")
        }

        #expect(await realtime.addReactionCalls.isEmpty)
        #expect(await realtime.removeReactionCalls.isEmpty)
    }

    // MARK: - Delete

    @Test("메시지 삭제도 실시간 채널로 간다 — REST 를 거치지 않는다")
    func routesDeleteToRealtime() async throws {
        let repository = FakeThreadRepository()
        let realtime = FakeThreadRealtime()
        let useCase = makeUseCase(repository: repository, realtime: realtime)

        try await useCase.deleteMessage(threadId: "thread-1", messageId: "message-42")

        #expect(await realtime.deleteCalls == [
            FakeThreadRealtime.DeleteCall(threadId: "thread-1", messageId: "message-42"),
        ])
        #expect(await repository.fetchThreadCalls.isEmpty)
    }

    // MARK: - Realtime Lifecycle

    @Test("실시간 시작은 연결 소유자에게 위임한다")
    func startsRealtime() async {
        let realtime = FakeThreadRealtime()
        let useCase = makeUseCase(realtime: realtime)

        await useCase.startRealtime()

        #expect(await realtime.startCount == 1)
    }

    @Test("신호 스트림은 실시간 채널의 스트림을 그대로 흘려보낸다")
    func forwardsRealtimeSignals() async throws {
        let realtime = FakeThreadRealtime()
        let useCase = makeUseCase(realtime: realtime)

        let signals = await useCase.signals()
        await realtime.emit(.commandFailed(makeCommandError()))

        var iterator = signals.makeAsyncIterator()
        let received = try #require(await iterator.next())

        guard case .commandFailed(let error) = received else {
            Issue.record("commandFailed 가 아닌 신호를 받았다")
            return
        }
        #expect(error.isRateLimited)
    }

    // MARK: - Function

    private func makeUseCase(
        repository: FakeThreadRepository = FakeThreadRepository(),
        realtime: FakeThreadRealtime = FakeThreadRealtime()
    ) -> CommunityThreadRoomUseCase {
        CommunityThreadRoomUseCase(repository: repository, realtime: realtime)
    }
}

@Suite("커뮤니티 스레드 참여자 UseCase")
struct CommunityThreadMemberUseCaseTests {

    @Test("개설자를 맨 위로, 나머지는 이름순으로 정렬한다")
    func sortsOwnerFirstThenByName() async throws {
        let repository = FakeThreadRepository(members: [
            makeMember(id: "3", name: "정의진", role: .member),
            makeMember(id: "7", name: "이재원", role: .owner),
            makeMember(id: "9", name: "강예진", role: .admin)
        ])
        let useCase = CommunityThreadMemberUseCase(repository: repository)

        let members = try await useCase.loadMembers(threadId: "1")

        #expect(members.map(\.id) == ["7", "9", "3"])
        #expect(await repository.fetchMembersCalls == ["1"])
    }

    @Test("내보내기는 대상 멤버 그대로 저장소에 넘긴다")
    func forwardsKickTarget() async throws {
        let repository = FakeThreadRepository()
        let useCase = CommunityThreadMemberUseCase(repository: repository)

        try await useCase.kick(threadId: "1", memberId: "9")

        let call = try #require(await repository.kickCalls.first)
        #expect(call.threadId == "1")
        #expect(call.memberId == "9")
    }

    @Test("위임은 대상 멤버의 역할을 OWNER 로 올린다")
    func transfersOwnershipWithOwnerRole() async throws {
        let repository = FakeThreadRepository()
        let useCase = CommunityThreadMemberUseCase(repository: repository)

        try await useCase.transferOwnership(threadId: "1", to: "9")

        let call = try #require(await repository.roleCalls.first)
        #expect(call.memberId == "9")
        #expect(call.role == ThreadMemberRole.owner.rawValue)
    }

    @Test("나가기 실패는 삼키지 않고 그대로 올린다 — 개설자 차단(409)을 화면이 알아야 한다")
    func propagatesLeaveFailure() async {
        let repository = FakeThreadRepository(error: FakeFailure())
        let useCase = CommunityThreadMemberUseCase(repository: repository)

        await #expect(throws: FakeFailure.self) {
            try await useCase.leave(threadId: "1")
        }
    }
}

@Suite("커뮤니티 스레드 초대 UseCase")
struct CommunityThreadInviteUseCaseTests {

    @Test("후보는 이름순으로 정렬하고 남은 정원을 함께 돌려준다")
    func sortsCandidatesAndReportsRemainingSlots() async throws {
        let repository = FakeThreadRepository(invitableMembers: [
            makeMember(id: "3", name: "정의진", role: .member),
            makeMember(id: "7", name: "강예진", role: .member)
        ])
        let useCase = CommunityThreadInviteUseCase(repository: repository)

        let result = try await useCase.loadCandidates(threadId: "1")

        #expect(result.candidates.map(\.id) == ["7", "3"])
        // 정원 30 · 현재 12명.
        #expect(result.remainingSlots == 18)
        #expect(await repository.fetchInvitableMembersCalls == ["1"])
    }

    @Test("정원이 이미 찼으면 남은 자리는 음수가 아니라 0 이다")
    func clampsRemainingSlotsAtZero() async throws {
        let repository = FakeThreadRepository(
            thread: makeThread(memberCount: "31", maxMembers: "30")
        )
        let useCase = CommunityThreadInviteUseCase(repository: repository)

        let result = try await useCase.loadCandidates(threadId: "1")

        #expect(result.remainingSlots == 0)
    }

    @Test("서버 정원 값이 쓸모없으면 상한을 두지 않는다 — nil 로 올린다")
    func omitsRemainingSlotsWithoutCapacity() async throws {
        let repository = FakeThreadRepository(thread: makeThread(maxMembers: "0"))
        let useCase = CommunityThreadInviteUseCase(repository: repository)

        let result = try await useCase.loadCandidates(threadId: "1")

        #expect(result.remainingSlots == nil)
    }

    @Test("초대는 고른 멤버를 그대로 저장소에 넘긴다")
    func forwardsInviteTargets() async throws {
        let repository = FakeThreadRepository()
        let useCase = CommunityThreadInviteUseCase(repository: repository)

        try await useCase.invite(threadId: "1", memberIds: ["11", "12"])

        let call = try #require(await repository.inviteCalls.first)
        #expect(call.threadId == "1")
        #expect(call.memberIds == ["11", "12"])
    }

    @Test("빈 선택은 저장소까지 가지 않는다 — 서버가 400 으로 거절하는 요청이다")
    func skipsEmptyInvite() async throws {
        let repository = FakeThreadRepository()
        let useCase = CommunityThreadInviteUseCase(repository: repository)

        try await useCase.invite(threadId: "1", memberIds: [])

        #expect(await repository.inviteCalls.isEmpty)
    }
}

@Suite("커뮤니티 스레드 편집 UseCase")
struct CommunityThreadEditUseCaseTests {

    /// 부분 수정의 전부다 — 안 건드린 필드가 `nil` 로 남아야 서버 값이 유지된다.
    @Test("넘기지 않은 필드는 nil 그대로 내려가 서버 값을 건드리지 않는다")
    func keepsUntouchedFieldsNil() async throws {
        let repository = FakeThreadRepository()
        let useCase = CommunityThreadEditUseCase(repository: repository)

        _ = try await useCase.update(
            threadId: "1",
            title: nil,
            description: "매주 목요일 9시",
            category: nil,
            icon: nil
        )

        let call = try #require(await repository.updateThreadCalls.first)
        #expect(call.threadId == "1")
        #expect(call.title == nil)
        #expect(call.description == "매주 목요일 9시")
        #expect(call.category == nil)
        #expect(call.icon == nil)
    }

    @Test("제목·특징은 공백을 털고 상한까지 잘라 보내며 카테고리는 rawValue 로 내려간다")
    func trimsClampsAndSendsRawValue() async throws {
        let repository = FakeThreadRepository()
        let useCase = CommunityThreadEditUseCase(repository: repository)

        _ = try await useCase.update(
            threadId: "1",
            title: "  " + String(repeating: "가", count: 100) + " ",
            description: " 매주 화요일 8시 ",
            category: .project,
            icon: "🚀"
        )

        let call = try #require(await repository.updateThreadCalls.first)
        #expect(call.title?.unicodeScalars.count == CommunityThreadCreateRule.titleMaxLength)
        #expect(call.description == "매주 화요일 8시")
        #expect(call.category == "PROJECT")
        #expect(call.icon == "🚀")
    }

    /// 아이콘만 지우는 요청은 서버 계약에 없다. 빈 값으로 밀면 `@SingleGrapheme` 400 이다.
    @Test("이모지가 아닌 아이콘은 키째 빼서 기존 아이콘을 남긴다")
    func dropsNonEmojiIcon() async throws {
        for input in ["", "a", "스터디"] {
            let repository = FakeThreadRepository()
            let useCase = CommunityThreadEditUseCase(repository: repository)

            _ = try await useCase.update(
                threadId: "1",
                title: nil,
                description: nil,
                category: nil,
                icon: input
            )

            let call = try #require(await repository.updateThreadCalls.first)
            #expect(call.icon == nil, "입력 \(input)")
        }
    }

    @Test("삭제는 스레드 id 를 그대로 넘긴다")
    func forwardsDeleteTarget() async throws {
        let repository = FakeThreadRepository()
        let useCase = CommunityThreadEditUseCase(repository: repository)

        try await useCase.delete(threadId: "42")

        #expect(await repository.deleteThreadCalls == ["42"])
    }

    @Test("삭제 실패는 삼키지 않고 그대로 올린다 — 권한 없음(403)을 화면이 알아야 한다")
    func propagatesDeleteFailure() async {
        let repository = FakeThreadRepository(error: FakeFailure())
        let useCase = CommunityThreadEditUseCase(repository: repository)

        await #expect(throws: FakeFailure.self) {
            try await useCase.delete(threadId: "1")
        }
    }
}

// MARK: - Fake

private struct FakeFailure: Error, Equatable {}

private actor FakeThreadRepository: CommunityThreadRepositoryProtocol {

    struct FetchThreadsCall: Equatable {
        let filter: String
        let query: String?
        let offset: Int
        let limit: Int
    }

    struct FetchMessagesCall: Equatable {
        let threadId: String
        let before: String?
        let limit: Int
    }

    struct ToggleCall: Equatable {
        let threadId: String
        let isOn: Bool
    }

    struct CreateThreadCall: Equatable {
        let title: String
        let description: String
        let category: String
        let icon: String
    }

    struct MemberCall: Equatable {
        let threadId: String
        let memberId: String
        let role: String?
    }

    /// `nil` 은 "그 필드는 건드리지 않는다" 는 뜻이라 부분 수정 검증의 핵심이다.
    struct UpdateThreadCall: Equatable {
        let threadId: String
        let title: String?
        let description: String?
        let category: String?
        let icon: String?
    }

    struct ReportCall: Equatable {
        let messageId: String
        let reason: String
    }

    struct InviteCall: Equatable {
        let threadId: String
        let memberIds: [String]
    }

    // MARK: - Property

    private(set) var createThreadCalls: [CreateThreadCall] = []
    private(set) var fetchThreadsCalls: [FetchThreadsCall] = []
    private(set) var fetchThreadCalls: [String] = []
    private(set) var fetchMessagesCalls: [FetchMessagesCall] = []
    private(set) var pinCalls: [ToggleCall] = []
    private(set) var muteCalls: [ToggleCall] = []
    private(set) var fetchMembersCalls: [String] = []
    private(set) var fetchInvitableMembersCalls: [String] = []
    private(set) var inviteCalls: [InviteCall] = []
    private(set) var kickCalls: [MemberCall] = []
    private(set) var roleCalls: [MemberCall] = []
    private(set) var leaveCalls: [String] = []
    private(set) var reportCalls: [ReportCall] = []
    private(set) var updateThreadCalls: [UpdateThreadCall] = []
    private(set) var deleteThreadCalls: [String] = []

    private let threadPage: CommunityThreadPage
    private let thread: CommunityThread
    private let messagePage: ThreadMessagePage
    private let members: [ThreadMember]
    private let invitableMembers: [ThreadMember]
    private let error: Error?

    // MARK: - Init

    init(
        threadPage: CommunityThreadPage = CommunityThreadPage(
            pinned: [],
            threads: [],
            nextOffset: nil,
            total: "0"
        ),
        thread: CommunityThread = makeThread(),
        messagePage: ThreadMessagePage = ThreadMessagePage(
            messages: [],
            hasMore: false,
            nextBefore: nil
        ),
        members: [ThreadMember] = [],
        invitableMembers: [ThreadMember] = [],
        error: Error? = nil
    ) {
        self.threadPage = threadPage
        self.thread = thread
        self.messagePage = messagePage
        self.members = members
        self.invitableMembers = invitableMembers
        self.error = error
    }

    // MARK: - Function

    func fetchThreads(
        filter: String,
        query: String?,
        offset: Int,
        limit: Int
    ) async throws -> CommunityThreadPage {
        fetchThreadsCalls.append(
            FetchThreadsCall(filter: filter, query: query, offset: offset, limit: limit)
        )
        if let error { throw error }
        return threadPage
    }

    func fetchThread(threadId: String) async throws -> CommunityThread {
        fetchThreadCalls.append(threadId)
        if let error { throw error }
        return thread
    }

    func fetchMessages(
        threadId: String,
        before: String?,
        limit: Int
    ) async throws -> ThreadMessagePage {
        fetchMessagesCalls.append(
            FetchMessagesCall(threadId: threadId, before: before, limit: limit)
        )
        if let error { throw error }
        return messagePage
    }

    func createThread(
        title: String,
        description: String,
        category: String,
        icon: String
    ) async throws -> CommunityThread {
        createThreadCalls.append(
            CreateThreadCall(
                title: title,
                description: description,
                category: category,
                icon: icon
            )
        )
        if let error { throw error }
        return thread
    }

    func updateThread(
        threadId: String,
        title: String?,
        description: String?,
        category: String?,
        icon: String?
    ) async throws -> CommunityThread {
        updateThreadCalls.append(
            UpdateThreadCall(
                threadId: threadId,
                title: title,
                description: description,
                category: category,
                icon: icon
            )
        )
        if let error { throw error }
        return thread
    }

    func deleteThread(threadId: String) async throws {
        deleteThreadCalls.append(threadId)
        if let error { throw error }
    }

    func setPinned(threadId: String, isPinned: Bool) async throws {
        pinCalls.append(ToggleCall(threadId: threadId, isOn: isPinned))
        if let error { throw error }
    }

    func setMuted(threadId: String, isMuted: Bool) async throws {
        muteCalls.append(ToggleCall(threadId: threadId, isOn: isMuted))
        if let error { throw error }
    }

    func fetchMembers(threadId: String) async throws -> [ThreadMember] {
        fetchMembersCalls.append(threadId)
        if let error { throw error }
        return members
    }

    func fetchInvitableMembers(threadId: String) async throws -> [ThreadMember] {
        fetchInvitableMembersCalls.append(threadId)
        if let error { throw error }
        return invitableMembers
    }

    func inviteMembers(threadId: String, memberIds: [String]) async throws {
        inviteCalls.append(InviteCall(threadId: threadId, memberIds: memberIds))
        if let error { throw error }
    }

    func kickMember(threadId: String, memberId: String) async throws {
        kickCalls.append(MemberCall(threadId: threadId, memberId: memberId, role: nil))
        if let error { throw error }
    }

    func changeMemberRole(threadId: String, memberId: String, role: String) async throws {
        roleCalls.append(MemberCall(threadId: threadId, memberId: memberId, role: role))
        if let error { throw error }
    }

    func leaveThread(threadId: String) async throws {
        leaveCalls.append(threadId)
        if let error { throw error }
    }

    func reportMessage(messageId: String, reason: String) async throws {
        reportCalls.append(ReportCall(messageId: messageId, reason: reason))
        if let error { throw error }
    }
}

private actor FakeThreadRealtime: CommunityThreadRealtimeProtocol {

    struct SendCall: Equatable {
        let threadId: String
        let clientMessageId: String
        let content: String
        let fileMetadataIds: [String]
        let replyToId: String?
        let mentionedMemberIds: [String]
    }

    struct ReadCall: Equatable {
        let threadId: String
        let lastReadMessageId: String
    }

    struct ReactionCall: Equatable {
        let threadId: String
        let messageId: String
        let emoji: String
    }

    struct DeleteCall: Equatable {
        let threadId: String
        let messageId: String
    }

    // MARK: - Property

    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var sendCalls: [SendCall] = []
    private(set) var readCalls: [ReadCall] = []
    private(set) var addReactionCalls: [ReactionCall] = []
    private(set) var removeReactionCalls: [ReactionCall] = []
    private(set) var deleteCalls: [DeleteCall] = []

    private let sendError: Error?
    private let commandError: Error?
    private let stream: AsyncStream<CommunityRealtimeSignal>
    private let continuation: AsyncStream<CommunityRealtimeSignal>.Continuation

    // MARK: - Init

    init(sendError: Error? = nil, commandError: Error? = nil) {
        self.sendError = sendError
        self.commandError = commandError
        let made = AsyncStream.makeStream(of: CommunityRealtimeSignal.self)
        self.stream = made.stream
        self.continuation = made.continuation
    }

    // MARK: - Function

    func emit(_ signal: CommunityRealtimeSignal) {
        continuation.yield(signal)
    }

    func start() async {
        startCount += 1
    }

    func stop() async {
        stopCount += 1
    }

    func signals() async -> AsyncStream<CommunityRealtimeSignal> {
        stream
    }

    func sendMessage(
        threadId: String,
        clientMessageId: String,
        content: String,
        fileMetadataIds: [String],
        replyToId: String?,
        mentionedMemberIds: [String]
    ) async throws {
        sendCalls.append(
            SendCall(
                threadId: threadId,
                clientMessageId: clientMessageId,
                content: content,
                fileMetadataIds: fileMetadataIds,
                replyToId: replyToId,
                mentionedMemberIds: mentionedMemberIds
            )
        )
        if let sendError { throw sendError }
    }

    func updateReadWatermark(threadId: String, lastReadMessageId: String) async throws {
        readCalls.append(ReadCall(threadId: threadId, lastReadMessageId: lastReadMessageId))
    }

    func addReaction(threadId: String, messageId: String, emoji: String) async throws {
        addReactionCalls.append(
            ReactionCall(threadId: threadId, messageId: messageId, emoji: emoji)
        )
        if let commandError { throw commandError }
    }

    func removeReaction(threadId: String, messageId: String, emoji: String) async throws {
        removeReactionCalls.append(
            ReactionCall(threadId: threadId, messageId: messageId, emoji: emoji)
        )
        if let commandError { throw commandError }
    }

    func deleteMessage(threadId: String, messageId: String) async throws {
        deleteCalls.append(DeleteCall(threadId: threadId, messageId: messageId))
        if let commandError { throw commandError }
    }
}

// MARK: - Fixture

private func makeThread(
    id: String = "thread-1",
    memberCount: String = "12",
    maxMembers: String = "30"
) -> CommunityThread {
    CommunityThread(
        id: id,
        title: "iOS 스터디",
        description: "설명",
        category: .study,
        icon: "🔥",
        memberCount: memberCount,
        unreadCount: "0",
        maxMembers: maxMembers,
        isPinned: false,
        isMuted: false,
        isJoined: true,
        myRole: .member,
        lastMessage: nil,
        createdBy: "creator-id",
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 100)
    )
}

private func makeMember(
    id: String,
    name: String,
    role: ThreadMemberRole
) -> ThreadMember {
    ThreadMember(id: id, name: name, part: "iOS", profileImageURL: nil, role: role)
}

private func makeMessage(id: String) -> ThreadMessage {
    ThreadMessage(
        id: id,
        threadId: "thread-1",
        senderId: "sender-id",
        senderName: "정의진",
        content: "안녕하세요",
        type: .text,
        createdAt: Date(timeIntervalSince1970: 100)
    )
}

private func makeCommandError() -> RealtimeCommandError {
    RealtimeCommandError(
        commandId: "command-id",
        clientMessageId: "client-1",
        status: "429",
        code: "RATE_LIMITED",
        message: "요청이 너무 많습니다",
        retryable: true
    )
}
