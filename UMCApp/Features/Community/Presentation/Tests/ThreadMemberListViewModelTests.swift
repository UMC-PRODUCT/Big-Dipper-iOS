//
//  ThreadMemberListViewModelTests.swift
//  CommunityPresentationTests
//

import Foundation
import Testing
import CommunityDomain
import UMCFoundation
@testable import CommunityPresentation

// MARK: - Test Double

/// 호출을 기록하고 결과를 미리 심어 두는 UseCase 대역.
///
/// 스위트가 `@MainActor` 라 대역도 같은 격리에 둬 `await` 없이 기록을 검증한다
/// (`CommunityThreadListViewModelTests` 와 같은 구성).
@MainActor
private final class StubMemberUseCase: CommunityThreadMemberUseCaseProtocol {

    var members: [ThreadMember] = []
    var shouldFailLoad = false
    var shouldFailCommand = false
    /// 위임 성공 후 다시 읽을 목록. 서버가 이전 개설자를 어떤 역할로 내리는지 재현한다.
    var membersAfterTransfer: [ThreadMember]?

    private(set) var kickCalls: [String] = []
    private(set) var transferCalls: [String] = []
    private(set) var leaveCalls: [String] = []

    func loadMembers(threadId: String) async throws -> [ThreadMember] {
        if shouldFailLoad { throw AppError.unknown(message: "실패") }
        return members
    }

    func kick(threadId: String, memberId: String) async throws {
        kickCalls.append(memberId)
        if shouldFailCommand { throw AppError.unknown(message: "실패") }
    }

    func transferOwnership(threadId: String, to memberId: String) async throws {
        transferCalls.append(memberId)
        if shouldFailCommand { throw AppError.unknown(message: "실패") }
        if let membersAfterTransfer { members = membersAfterTransfer }
    }

    func leave(threadId: String) async throws {
        leaveCalls.append(threadId)
        if shouldFailCommand { throw AppError.unknown(message: "실패") }
    }
}

private func makeMember(
    id: String,
    name: String = "정의진",
    role: ThreadMemberRole = .member
) -> ThreadMember {
    ThreadMember(id: id, name: name, part: "iOS", profileImageURL: nil, role: role)
}

// MARK: - Tests

@Suite("ThreadMemberListViewModel")
@MainActor
struct ThreadMemberListViewModelTests {

    // MARK: - Function

    private func makeViewModel(
        _ useCase: StubMemberUseCase,
        errorHandler: ErrorHandler = ErrorHandler(),
        currentMemberId: String? = "5"
    ) -> ThreadMemberListViewModel {
        ThreadMemberListViewModel(
            threadId: "1",
            useCase: useCase,
            errorHandler: errorHandler,
            currentMemberId: currentMemberId
        )
    }

    /// 나(개설자) + 참여자 한 명. 관리 메뉴가 열리는 최소 구성이다.
    private func makeOwnerViewModel(
        _ useCase: StubMemberUseCase,
        errorHandler: ErrorHandler = ErrorHandler()
    ) async -> ThreadMemberListViewModel {
        useCase.members = [
            makeMember(id: "5", role: .owner),
            makeMember(id: "9", name: "이재원")
        ]
        let viewModel = makeViewModel(useCase, errorHandler: errorHandler)
        await viewModel.load()
        return viewModel
    }

    // MARK: - Load

    @Test("목록 로드 실패는 인라인 상태로 남는다")
    func keepsLoadFailureInline() async {
        let useCase = StubMemberUseCase()
        useCase.shouldFailLoad = true
        let viewModel = makeViewModel(useCase)

        await viewModel.load()

        #expect(viewModel.state.error != nil)
        #expect(viewModel.members.isEmpty)
    }

    // MARK: - Permission

    @Test("내 권한은 목록에 실려 온 내 행의 역할에서 읽는다")
    func readsMyRoleFromMyRow() async {
        let useCase = StubMemberUseCase()
        let viewModel = await makeOwnerViewModel(useCase)

        #expect(viewModel.isOwner)
    }

