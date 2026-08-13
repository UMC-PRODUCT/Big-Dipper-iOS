//
//  CommunityThreadCreateUseCase.swift
//  CommunityDomain
//

import Foundation

// MARK: - Rule

/// 스레드 생성 입력 규칙. 서버 `CreateCommunityThreadRequest` 제약과 1:1 로 맞춘다.
///
/// 폼(입력 제한·버튼 활성화)과 UseCase(전송 직전 정규화)가 같은 규칙을 봐야 하므로 한 곳에 둔다.
public enum CommunityThreadCreateRule {

    /// 서버 `@CodePointLength(max = 80)`.
    public static let titleMaxLength = 80
    /// 서버 `@CodePointLength(max = 500)`.
    public static let descriptionMaxLength = 500

    /// 코드포인트 기준으로 자른다. `String.prefix` 는 grapheme 단위라 서버 계산과 어긋난다.
    ///
    /// 입력 중에도 쓰이므로 공백은 털지 않는다 — 털면 단어 사이 스페이스를 칠 수 없다.
    public static func clamped(_ text: String, max limit: Int) -> String {
        guard text.unicodeScalars.count > limit else { return text }
        return String(text.unicodeScalars.prefix(limit).map(Character.init))
    }

    /// 서버 `@SingleGrapheme` 선반영 — grapheme 하나만 남기고, 그게 이모지가 아니면 버린다.
    ///
    /// 마지막 글자를 남기는 이유는 이미 채워진 칸에 새 이모지를 고르면 교체되는 게
    /// 자연스럽기 때문이다. ZWJ 조합(👨‍👩‍👧)은 `Character` 하나라 그대로 통과한다.
    public static func normalizedIcon(_ icon: String) -> String {
        guard let last = icon.last,
              last.isEmojiIcon,
              String(last).unicodeScalars.count <= iconMaxCodePoints else { return "" }
        return String(last)
    }

    /// 서버 `@CodePointLength(max = 32)`. 사람이 만들 수 있는 이모지는 한참 아래지만
    /// 조합 문자를 잔뜩 붙인 grapheme 하나가 상한을 넘길 수 있어 함께 본다.
    private static let iconMaxCodePoints = 32
}

extension Character {

    /// 표준 유니코드 이모지인지.
    ///
    /// `isEmoji` 만 보면 숫자·`#`·`*` 까지 통과한다(키캡 base 라서). 기본 이모지 표현이거나
    /// 변이 선택자(U+FE0F)로 이모지 표현을 명시한 경우만 인정한다.
    var isEmojiIcon: Bool {
        guard let first = unicodeScalars.first else { return false }
        return first.properties.isEmojiPresentation
            || (first.properties.isEmoji && unicodeScalars.contains { $0.value == 0xFE0F })
    }
}

// MARK: - UseCase

public protocol CommunityThreadCreateUseCaseProtocol: Sendable {

    /// - Parameter icon: 비었으면 카테고리 기본 이모지로 채운다. 서버는 `icon` 을 필수로 받는다.
    /// - Returns: 서버가 돌려준 상세. 리스트에 바로 꽂을 수 있다.
    func create(
        title: String,
        description: String,
        category: CommunityThreadCategory,
        icon: String
    ) async throws -> CommunityThread
}

public struct CommunityThreadCreateUseCase: CommunityThreadCreateUseCaseProtocol {

    // MARK: - Property

    private let repository: CommunityThreadRepositoryProtocol

    // MARK: - Init

    public init(repository: CommunityThreadRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    /// 폼이 이미 막지만 여기서 한 번 더 정규화한다 — 붙여넣기로 상한을 넘긴 값이 400 으로
    /// 돌아오는 것보다 잘라서 통과시키는 게 낫다(검색어 정규화와 같은 판단).
    public func create(
        title: String,
        description: String,
        category: CommunityThreadCategory,
        icon: String
    ) async throws -> CommunityThread {
        let normalizedIcon = CommunityThreadCreateRule.normalizedIcon(icon)

        return try await repository.createThread(
            title: clamped(title, max: CommunityThreadCreateRule.titleMaxLength),
            description: clamped(description, max: CommunityThreadCreateRule.descriptionMaxLength),
            category: category.rawValue,
            icon: normalizedIcon.isEmpty ? category.defaultIcon : normalizedIcon
        )
    }

    // MARK: - Private Function

    private func clamped(_ text: String, max limit: Int) -> String {
        CommunityThreadCreateRule.clamped(
            text.trimmingCharacters(in: .whitespacesAndNewlines),
            max: limit
        )
    }
}
