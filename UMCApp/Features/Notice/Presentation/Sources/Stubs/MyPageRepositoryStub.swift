//
//  MyPageRepositoryStub.swift
//  NoticeData
//
//  Created by 이예지 on 5/30/26.
//

import Foundation

// TODO: MyPage 모듈 이식 후 교체
public protocol MyPageRepositoryProtocol {
    func fetchMemberProfile(memberId: Int) async throws -> MemberProfileSummary
}