    @Test("참여자 계정에서는 어떤 행에도 관리 메뉴가 열리지 않는다")
    func hidesManageMenuForMember() async {
        let useCase = StubMemberUseCase()
        useCase.members = [
            makeMember(id: "5"),
            makeMember(id: "9", name: "이재원", role: .owner)
        ]
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        #expect(viewModel.isOwner == false)
        #expect(viewModel.members.allSatisfy { viewModel.canManage($0) == false })
    }

    @Test("개설자라도 내 행에는 관리 메뉴를 열지 않는다")
    func hidesManageMenuOnMyOwnRow() async {
        let useCase = StubMemberUseCase()
        let viewModel = await makeOwnerViewModel(useCase)

        let me = viewModel.members.first { $0.id == "5" }
        let other = viewModel.members.first { $0.id == "9" }

        #expect(me.map { viewModel.canManage($0) } == false)
        #expect(other.map { viewModel.canManage($0) } == true)
    }

    // MARK: - Kick

    @Test("내보내기는 확인 알림을 거쳐야 실행되고, 성공하면 목록에서 사라진다")
    func kicksOnlyAfterConfirmation() async throws {
        let useCase = StubMemberUseCase()
        let viewModel = await makeOwnerViewModel(useCase)
        let target = try #require(viewModel.members.first { $0.id == "9" })

        viewModel.confirmKick(target)
        #expect(useCase.kickCalls.isEmpty)

        let confirm = try #require(viewModel.alertPrompt?.positiveBtnAction)
        confirm()
        await Task.yield()

        #expect(useCase.kickCalls == ["9"])
        #expect(viewModel.members.map(\.id) == ["5"])
    }

    @Test("내보내기 확인 알림은 재초대 조건을 알린다")
    func kickPromptExplainsReinvite() async throws {
        let useCase = StubMemberUseCase()
        let viewModel = await makeOwnerViewModel(useCase)
        let target = try #require(viewModel.members.first { $0.id == "9" })

        viewModel.confirmKick(target)

        let prompt = try #require(viewModel.alertPrompt)
        #expect(prompt.message.contains("다시 초대"))
        #expect(prompt.isPositiveBtnDestructive)
    }

    @Test("내보내기가 실패하면 사라졌던 행이 되돌아온다")
    func restoresRowWhenKickFails() async throws {
        let useCase = StubMemberUseCase()
        let errorHandler = ErrorHandler()
        let viewModel = await makeOwnerViewModel(useCase, errorHandler: errorHandler)
        useCase.shouldFailCommand = true
        let target = try #require(viewModel.members.first { $0.id == "9" })

        viewModel.confirmKick(target)
        try #require(viewModel.alertPrompt?.positiveBtnAction)()
        await Task.yield()

        #expect(viewModel.members.map(\.id) == ["5", "9"])
        #expect(errorHandler.currentError != nil)
    }

