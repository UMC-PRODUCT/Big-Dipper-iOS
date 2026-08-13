//
//  CommunityThreadCreateViewModel.swift
//  CommunityPresentation
//

import Foundation
import Observation
import CommunityDomain
import UMCFoundation

/// 스레드 생성 폼 상태 기계.
///
/// 실패는 전역 Alert 이 아니라 화면 안 인라인으로 보여 준다 — 흐름을 끊으면 사용자가 방금 쓴
/// 제목·특징을 잃는다(에러 처리 규약: 검증·도메인 실패는 `Loadable`).
///
/// 입력 상한은 `didSet` 에서 자르기 때문에 화면에 보이는 값이 곧 전송될 값이다.
@Observable
@MainActor
public final class CommunityThreadCreateViewModel {

    // MARK: - Property

    public var title = "" {
        didSet { clamp(\.title, max: CommunityThreadCreateRule.titleMaxLength) }
    }

    /// 시안의 "스레드 특징". 서버 필드명은 `description` 이지만, 프로퍼티명으로 쓰면
    /// `String(describing:)` 이 보는 이름과 겹쳐 헷갈린다.
    public var threadDescription = "" {
        didSet { clamp(\.threadDescription, max: CommunityThreadCreateRule.descriptionMaxLength) }
    }

    /// 사용자가 고른 이모지. 비워 두면 카테고리 기본 이모지로 생성된다.
    public var icon = "" {
        didSet {
            let normalized = CommunityThreadCreateRule.normalizedIcon(icon)
            guard normalized != icon else { return }
            icon = normalized
        }
    }

    public var category: CommunityThreadCategory = .free
    public var isCategorySheetPresented = false

    public private(set) var state: Loadable<CommunityThread> = .idle

    private let useCase: CommunityThreadCreateUseCaseProtocol

    // MARK: - Init

    public init(useCase: CommunityThreadCreateUseCaseProtocol) {
        self.useCase = useCase
    }

    // MARK: - Computed Property

    /// 제목·특징 둘 다 채워졌을 때만 제출한다. 아이콘은 비어도 카테고리 기본값이 채우므로
    /// 활성 조건에 넣지 않는다.
    public var canSubmit: Bool {
        !trimmed(title).isEmpty && !trimmed(threadDescription).isEmpty && !state.isLoading
    }

    /// 아이콘 칸에 흐리게 띄울 값. 비워 둔 채 만들면 이 이모지로 생성된다.
    public var iconPlaceholder: String {
        category.defaultIcon
    }

    /// 인라인으로 띄울 실패 메시지.
    public var submitErrorMessage: String? {
        guard case .failed(let error) = state else { return nil }
        return error.userMessage
    }

    // MARK: - Function

    /// - Returns: 생성된 스레드. 실패하거나 제출 조건을 못 채우면 `nil` — 화면은 그대로 둔다.
    public func submit() async -> CommunityThread? {
        guard canSubmit else { return nil }

        state = .loading

        do {
            let thread = try await useCase.create(
                title: title,
                description: threadDescription,
                category: category,
                icon: icon
            )
            state = .loaded(thread)
            return thread
        } catch {
            state = .failed(AppError.from(error))
            return nil
        }
    }

    // MARK: - Private Function

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 상한을 넘긴 입력만 되쓴다 — 매번 대입하면 `didSet` 이 무한히 재진입한다.
    private func clamp(
        _ keyPath: ReferenceWritableKeyPath<CommunityThreadCreateViewModel, String>,
        max limit: Int
    ) {
        let clamped = CommunityThreadCreateRule.clamped(self[keyPath: keyPath], max: limit)
        guard clamped != self[keyPath: keyPath] else { return }
        self[keyPath: keyPath] = clamped
    }
}
