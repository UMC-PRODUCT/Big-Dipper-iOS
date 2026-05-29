//
//  MockNoticeReadRepository.swift
//  NoticeData
//
//  Created by 이예지 on 5/30/26.
//

import Foundation
import NoticeDomain

/// 프리뷰 및 테스트용 NoticeRead Repository Mock 구현체
///
/// SwiftData 없이 메모리 기반으로 읽음 상태를 관리합니다.
public final class MockNoticeReadRepository: NoticeReadRepositoryProtocol {

    // MARK: - Property

    private var readIds: Set<String> = []

    // MARK: - Function

    public func fetchReadNoticeIDs(memberId: String) throws -> Set<String> {
        readIds
    }

    public func markAsRead(noticeId: String, memberId: String) throws {
        readIds.insert(noticeId)
    }
}