    @Test("참여자 계정의 내보내기 요청은 확인 알림조차 띄우지 않는다")
    func ignoresKickFromNonOwner() async throws {
        let useCase = StubMemberUseCase()
        useCase.members = [makeMember(id: "5"), makeMember(id: "9", name: "이재원", role: .owner)]
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.confirmKick(try #require(viewModel.members.first { $0.id == "9" }))

        #expect(viewModel.alertPrompt == nil)
        #expect(useCase.kickCalls.isEmpty)
    }

    // MARK: - Ownership Transfer

    @Test("위임은 확인을 거친 뒤 실행되고, 끝나면 서버 역할을 다시 읽는다")
    func transfersOwnershipAfterConfirmation() async throws {
        let useCase = StubMemberUseCase()
        let viewModel = await makeOwnerViewModel(useCase)
        // 서버가 이전 개설자를 어떤 역할로 내리는지는 클라이언트가 추측하지 않는다.
        useCase.membersAfterTransfer = [
            makeMember(id: "9", name: "이재원", role: .owner),
            makeMember(id: "5", role: .admin)
        ]
        let target = try #require(viewModel.members.first { $0.id == "9" })

        viewModel.confirmTransferOwnership(to: target)
        #expect(useCase.transferCalls.isEmpty)

        try #require(viewModel.alertPrompt?.positiveBtnAction)()
        await waitUntil { viewModel.isOwner == false }

        #expect(useCase.transferCalls == ["9"])
        #expect(viewModel.members.first { $0.id == "5" }?.role == .admin)
    }

    // MARK: - Leave

    @Test("개설자는 위임 전까지 나갈 수 없고, 사유가 안내된다")
    func blocksOwnerLeaveUntilDelegated() async {
        let useCase = StubMemberUseCase()
        let viewModel = await makeOwnerViewModel(useCase)

        #expect(viewModel.canLeave == false)
        #expect(viewModel.leaveBlockReason?.contains("위임") == true)

        viewModel.confirmLeave()

        #expect(viewModel.alertPrompt == nil)
        #expect(useCase.leaveCalls.isEmpty)
    }

    @Test("참여자가 나뿐인 개설자에게는 위임 대신 스레드 삭제를 안내한다")
    func guidesSoloOwnerToDeleteThread() async {
        let useCase = StubMemberUseCase()
        useCase.members = [makeMember(id: "5", role: .owner)]
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        #expect(viewModel.canLeave == false)
        #expect(viewModel.leaveBlockReason?.contains("삭제") == true)
    }

    @Test("위임을 끝낸 개설자는 일반 참여자처럼 나갈 수 있다")
    func allowsLeaveAfterDelegation() async throws {
        let useCase = StubMemberUseCase()
        let viewModel = await makeOwnerViewModel(useCase)
        useCase.membersAfterTransfer = [
            makeMember(id: "9", name: "이재원", role: .owner),
            makeMember(id: "5", role: .member)
        ]

        viewModel.confirmTransferOwnership(to: try #require(viewModel.members.first { $0.id == "9" }))
        try #require(viewModel.alertPrompt?.positiveBtnAction)()
        await waitUntil { viewModel.canLeave }

        #expect(viewModel.leaveBlockReason == nil)

        viewModel.confirmLeave()
        try #require(viewModel.alertPrompt?.positiveBtnAction)()
        await waitUntil { viewModel.didLeave }

        #expect(useCase.leaveCalls == ["1"])
    }

    @Test("나가기 확인 알림은 재참여 조건을 알린다")
    func leavePromptExplainsRejoin() async throws {
        let useCase = StubMemberUseCase()
        useCase.members = [makeMember(id: "5"), makeMember(id: "9", name: "이재원", role: .owner)]
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.confirmLeave()

        let prompt = try #require(viewModel.alertPrompt)
        #expect(prompt.message.contains("초대"))
        #expect(prompt.isPositiveBtnDestructive)
    }

    @Test("나가기가 실패하면 화면을 닫지 않고 전역 에러로 알린다")
    func keepsScreenWhenLeaveFails() async throws {
        let useCase = StubMemberUseCase()
        let errorHandler = ErrorHandler()
        useCase.members = [makeMember(id: "5"), makeMember(id: "9", name: "이재원", role: .owner)]
        let viewModel = makeViewModel(useCase, errorHandler: errorHandler)
        await viewModel.load()
        useCase.shouldFailCommand = true

        viewModel.confirmLeave()
        try #require(viewModel.alertPrompt?.positiveBtnAction)()
        await waitUntil { errorHandler.currentError != nil }

        #expect(viewModel.didLeave == false)
    }

    // MARK: - Helper

    /// `AlertPrompt` 액션이 띄운 Task 가 끝날 때까지 기다린다.
    private func waitUntil(
        timeout: Duration = .seconds(2),
        _ condition: () -> Bool
    ) async {
        let deadline = ContinuousClock.now + timeout
        while !condition(), ContinuousClock.now < deadline {
            await Task.yield()
        }
    }
}
