//
//  MockActivityStatRepository.swift
//  BusinessCardDomainTests
//
//  Created by One on 8/16/26.
//

import Foundation
@testable import BusinessCardDomain

final class MockActivityStatRepository: ActivityStatRepositoryProtocol, @unchecked Sendable {

    // MARK: - Stub

    /// 잘림 표기(`"50+"`)까지 실어야 해서 String (프로토콜과 동일).
    var studyCountResult: Result<String, Error> = .failure(MockError.notStubbed)
    /// 서버 `totalElements` 원본 통과라 String (프로토콜과 동일).
    var bookmarkCountResult: Result<String, Error> = .failure(MockError.notStubbed)
    var activityCountResult: Result<Int, Error> = .failure(MockError.notStubbed)

    /// 서버 통계 한 방의 응답. `nil`이면 위 소스별 스텁으로 조립한다 — 소스별 실패를
    /// 검증하는 기존 테스트가 그대로 살아 있어야 한다.
    var memberStatsResult: Result<MemberStats, Error>?

    // MARK: - Capture

    private(set) var memberStatsCallCount = 0

    // MARK: - ActivityStatRepositoryProtocol

    func fetchMemberStats() async throws -> MemberStats {
        memberStatsCallCount += 1
        if let memberStatsResult {
            return try memberStatsResult.get()
        }
        return MemberStats(
            receivedCardCount: nil,
            studyCount: try? studyCountResult.get(),
            bookmarkCount: try? bookmarkCountResult.get()
        )
    }

    func fetchActivityCount() async throws -> Int {
        try activityCountResult.get()
    }
}
