//
//  MockNoticeReadRepository.swift
//  AppProduct
//

import Foundation

/// 프리뷰 및 테스트용 NoticeRead Repository Mock 구현체
///
/// SwiftData 없이 메모리 기반으로 읽음 상태를 관리합니다.
final class MockNoticeReadRepository: NoticeReadRepositoryProtocol {

    // MARK: - Property

    private var readIds: Set<String> = []

    // MARK: - Function

    func fetchReadNoticeIDs(memberId: Int) throws -> Set<String> {
        readIds
    }

    func markAsRead(noticeId: String, memberId: Int) throws {
        readIds.insert(noticeId)
    }
}
