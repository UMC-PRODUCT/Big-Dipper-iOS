//
//  FetchActivityStatUseCase.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation

public final class FetchActivityStatUseCase:
    FetchActivityStatUseCaseProtocol, @unchecked Sendable {

    // MARK: - Property

    private let statRepository: ActivityStatRepositoryProtocol
    private let receivedCardRepository: ReceivedCardRepositoryProtocol

    // MARK: - Init

    public init(
        statRepository: ActivityStatRepositoryProtocol,
        receivedCardRepository: ReceivedCardRepositoryProtocol
    ) {
        self.statRepository = statRepository
        self.receivedCardRepository = receivedCardRepository
    }

    // MARK: - Function

    /// 네 소스를 병렬 조회하고, 실패한 소스만 `nil` 로 남긴다.
    ///
    /// 한 소스가 죽어도 나머지 숫자는 보여야 해서 소스별로 삼키되, 삼킨 결과를 `"0"` 이
    /// 아니라 `nil` 로 남긴다 — 화면이 「0개」와 「못 세었다」를 다르게 그린다 (#1222).
    public func execute() async -> ActivityStat {
        async let received = value { String(try await self.receivedCardRepository.count()) }
        async let study = value { try await self.statRepository.fetchStudyCount() }
        async let activity = value { String(try await self.statRepository.fetchActivityCount()) }
        async let bookmark = value { try await self.statRepository.fetchBookmarkCount() }

        return await ActivityStat(
            receivedCardCount: received,
            studyCount: study,
            activityCount: activity,
            bookmarkCount: bookmark
        )
    }

    // MARK: - Private Function

    /// 조회 실패·빈 문자열이면 `nil`. 값은 변환 없이 통과시킨다
    /// (절대 규칙 #2 — Int 왕복은 비정상 값을 조용히 0으로 삼킨다).
    private func value(_ fetch: () async throws -> String) async -> String? {
        guard let value = try? await fetch(),
              !value.trimmingCharacters(in: .whitespaces).isEmpty else {
            return nil
        }
        return value
    }
}
