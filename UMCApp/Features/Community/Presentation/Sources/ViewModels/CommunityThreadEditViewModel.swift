//
//  CommunityThreadEditViewModel.swift
//  CommunityPresentation
//

import Foundation
import Observation
import CommunityDomain
import UMCFoundation

/// 스레드 편집 폼 상태 기계.
///
/// 생성 폼과 입력 규칙·상한이 같아 ``CommunityThreadCreateRule`` 을 그대로 쓰지만, 결정적으로
/// 다른 점이 둘 있다.
///
/// 1. **바뀐 게 없으면 저장할 수 없다.** 무엇이 바뀌었는지는 진입 시점의 서버 값(`original`)과
///    비교해 판정하고, 바뀐 필드만 PATCH 본문에 실어 나머지를 서버에 남긴다.
/// 2. **특징을 고쳐도 자동으로 재분류하지 않는다.** 저절로 카테고리가 바뀌면 사용자가 놀란다 —
///    대신 "다시 분류" 를 권하는 넛지만 띄우고, 실행은 사용자가 누를 때만 한다.
///
/// 저장 실패는 전역 Alert 이 아니라 화면 안 인라인이다(방금 고친 값을 잃지 않는다). 반대로
/// 삭제 실패는 화면이 이미 사라진 뒤일 수 있어 `ErrorHandler` 로 올린다 — 나가기·강퇴와 같다.
@Observable
@MainActor
public final class CommunityThreadEditViewModel {

    // MARK: - Property

    public var title = "" {
        didSet { clamp(\.title, max: CommunityThreadCreateRule.titleMaxLength) }
    }

    /// 시안의 "스레드 특징". 서버 필드명은 `description` 이다(생성 폼과 같은 이유로 개명).
    public var threadDescription = "" {
        didSet { clamp(\.threadDescription, max: CommunityThreadCreateRule.descriptionMaxLength) }
    }

    /// 비워 두면 카테고리 기본 이모지로 저장된다 — 생성 폼과 같은 규칙이다.
    public var icon = "" {
        didSet {
            let normalized = CommunityThreadCreateRule.normalizedIcon(icon)
            guard normalized != icon else { return }
            icon = normalized
        }
    }

    public var category: CommunityThreadCategory
    public var isCategorySheetPresented = false

    public private(set) var state: Loadable<CommunityThread> = .idle
    public private(set) var classification: Loadable<ThreadClassification> = .idle

    /// 삭제가 확정된 상태. View 가 이걸 보고 리스트로 되돌린다.
    public private(set) var didDelete = false

    public var alertPrompt: AlertPrompt?

    /// 진입 시점의 서버 값. dirty 판정과 PATCH 본문 구성의 유일한 기준이다.
    public let original: CommunityThread

    private let useCase: CommunityThreadEditUseCaseProtocol
    private let classifier: ThreadClassifying
    private let errorHandler: ErrorHandler

    /// 마지막으로 분류를 돌린 특징. 넛지를 한 번 따르고 나면 같은 문구로 다시 조르지 않는다.
    @ObservationIgnored private var lastClassifiedDescription: String?

    // MARK: - Init

    /// - Parameter thread: 리스트·상세가 서버에서 받아 둔 값. 이 값이 곧 폼의 프리필이다.
    public init(
        thread: CommunityThread,
        useCase: CommunityThreadEditUseCaseProtocol,
        classifier: ThreadClassifying,
        errorHandler: ErrorHandler
    ) {
        self.original = thread
        self.useCase = useCase
        self.classifier = classifier
        self.errorHandler = errorHandler
        self.category = thread.category
        self.title = thread.title
        self.threadDescription = thread.description
        self.icon = thread.icon
    }

    // MARK: - Computed Property

    /// 저장했을 때 실제로 서버에 남을 아이콘. 빈 칸은 카테고리 기본 이모지가 채운다.
    public var effectiveIcon: String {
        icon.isEmpty ? category.defaultIcon : icon
    }

    /// 아이콘 칸에 흐리게 띄울 값.
    public var iconPlaceholder: String {
        category.defaultIcon
    }

    /// 진입 이후 무엇이든 바뀌었는지 (#10 저장 비활성의 근거).
    public var hasChanges: Bool {
        changedTitle != nil
            || changedDescription != nil
            || changedCategory != nil
            || changedIcon != nil
    }

    /// 저장 가능 조건. 재분류가 도는 동안에는 잠근다 — 분류가 끝나면 카테고리·아이콘이 바뀌는데
    /// 그 직전 값으로 저장되면 사용자가 방금 본 결과와 저장된 값이 어긋난다 (#12).
    public var canSubmit: Bool {
        hasChanges
            && !trimmed(title).isEmpty
            && !trimmed(threadDescription).isEmpty
            && !state.isLoading
            && !classification.isLoading
    }

    /// 인라인으로 띄울 저장 실패 메시지.
    public var submitErrorMessage: String? {
        guard case .failed(let error) = state else { return nil }
        return error.userMessage
    }

    // MARK: - Classification

