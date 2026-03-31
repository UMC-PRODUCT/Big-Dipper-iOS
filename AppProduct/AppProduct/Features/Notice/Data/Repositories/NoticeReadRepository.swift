//
//  NoticeReadRepository.swift
//  AppProduct
//
//  Created by euijjang97 on 3/12/26.
//

import Foundation
import SwiftData

/// SwiftData 기반 공지 읽음 상태 로컬 저장소 구현체입니다.
///
/// CloudKit Sync 환경에서는 unique 제약을 사용하지 않고,
/// `(memberId, noticeId)` 조합 기준 fetch 후 수동 upsert 방식으로 처리합니다.
final class NoticeReadRepository: NoticeReadRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let modelContext: ModelContext

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Function

    func fetchReadNoticeIDs(memberId: Int) throws -> Set<String> {
        let descriptor = FetchDescriptor<NoticeReadRecord>()
        let records = try modelContext.fetch(descriptor)

        return Set(
            records
                .filter { $0.memberId == memberId }
                .map(\.noticeId)
        )
    }

    func markAsRead(noticeId: String, memberId: Int) throws {
        let descriptor = FetchDescriptor<NoticeReadRecord>()
        let records = try modelContext.fetch(descriptor)

        if let record = records.first(where: { $0.memberId == memberId && $0.noticeId == noticeId }) {
            record.updatedAt = .now
        } else {
            modelContext.insert(
                NoticeReadRecord(
                    memberId: memberId,
                    noticeId: noticeId
                )
            )
        }

        try modelContext.save()
    }
}
