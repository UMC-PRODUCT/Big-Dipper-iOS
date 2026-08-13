//
//  CreateThreadBody.swift
//  CommunityData
//

import Foundation

/// `POST /api/v1/community/threads` 본문.
///
/// `memberIds` 는 싣지 않는다 — 서버가 미전달을 빈 배열로 받고, 참여자 선택 UI 는 이 폼을
/// 재사용하는 후속 작업이다. 개설자는 서버가 자동으로 `OWNER` 로 넣는다.
public struct CreateThreadBody: Encodable {

    // MARK: - Property

    public let title: String
    public let description: String
    public let category: String
    public let icon: String

    // MARK: - Init

    public init(title: String, description: String, category: String, icon: String) {
        self.title = title
        self.description = description
        self.category = category
        self.icon = icon
    }
}
