//
//  CommunityThreadEditUseCase.swift
//  CommunityDomain
//

import Foundation

/// 스레드 수정·삭제 계약.
///
/// 입력 규칙은 생성과 같은 서버 제약을 보므로 ``CommunityThreadCreateRule`` 을 그대로 쓴다.
public protocol CommunityThreadEditUseCaseProtocol: Sendable {

    /// 부분 수정. **`nil` 은 "안 바꾼다"** 로 그대로 전달된다.
    ///
    /// 특징만 넘기면 카테고리는 서버에 남아 있는 값 그대로다 — 특징을 고쳤다고 카테고리가
    /// 저절로 바뀌면 사용자가 놀란다(재분류는 명시적으로 눌러야 한다).
    ///
    /// - Parameter icon: grapheme 하나. 이모지가 아니면 버려지고 아이콘은 갱신되지 않는다.
    /// - Returns: 갱신된 스레드 상세. 리스트 행에 그대로 꽂을 수 있다.
    func update(
        threadId: String,
        title: String?,
        description: String?,
        category: CommunityThreadCategory?,
        icon: String?
    ) async throws -> CommunityThread

    /// 되돌릴 수 없다. 화면은 호출 전에 반드시 확인을 받는다.
    func delete(threadId: String) async throws
}

public struct CommunityThreadEditUseCase: CommunityThreadEditUseCaseProtocol {

    // MARK: - Property

    private let repository: CommunityThreadRepositoryProtocol

    // MARK: - Init

    public init(repository: CommunityThreadRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    /// 폼이 이미 막지만 전송 직전에 한 번 더 정규화한다 — 붙여넣기로 상한을 넘긴 값이 400 으로
    /// 돌아오는 것보다 잘라서 통과시키는 게 낫다(생성과 같은 판단).
    public func update(
        threadId: String,
        title: String?,
        description: String?,
        category: CommunityThreadCategory?,
        icon: String?
    ) async throws -> CommunityThread {
        let normalizedIcon = icon.map(CommunityThreadCreateRule.normalizedIcon)

        return try await repository.updateThread(
            threadId: threadId,
            title: title.map { clamped($0, max: CommunityThreadCreateRule.titleMaxLength) },
            description: description.map {
                clamped($0, max: CommunityThreadCreateRule.descriptionMaxLength)
            },
            category: category?.rawValue,
            // 이모지가 아닌 입력이 빈 문자열로 정규화되면 서버 `@SingleGrapheme` 에 걸린다.
            // 아이콘만 지우는 요청은 계약에 없으므로 키째 빼서 기존 아이콘을 남긴다.
            icon: normalizedIcon.flatMap { $0.isEmpty ? nil : $0 }
        )
    }

    public func delete(threadId: String) async throws {
        try await repository.deleteThread(threadId: threadId)
    }

    // MARK: - Private Function

    private func clamped(_ text: String, max limit: Int) -> String {
        CommunityThreadCreateRule.clamped(
            text.trimmingCharacters(in: .whitespacesAndNewlines),
            max: limit
        )
    }
}
