//
//  MemberProfileSummary.swift
//  NoticeData
//
//  Created by 이예지 on 5/30/26.
//

import Foundation

// TODO: MyPage/Home 도메인 모델로 교체
public struct MemberProfileSummary {
    public let memberId: String
    public let name: String
    public let nickname: String
    public let generation: String
    public let organizationName: String?
    public let roleName: String
    public let profileImageURL: String?
}
