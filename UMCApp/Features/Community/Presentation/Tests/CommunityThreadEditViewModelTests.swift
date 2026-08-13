//
//  CommunityThreadEditViewModelTests.swift
//  CommunityPresentationTests
//

import Foundation
import Testing
import CommunityDomain
import UMCFoundation
@testable import CommunityPresentation

// MARK: - Test Double

@MainActor
private final class StubEditUseCase: CommunityThreadEditUseCaseProtocol {

    /// `nil` 은 "그 필드는 보내지 않았다" 는 뜻이다 — 부분 수정 검증의 핵심이라 그대로 기록한다.
    struct UpdateCall: Equatable {
        let threadId: String
        let title: String?
        let description: String?
        let category: CommunityThreadCategory?
        let icon: String?
    }

    var shouldFail = false
    private(set) var updateCalls: [UpdateCall] = []
    private(set) var deleteCalls: [String] = []

    func update(
        threadId: String,
        title: String?,
        description: String?,
        category: CommunityThreadCategory?,
        icon: String?
    ) async throws -> CommunityThread {
        updateCalls.append(
            UpdateCall(
                threadId: threadId,
                title: title,
                description: description,
                category: category,
                icon: icon
            )
        )
        if shouldFail { throw AppError.unknown(message: "수정 실패") }
        return makeEditableThread(title: title ?? "iOS 스터디")
    }

    func delete(threadId: String) async throws {
        deleteCalls.append(threadId)
        if shouldFail { throw AppError.unknown(message: "삭제 실패") }
    }
}

private final class StubEditClassifier: ThreadClassifying, @unchecked Sendable {

    static let result = ThreadClassification(
        category: .project,
        icon: "🚀",
        reason: "결과물을 만드는 모임이라고 적혀 있어요."
    )

    let isAvailable: Bool
    private(set) var callCount = 0

    init(isAvailable: Bool = true) {
        self.isAvailable = isAvailable
    }

    func classify(title: String, description: String) async throws -> ThreadClassification {
        callCount += 1
        return Self.result
    }
}

/// 분류가 도는 **중간** 상태를 관찰하려고 호출을 붙잡아 두는 대역.
///
/// `release()` 를 부를 때까지 `classify` 가 멈춰 있어, 그동안 저장 버튼이 잠기는지 확인할 수 있다.
private final class GateClassifier: ThreadClassifying, @unchecked Sendable {

    let isAvailable = true

    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() {
        (stream, continuation) = AsyncStream.makeStream()
    }

    /// 붙잡아 둔 분류를 진행시킨다. 먼저 불러도 값이 버퍼에 남아 신호를 놓치지 않는다.
    func release() {
        continuation.yield()
    }

    func classify(title: String, description: String) async throws -> ThreadClassification {
        var iterator = stream.makeAsyncIterator()
        await iterator.next()
        return StubEditClassifier.result
    }
}

// MARK: - Tests

@Suite("커뮤니티 스레드 편집 ViewModel")
@MainActor
struct CommunityThreadEditViewModelTests {

    // MARK: - 프리필 · dirty 판정

    @Test("서버 값이 폼에 그대로 프리필된다")
    func prefillsFromThread() {
        let viewModel = makeViewModel()

        #expect(viewModel.title == "iOS 스터디")
        #expect(viewModel.threadDescription == "매주 화요일 8시에 모여요")
        #expect(viewModel.category == .study)
        #expect(viewModel.icon == "🔥")
    }

    @Test("아무것도 바꾸지 않으면 저장할 수 없다")
    func disablesSaveWithoutChanges() {
        let viewModel = makeViewModel()

        #expect(!viewModel.hasChanges)
        #expect(!viewModel.canSubmit)
    }

    @Test("값을 되돌리면 저장이 다시 잠긴다")
    func disablesSaveAfterRevert() {
        let viewModel = makeViewModel()

        viewModel.title = "iOS 스터디 시즌2"
        #expect(viewModel.canSubmit)

        viewModel.title = "iOS 스터디"
        #expect(!viewModel.canSubmit)
    }

    @Test("앞뒤 공백만 붙인 입력은 변경으로 보지 않는다")
    func ignoresWhitespaceOnlyEdit() {
        let viewModel = makeViewModel()

        viewModel.title = "  iOS 스터디  "

        #expect(!viewModel.hasChanges)
    }

    @Test("제목·특징을 비우면 저장할 수 없다")
    func requiresTitleAndDescription() {
        let viewModel = makeViewModel()

        viewModel.title = ""
        #expect(viewModel.hasChanges)
        #expect(!viewModel.canSubmit)
    }

    // MARK: - 부분 수정

