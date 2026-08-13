//
//  CommunityThreadCreateViewModelTests.swift
//  CommunityPresentationTests
//

import Foundation
import Testing
import CommunityDomain
import UMCFoundation
@testable import CommunityPresentation

// MARK: - Test Double

@MainActor
private final class StubCreateUseCase: CommunityThreadCreateUseCaseProtocol {

    struct Call: Equatable {
        let title: String
        let description: String
        let category: CommunityThreadCategory
        let icon: String
    }

    var shouldFail = false
    private(set) var calls: [Call] = []

    func create(
        title: String,
        description: String,
        category: CommunityThreadCategory,
        icon: String
    ) async throws -> CommunityThread {
        calls.append(Call(title: title, description: description, category: category, icon: icon))
        if shouldFail { throw AppError.unknown(message: "생성 실패") }
        return makeThread(id: "new")
    }
}

// MARK: - Tests

@Suite("커뮤니티 스레드 생성 ViewModel")
@MainActor
struct CommunityThreadCreateViewModelTests {

    // MARK: - 제출 조건

    @Test("제목·특징 중 하나라도 비면 제출할 수 없다")
    func requiresTitleAndDescription() {
        let viewModel = CommunityThreadCreateViewModel(useCase: StubCreateUseCase())

        #expect(!viewModel.canSubmit)

        viewModel.title = "iOS 스터디"
        #expect(!viewModel.canSubmit)

        viewModel.threadDescription = "매주 화요일 8시"
        #expect(viewModel.canSubmit)
    }

    @Test("공백만 채운 입력은 제출 조건을 채우지 못한다")
    func rejectsWhitespaceOnlyInput() {
        let viewModel = CommunityThreadCreateViewModel(useCase: StubCreateUseCase())

        viewModel.title = "   \n"
        viewModel.threadDescription = "\t "

        #expect(!viewModel.canSubmit)
    }

    @Test("아이콘은 비어도 제출할 수 있다 — 카테고리 기본 이모지가 채운다")
    func iconIsOptionalForSubmission() {
        let viewModel = CommunityThreadCreateViewModel(useCase: StubCreateUseCase())

        viewModel.title = "질문방"
        viewModel.threadDescription = "무엇이든"
        viewModel.category = .qna

        #expect(viewModel.icon.isEmpty)
        #expect(viewModel.canSubmit)
        #expect(viewModel.iconPlaceholder == CommunityThreadCategory.qna.defaultIcon)
    }

    // MARK: - 입력 제한

    @Test("아이콘 칸은 이모지 하나만 남긴다")
    func keepsSingleEmojiInIconField() {
        let viewModel = CommunityThreadCreateViewModel(useCase: StubCreateUseCase())

        viewModel.icon = "📚🚀"
        #expect(viewModel.icon == "🚀")

        // ZWJ 조합은 Character 하나라 통과한다 (서버 @SingleGrapheme 도 통과).
        viewModel.icon = "👨‍👩‍👧"
        #expect(viewModel.icon == "👨‍👩‍👧")

        // Genmoji 를 못 쓰게 막아도 텍스트는 붙여넣을 수 있다. 이모지가 아니면 비운다.
        viewModel.icon = "스터디"
        #expect(viewModel.icon.isEmpty)
    }

    @Test("제목·특징은 서버 상한을 넘기지 못한다")
    func clampsInputToServerLimits() {
        let viewModel = CommunityThreadCreateViewModel(useCase: StubCreateUseCase())

        viewModel.title = String(repeating: "가", count: 200)
        viewModel.threadDescription = String(repeating: "나", count: 700)

        #expect(viewModel.title.unicodeScalars.count == CommunityThreadCreateRule.titleMaxLength)
        #expect(
            viewModel.threadDescription.unicodeScalars.count
                == CommunityThreadCreateRule.descriptionMaxLength
        )
    }

    // MARK: - 제출

    @Test("제출 성공하면 생성된 스레드를 돌려준다")
    func returnsCreatedThread() async throws {
        let useCase = StubCreateUseCase()
        let viewModel = CommunityThreadCreateViewModel(useCase: useCase)
        viewModel.title = "iOS 스터디"
        viewModel.threadDescription = "매주 화요일 8시"
        viewModel.category = .study
        viewModel.icon = "📚"

        let thread = await viewModel.submit()

        #expect(thread?.id == "new")
        #expect(
            useCase.calls == [
                StubCreateUseCase.Call(
                    title: "iOS 스터디",
                    description: "매주 화요일 8시",
                    category: .study,
                    icon: "📚"
                )
            ]
        )
    }

    @Test("실패하면 인라인 에러가 뜨고 입력값은 그대로 남는다")
    func keepsInputOnFailure() async {
        let useCase = StubCreateUseCase()
        useCase.shouldFail = true
        let viewModel = CommunityThreadCreateViewModel(useCase: useCase)
        viewModel.title = "iOS 스터디"
        viewModel.threadDescription = "매주 화요일 8시"

        let thread = await viewModel.submit()

        #expect(thread == nil)
        #expect(viewModel.submitErrorMessage != nil)
        #expect(viewModel.title == "iOS 스터디")
        #expect(viewModel.threadDescription == "매주 화요일 8시")
        #expect(viewModel.canSubmit)
    }

    @Test("제출 조건을 못 채우면 UseCase 를 부르지 않는다")
    func doesNotSubmitWhenInvalid() async {
        let useCase = StubCreateUseCase()
        let viewModel = CommunityThreadCreateViewModel(useCase: useCase)

        let thread = await viewModel.submit()

        #expect(thread == nil)
        #expect(useCase.calls.isEmpty)
    }
}

// MARK: - Fixture

private func makeThread(id: String) -> CommunityThread {
    CommunityThread(
        id: id,
        title: "iOS 스터디",
        description: "매주 화요일 8시",
        category: .study,
        icon: "📚",
        memberCount: "1",
        unreadCount: "0",
        maxMembers: "100",
        isPinned: false,
        isMuted: false,
        isJoined: true,
        myRole: .owner,
        lastMessage: nil,
        createdBy: "5",
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0)
    )
}
