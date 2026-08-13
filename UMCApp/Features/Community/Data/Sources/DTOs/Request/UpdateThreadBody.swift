//
//  UpdateThreadBody.swift
//  CommunityData
//

import Foundation

/// `PATCH /api/v1/community/threads/{threadId}` 본문.
///
/// **부분 수정이다.** 서버 `UpdateCommunityThreadRequest` 가 `@JsonSetter` 로 필드별 `*Present`
/// 플래그를 세우기 때문에 **JSON 에 키가 있는 필드만** 갱신된다. 즉 키를 빼는 것과 `null` 을
/// 보내는 것의 의미가 다르다 — `{"description": null}` 은 "설명을 지운다" 로 해석된다.
///
/// 그래서 `encode(to:)` 를 직접 쓴다. 합성 구현도 옵셔널을 `encodeIfPresent` 로 내보내지만,
/// 이 계약에서는 키 유무가 곧 의미라 암묵적 동작에 기대지 않고 눈에 보이게 둔다.
public struct UpdateThreadBody: Encodable {

    // MARK: - Property

    public let title: String?
    public let description: String?
    public let category: String?
    public let icon: String?

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case title
        case description
        case category
        case icon
    }

    // MARK: - Init

    public init(
        title: String? = nil,
        description: String? = nil,
        category: String? = nil,
        icon: String? = nil
    ) {
        self.title = title
        self.description = description
        self.category = category
        self.icon = icon
    }

    // MARK: - Computed Property

    /// 바꿀 필드가 하나도 없는지. 전부 `nil` 이면 `{}` 를 보내게 되므로 호출 전에 걸러야 한다.
    public var isEmpty: Bool {
        title == nil && description == nil && category == nil && icon == nil
    }

    // MARK: - Function

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(icon, forKey: .icon)
    }
}