    @Test("특징만 고치면 카테고리는 보내지 않는다 — 서버 값이 유지된다")
    func sendsOnlyChangedFields() async {
        let useCase = StubEditUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        viewModel.threadDescription = "매주 목요일 9시에 모여요"
        _ = await viewModel.submit()

        #expect(
            useCase.updateCalls == [
                StubEditUseCase.UpdateCall(
                    threadId: "10",
                    title: nil,
                    description: "매주 목요일 9시에 모여요",
                    category: nil,
                    icon: nil
                )
            ]
        )
    }

    @Test("아이콘을 비우면 카테고리 기본 이모지로 저장된다")
    func fallsBackToCategoryIcon() async {
        let useCase = StubEditUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        viewModel.icon = ""
        _ = await viewModel.submit()

        #expect(useCase.updateCalls.first?.icon == CommunityThreadCategory.study.defaultIcon)
    }

    @Test("실패하면 인라인 에러가 뜨고 입력값은 그대로 남는다")
    func keepsInputOnFailure() async {
        let useCase = StubEditUseCase()
        useCase.shouldFail = true
        let viewModel = makeViewModel(useCase: useCase)

        viewModel.title = "iOS 스터디 시즌2"
        let updated = await viewModel.submit()

        #expect(updated == nil)
        #expect(viewModel.submitErrorMessage != nil)
        #expect(viewModel.title == "iOS 스터디 시즌2")
        #expect(viewModel.canSubmit)
    }

    @Test("바뀐 게 없으면 UseCase 를 부르지 않는다")
    func doesNotSubmitWithoutChanges() async {
        let useCase = StubEditUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        let updated = await viewModel.submit()

        #expect(updated == nil)
        #expect(useCase.updateCalls.isEmpty)
    }

    // MARK: - 재분류

    @Test("특징을 고치면 재분류를 권하고, 한 번 돌리면 넛지가 사라진다")
    func suggestsReclassifyAfterDescriptionEdit() async {
        let viewModel = makeViewModel()

        #expect(!viewModel.isReclassifySuggested)

        viewModel.threadDescription = "이제 사이드 프로젝트를 만들어요"
        #expect(viewModel.isReclassifySuggested)

        await viewModel.classify()
        #expect(!viewModel.isReclassifySuggested)
        #expect(viewModel.category == .project)
        #expect(viewModel.icon == "🚀")
    }

    @Test("제목만 고치면 재분류를 권하지 않는다")
    func doesNotSuggestReclassifyForTitleEdit() {
        let viewModel = makeViewModel()

        viewModel.title = "iOS 스터디 시즌2"

        #expect(!viewModel.isReclassifySuggested)
    }

    @Test("재분류가 도는 동안 저장이 잠기고, 끝나면 풀린다")
    func locksSaveWhileClassifying() async {
        let classifier = GateClassifier()
        let viewModel = makeViewModel(classifier: classifier)
        viewModel.threadDescription = "이제 사이드 프로젝트를 만들어요"
        #expect(viewModel.canSubmit)

        let task = Task { await viewModel.classify() }
        while !viewModel.classification.isLoading {
            await Task.yield()
        }

        #expect(!viewModel.canSubmit)

        classifier.release()
        await task.value

        #expect(viewModel.canSubmit)
    }

    @Test("미지원 기기에서는 재분류가 잠기고 카테고리가 유지된다")
    func keepsCategoryWhenClassificationUnavailable() async {
        let classifier = StubEditClassifier(isAvailable: false)
        let viewModel = makeViewModel(classifier: classifier)

        viewModel.threadDescription = "이제 사이드 프로젝트를 만들어요"

        #expect(!viewModel.canClassify)
        #expect(!viewModel.isReclassifySuggested)

        await viewModel.classify()

        #expect(classifier.callCount == 0)
        #expect(viewModel.category == .study)
        // 이모지 변경과 저장은 계속 열려 있어야 한다.
        viewModel.icon = "🚀"
        #expect(viewModel.canSubmit)
    }

    // MARK: - 삭제

    @Test("확인 알럿을 거치지 않으면 삭제되지 않는다")
    func requiresConfirmationBeforeDelete() async {
        let useCase = StubEditUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        viewModel.confirmDelete()

        #expect(viewModel.alertPrompt != nil)
        #expect(useCase.deleteCalls.isEmpty)
        #expect(!viewModel.didDelete)
    }

    @Test("확인하면 삭제되고 화면이 닫힐 신호가 선다")
    func deletesAfterConfirmation() async {
        let useCase = StubEditUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        viewModel.confirmDelete()
        viewModel.alertPrompt?.positiveBtnAction?()
        await waitUntil { viewModel.didDelete }

        #expect(useCase.deleteCalls == ["10"])
    }

    @Test("삭제에 실패하면 화면을 닫지 않는다")
    func keepsScreenWhenDeleteFails() async {
        let useCase = StubEditUseCase()
        useCase.shouldFail = true
        let viewModel = makeViewModel(useCase: useCase)

        viewModel.confirmDelete()
        viewModel.alertPrompt?.positiveBtnAction?()
        await waitUntil { !useCase.deleteCalls.isEmpty }

        #expect(!viewModel.didDelete)
    }

    // MARK: - Function

    private func waitUntil(_ condition: () -> Bool) async {
        while !condition() {
            await Task.yield()
        }
    }
}

// MARK: - Fixture

@MainActor
private func makeViewModel(
    useCase: StubEditUseCase? = nil,
    classifier: ThreadClassifying = StubEditClassifier()
) -> CommunityThreadEditViewModel {
    CommunityThreadEditViewModel(
        thread: makeEditableThread(),
        useCase: useCase ?? StubEditUseCase(),
        classifier: classifier,
        errorHandler: ErrorHandler()
    )
}

private func makeEditableThread(title: String = "iOS 스터디") -> CommunityThread {
    CommunityThread(
        id: "10",
        title: title,
        description: "매주 화요일 8시에 모여요",
        category: .study,
        // 카테고리 기본 이모지(📚)와 다른 값이어야 "비우면 기본값으로" 를 검증할 수 있다.
        icon: "🔥",
        memberCount: "4",
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
