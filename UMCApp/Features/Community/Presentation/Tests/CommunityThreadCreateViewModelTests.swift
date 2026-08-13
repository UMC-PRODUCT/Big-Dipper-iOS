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

/// 분류기 대역. `result` 를 `nil` 로 두면 실패를 던진다.
private final class StubClassifier: ThreadClassifying, @unchecked Sendable {

    let isAvailable: Bool
    var result: ThreadClassification?
    private(set) var callCount = 0

    init(isAvailable: Bool = true, result: ThreadClassification? = StubClassifier.defaultResult) {
        self.isAvailable = isAvailable
        self.result = result
    }

    static let defaultResult = ThreadClassification(
        category: .study,
        icon: "📚",
        reason: "매주 모여 공부한다는 내용이 있어요."
    )

    func classify(title: String, description: String) async throws -> ThreadClassification {
        callCount += 1
        guard let result else { throw ThreadClassificationError.unavailable }
        return result
    }
}

// MARK: - Tests

@Suite("커뮤니티 스레드 생성 ViewModel")
@MainActor
struct CommunityThreadCreateViewModelTests {

    // MARK: - 제출 조건

    @Test("제목·특징 중 하나라도 비면 제출할 수 없다")
    func requiresTitleAndDescription() {
        let viewModel = makeViewModel()

        #expect(!viewModel.canSubmit)

        viewModel.title = "iOS 스터디"
        #expect(!viewModel.canSubmit)

        viewModel.threadDescription = "매주 화요일 8시"
        #expect(viewModel.canSubmit)
    }

    @Test("공백만 채운 입력은 제출 조건을 채우지 못한다")
    func rejectsWhitespaceOnlyInput() {
        let viewModel = makeViewModel()

        viewModel.title = "   \n"
        viewModel.threadDescription = "\t "

        #expect(!viewModel.canSubmit)
    }

    @Test("아이콘은 비어도 제출할 수 있다 — 카테고리 기본 이모지가 채운다")
    func iconIsOptionalForSubmission() {
        let viewModel = makeViewModel()

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
        let viewModel = makeViewModel()

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
        let viewModel = makeViewModel()

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
        let viewModel = makeViewModel(useCase: useCase)
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
        let viewModel = makeViewModel(useCase: useCase)
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
        let viewModel = makeViewModel(useCase: useCase)

        let thread = await viewModel.submit()

        #expect(thread == nil)
        #expect(useCase.calls.isEmpty)
    }

    // MARK: - 자동 분류

    @Test("분류 결과가 카테고리·아이콘에 그대로 반영된다")
    func appliesClassificationToForm() async {
        let viewModel = makeViewModel()
        viewModel.title = "iOS 스터디"
        viewModel.threadDescription = "매주 화요일 8시에 모여서 공부해요"

        await viewModel.classify()

        #expect(viewModel.classification.value == StubClassifier.defaultResult)
        #expect(viewModel.category == .study)
        #expect(viewModel.icon == "📚")
        #expect(viewModel.recommendedCategory == .study)
    }

    @Test("특징이 비면 분류하지 않는다")
    func doesNotClassifyWithoutDescription() async {
        let classifier = StubClassifier()
        let viewModel = makeViewModel(classifier: classifier)
        viewModel.title = "iOS 스터디"

        #expect(!viewModel.canClassify)
        await viewModel.classify()

        #expect(classifier.callCount == 0)
        #expect(viewModel.classification.isIdle)
    }

    @Test("미지원 기기에서는 분류가 잠기고 카테고리는 자유로 남는다")
    func keepsFreeCategoryWhenUnavailable() async {
        let classifier = StubClassifier(isAvailable: false)
        let viewModel = makeViewModel(classifier: classifier)
        viewModel.title = "iOS 스터디"
        viewModel.threadDescription = "매주 화요일 8시에 모여서 공부해요"

        #expect(!viewModel.isClassificationAvailable)
        #expect(!viewModel.canClassify)

        await viewModel.classify()

        #expect(classifier.callCount == 0)
        #expect(viewModel.category == .free)
        // 분류를 못 해도 제출은 열려 있어야 한다 — 수동 카테고리로 계속 진행하는 경로.
        #expect(viewModel.canSubmit)
    }

    @Test("분류가 실패해도 폼은 그대로 제출할 수 있다")
    func keepsFormUsableWhenClassificationFails() async {
        let classifier = StubClassifier(result: nil)
        let viewModel = makeViewModel(classifier: classifier)
        viewModel.title = "iOS 스터디"
        viewModel.threadDescription = "매주 화요일 8시에 모여서 공부해요"

        await viewModel.classify()

        #expect(viewModel.classificationErrorMessage != nil)
        #expect(viewModel.recommendedCategory == nil)
        #expect(viewModel.canSubmit)
        // 실패 뒤에도 재시도 버튼은 살아 있어야 한다.
        #expect(viewModel.canClassify)
    }

    @Test("다시 분류하면 바뀐 결과로 갱신된다")
    func reclassifyUpdatesResult() async {
        let classifier = StubClassifier()
        let viewModel = makeViewModel(classifier: classifier)
        viewModel.title = "질문방"
        viewModel.threadDescription = "궁금한 걸 물어보는 방이에요"

        await viewModel.classify()
        classifier.result = ThreadClassification(
            category: .qna,
            icon: "❓",
            reason: "질문을 주고받는 방이라고 적혀 있어요."
        )
        await viewModel.classify()

        #expect(classifier.callCount == 2)
        #expect(viewModel.category == .qna)
        #expect(viewModel.icon == "❓")
        #expect(viewModel.recommendedCategory == .qna)
    }

    @Test("분류가 채운 카테고리·아이콘은 수동으로 덮어쓸 수 있다")
    func allowsManualOverrideAfterClassification() async {
        let viewModel = makeViewModel()
        viewModel.title = "iOS 스터디"
        viewModel.threadDescription = "매주 화요일 8시에 모여서 공부해요"

        await viewModel.classify()
        viewModel.category = .project
        viewModel.icon = "🚀"

        #expect(viewModel.category == .project)
        #expect(viewModel.icon == "🚀")
        // 추천 배지는 분류 결과를 계속 가리킨다 — 선택 상태와 다른 정보다.
        #expect(viewModel.recommendedCategory == .study)
    }
}

// MARK: - Fixture

/// `useCase` 기본값을 `nil` 로 두는 이유: 기본 인자 식은 호출 지점에서 평가되는데 그 자리가
/// nonisolated 라, `@MainActor` 대역을 기본값에 그대로 쓰면 격리 위반이 된다.
@MainActor
private func makeViewModel(
    useCase: StubCreateUseCase? = nil,
    classifier: StubClassifier = StubClassifier()
) -> CommunityThreadCreateViewModel {
    CommunityThreadCreateViewModel(
        useCase: useCase ?? StubCreateUseCase(),
        classifier: classifier
    )
}

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
