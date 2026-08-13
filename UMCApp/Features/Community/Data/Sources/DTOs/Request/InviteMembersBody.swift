//
//  InviteMembersBody.swift
//  CommunityData
//

import Foundation

/// `POST /api/v1/community/threads/{threadId}/invite` 본문.
///
/// 서버가 `memberIds` 를 raw number 배열로 받는다(`@NotEmpty`, 최대 99, 중복 불가).
/// Domain 은 식별자를 String 으로 들고 다니므로(절대 규칙 #2) 전송 직전인 여기서만 Int 로 바꾼다.
public struct InviteMembersBody: Encodable {

    // MARK: - Property

    public let memberIds: [Int]

    // MARK: - Init

    /// - Parameter memberIds: 서버가 준 식별자. 숫자로 바꿀 수 없는 값은 서버가 모르는
    ///   식별자라 보내 봐야 400 이므로 여기서 버린다.
    public init(memberIds: [String]) {
        self.memberIds = memberIds.compactMap(Int.init)
    }
}