    /// 이 기기에서 자동 분류를 시도해 볼 수 있는지. `false` 면 카드가 수동 선택 안내로 바뀐다(#13).
    public var isClassificationAvailable: Bool {
        classifier.isAvailable
    }

    public var canClassify: Bool {
        isClassificationAvailable
            && !trimmed(threadDescription).isEmpty
            && !classification.isLoading
    }

    /// "다시 분류" 넛지를 띄울지 (#11).
    ///
    /// 특징을 고친 뒤 아직 그 문구로 분류를 돌리지 않은 동안에만 띄운다. 미지원 기기에서는
    /// 권할 수 있는 행동이 없어 `canClassify` 에서 함께 걸린다.
    public var isReclassifySuggested: Bool {
        canClassify
            && trimmed(threadDescription) != original.description
            && lastClassifiedDescription != trimmed(threadDescription)
    }

    /// 카테고리 시트에 "AI 추천" 배지를 붙일 항목.
    public var recommendedCategory: CommunityThreadCategory? {
        classification.value?.category
    }

    public var classificationErrorMessage: String? {
        guard case .failed(let error) = classification else { return nil }
        return error.errorDescription ?? error.userMessage
    }

    // MARK: - Function

    /// 바뀐 필드만 PATCH 로 보낸다.
    ///
    /// - Returns: 갱신된 스레드. 실패하거나 저장 조건을 못 채우면 `nil` — 화면은 그대로 둔다.
    public func submit() async -> CommunityThread? {
        guard canSubmit else { return nil }

        state = .loading

        do {
            let updated = try await useCase.update(
                threadId: original.id,
                title: changedTitle,
                description: changedDescription,
                category: changedCategory,
                icon: changedIcon
            )
            state = .loaded(updated)
            return updated
        } catch {
            state = .failed(AppError.from(error))
            return nil
        }
    }

    /// 삭제는 되돌릴 수 없어 확인을 먼저 받는다 (절대 규칙 — 파괴적 작업은 AlertPrompt).
    public func confirmDelete() {
        alertPrompt = AlertPrompt(
            title: "'\(original.title)' 스레드를 삭제할까요?",
            message: "대화 내용과 참여자가 모두 사라져요. 되돌릴 수 없어요.",
            positiveBtnTitle: "삭제",
            positiveBtnAction: { [weak self] in
                Task { @MainActor in await self?.delete() }
            },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: true
        )
    }

    /// 제목·특징으로 카테고리와 아이콘을 다시 정한다.
    ///
    /// 결과는 폼에 바로 반영한다 — 카드에만 띄우고 옮겨 담게 하면 "분류" 가 아니라 제안이 되고,
    /// 옮기지 않은 채 저장하는 사고가 난다. 마음에 안 들면 시트와 이모지 칸에서 덮어쓸 수 있다.
    public func classify() async {
        guard canClassify else { return }
        classification = .loading

        do {
            let result = try await classifier.classify(
                title: title,
                description: threadDescription
            )
            classification = .loaded(result)
            category = result.category
            icon = result.icon
            lastClassifiedDescription = trimmed(threadDescription)
        } catch {
            // 취소는 화면을 벗어난 정상 흐름이다. 실패 카드로 바꾸면 돌아왔을 때 에러부터 보인다.
            guard !(error is CancellationError) else { return }
            classification = .failed(AppError.from(error))
        }
    }

    // MARK: - Private Function

    /// 아래 4개는 "바뀌었으면 값, 아니면 `nil`" 이다. 그대로 PATCH 본문이 되므로 dirty 판정과
    /// 전송 내용이 절대 어긋나지 않는다.
    private var changedTitle: String? {
        let value = trimmed(title)
        return value == original.title ? nil : value
    }

    private var changedDescription: String? {
        let value = trimmed(threadDescription)
        return value == original.description ? nil : value
    }

    private var changedCategory: CommunityThreadCategory? {
        category == original.category ? nil : category
    }

    /// 서버에 저장된 아이콘이 비어 있으면 화면에는 카테고리 기본 이모지가 보인다. 비교 기준을
    /// `displayIcon` 으로 맞춰야 "보이는 것과 같은데 변경으로 잡히는" 오판이 없다.
    private var changedIcon: String? {
        effectiveIcon == original.displayIcon ? nil : effectiveIcon
    }

    private func delete() async {
        do {
            try await useCase.delete(threadId: original.id)
            didDelete = true
        } catch {
            errorHandler.handle(
                error,
                context: ErrorContext(feature: "Community", action: "deleteThread")
            )
        }
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 상한을 넘긴 입력만 되쓴다 — 매번 대입하면 `didSet` 이 무한히 재진입한다.
    private func clamp(
        _ keyPath: ReferenceWritableKeyPath<CommunityThreadEditViewModel, String>,
        max limit: Int
    ) {
        let clamped = CommunityThreadCreateRule.clamped(self[keyPath: keyPath], max: limit)
        guard clamped != self[keyPath: keyPath] else { return }
        self[keyPath: keyPath] = clamped
    }
}

// MARK: - ThreadClassificationPresenting

extension CommunityThreadEditViewModel: ThreadClassificationPresenting {}
