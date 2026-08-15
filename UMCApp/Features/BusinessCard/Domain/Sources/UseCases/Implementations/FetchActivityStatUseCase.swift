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

    /// 네 소스를 병렬 조회하고, 실패한 소스만 "0"으로 채운다 (MP-F07 우측 값 일관).
    public func execute() async -> ActivityStat {
        async let received = countOrZero { try await self.receivedCardRepository.count() }
        async let study = countOrZero { try await self.statRepository.fetchStudyCount() }
        async let activity = countOrZero { try await self.statRepository.fetchActivityCount() }
        async let bookmark = textOrZero { try await self.statRepository.fetchBookmarkCount() }

        return await ActivityStat(
            receivedCardCount: received,
            studyCount: study,
            activityCount: activity,
            bookmarkCount: bookmark
        )
    }

    // MARK: - Private Function

    /// 로컬 집계(Int) 소스 — 실패 시 "0".
    private func countOrZero(_ fetch: () async throws -> Int) async -> String {
        (try? await fetch()).map(String.init) ?? "0"
    }

    /// 서버 원본(String) 소스 — 실패·빈 문자열이면 "0". 값은 변환 없이 통과시킨다
    /// (절대 규칙 #2 — Int 왕복은 비정상 값을 조용히 0으로 삼킨다).
    private func textOrZero(_ fetch: () async throws -> String) async -> String {
        guard let value = try? await fetch(),
              !value.trimmingCharacters(in: .whitespaces).isEmpty else {
            return "0"
        }
        return value
    }
}
