//
//  ThreadInviteViewModelTests.swift
//  CommunityPresentationTests
//

import Foundation
import Testing
import CommunityDomain
import UMCFoundation
@testable import CommunityPresentation

// MARK: - Test Double

/// 후보와 남은 정원을 미리 심어 두고 초대 호출을 기록하는 UseCase 대역.
@MainActor
private final class StubInviteUseCase: CommunityThreadInviteUseCaseProtocol {

    var candidates: [ThreadMember] = []
    var remainingSlots: Int?
    var shouldFailLoad = false
    var shouldFailInvite = false

    private(set) var inviteCalls: [[String]] = []

    func loadCandidates(threadId: String) async throws -> ThreadInviteCandidates {
        if shouldFailLoad { throw AppError.unknown(message: "실패") }
        return ThreadInviteCandidates(candidates: candidates, remainingSlots: remainingSlots)
    }

    func invite(threadId: String, memberIds: [String]) async throws {
        inviteCalls.append(memberIds)
        if shouldFailInvite { throw AppError.unknown(message: "실패") }
    }
}

private func makeMember(id: String, name: String, part: String?) -> ThreadMember {
    ThreadMember(id: id, name: name, part: part, profileImageURL: nil, role: .member)
}

// MARK: - Tests

@Suite("ThreadInviteViewModel")
@MainActor
struct ThreadInviteViewModelTests {

    // MARK: - Function

    /// 파트가 제각각인 후보 셋. "동아리 전체" 범위(#1131 결정 3)를 그대로 재현한다.
    private func makeViewModel(
        _ useCase: StubInviteUseCase,
        remainingSlots: Int? = 10
    ) async -> ThreadInviteViewModel {
        useCase.candidates = [
            makeMember(id: "11", name: "김하늘", part: "Web"),
            makeMember(id: "12", name: "박서준", part: "Spring"),
            makeMember(id: "13", name: "최유나", part: nil)
        ]
        useCase.remainingSlots = remainingSlots

        let viewModel = ThreadInviteViewModel(threadId: "1", useCase: useCase)
        await viewModel.load()
        return viewModel
    }

    // MARK: - Search

    @Test("파트가 달라도 이름만 맞으면 검색 결과에 남는다")
    func searchesAcrossParts() async {
        let useCase = StubInviteUseCase()
        let viewModel = await makeViewModel(useCase)

        #expect(viewModel.filteredCandidates.count == 3)

        viewModel.searchText = "유나"

        #expect(viewModel.filteredCandidates.map(\.id) == ["13"])
    }

    @Test("검색어를 바꿔 화면에서 사라져도 선택은 유지된다")
    func keepsSelectionWhileSearching() async throws {
        let useCase = StubInviteUseCase()
        let viewModel = await makeViewModel(useCase)
        let target = try #require(viewModel.candidates.first)

        viewModel.toggle(target)
        viewModel.searchText = "박서준"

        #expect(viewModel.filteredCandidates.map(\.id) == ["12"])
        #expect(viewModel.selectedCount == 1)
        #expect(viewModel.isSelected(target))
    }

    // MARK: - Capacity

    @Test("남은 정원을 넘기는 선택은 차단되고 사유가 남는다")
    func blocksSelectionOverCapacity() async {
        let useCase = StubInviteUseCase()
        let viewModel = await makeViewModel(useCase, remainingSlots: 2)

        viewModel.candidates.forEach { viewModel.toggle($0) }

        #expect(viewModel.selectedCount == 2)
        #expect(viewModel.capacityNotice?.contains("2명") == true)
    }

    @Test("정원이 가득 차면 고를 것이 없다고 알린다")
    func reportsCapacityFull() async {
        let useCase = StubInviteUseCase()
        let viewModel = await makeViewModel(useCase, remainingSlots: 0)

        #expect(viewModel.isCapacityFull)
        #expect(viewModel.canSubmit == false)
    }

    @Test("상한에 걸린 상태에서도 선택 해제는 통과한다")
    func allowsDeselectionAtLimit() async throws {
        let useCase = StubInviteUseCase()
        let viewModel = await makeViewModel(useCase, remainingSlots: 1)
        let target = try #require(viewModel.candidates.first)

        viewModel.toggle(target)
        viewModel.toggle(target)

        #expect(viewModel.selectedCount == 0)
        #expect(viewModel.capacityNotice == nil)
    }

    @Test("서버 정원 값이 없으면 요청 상한(99명)까지 고를 수 있다")
    func fallsBackToRequestLimit() async {
        let useCase = StubInviteUseCase()
        let viewModel = await makeViewModel(useCase, remainingSlots: nil)

        #expect(viewModel.selectionLimit == 99)
        #expect(viewModel.isCapacityFull == false)
    }

    // MARK: - Invite

    @Test("선택한 인원 수가 성공 결과로 올라온다")
    func reportsInvitedCount() async throws {
        let useCase = StubInviteUseCase()
        let viewModel = await makeViewModel(useCase)
        let targets = viewModel.candidates.prefix(2)
        targets.forEach { viewModel.toggle($0) }

        await viewModel.invite()

        #expect(viewModel.invitedCount == 2)
        #expect(useCase.inviteCalls.first?.sorted() == ["11", "12"])
    }

    @Test("초대에 실패해도 선택은 그대로 남아 다시 시도할 수 있다")
    func keepsSelectionWhenInviteFails() async throws {
        let useCase = StubInviteUseCase()
        let viewModel = await makeViewModel(useCase)
        useCase.shouldFailInvite = true
        let target = try #require(viewModel.candidates.first)
        viewModel.toggle(target)

        await viewModel.invite()

        #expect(viewModel.submitState.error != nil)
        #expect(viewModel.selectedCount == 1)
        #expect(viewModel.canSubmit)
        #expect(viewModel.invitedCount == nil)
    }

    @Test("한 명도 고르지 않으면 요청을 보내지 않는다")
    func skipsEmptyInvite() async {
        let useCase = StubInviteUseCase()
        let viewModel = await makeViewModel(useCase)

        await viewModel.invite()

        #expect(useCase.inviteCalls.isEmpty)
    }

    // MARK: - Load

    @Test("후보 로드 실패는 시트 안 인라인 상태로 남는다")
    func keepsLoadFailureInline() async {
        let useCase = StubInviteUseCase()
        useCase.shouldFailLoad = true
        let viewModel = ThreadInviteViewModel(threadId: "1", useCase: useCase)

        await viewModel.load()

        #expect(viewModel.state.error != nil)
        #expect(viewModel.candidates.isEmpty)
    }
}
