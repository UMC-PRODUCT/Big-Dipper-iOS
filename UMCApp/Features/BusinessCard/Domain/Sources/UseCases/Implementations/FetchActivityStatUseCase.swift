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

    /// 서버 통합 카운트와 로컬 활동 수를 병렬 조회하고, 못 센 값만 `nil` 로 남긴다.
    ///
    /// 한 소스가 죽어도 나머지 숫자는 보여야 해서 소스별로 삼키되, 삼킨 결과를 `"0"` 이
    /// 아니라 `nil` 로 남긴다 — 화면이 「0개」와 「못 세었다」를 다르게 그린다 (#1222).
    public func execute() async -> ActivityStat {
        async let statsTask = memberStats()
        async let activityTask = value {
            String(try await self.statRepository.fetchActivityCount())
        }

        let stats = await statsTask
        var received = nonEmpty(stats.receivedCardCount)
        if received == nil {
            // 서버가 못 준 값이라도 로컬 캐시 수는 **실제로 아는 값**이다. `nil`("-")로
            // 두는 것보다 정확하다 — #1222가 금지한 것은 실패를 "0"으로 눌러 담는 것이지
            // 아는 값을 쓰는 것이 아니다.
            received = await value { String(try await self.receivedCardRepository.count()) }
        }

        return await ActivityStat(
            receivedCardCount: received,
            studyCount: nonEmpty(stats.studyCount),
            activityCount: activityTask,
            bookmarkCount: nonEmpty(stats.bookmarkCount)
        )
    }

    // MARK: - Private Function

    /// 통합 조회가 통째로 실패하면 세 값 전부 「못 셌다」다.
    private func memberStats() async -> MemberStats {
        (try? await statRepository.fetchMemberStats()) ?? .unavailable
    }

    /// 조회 실패·빈 문자열이면 `nil`. 값은 변환 없이 통과시킨다
    /// (핵심 규칙 #2 — Int 왕복은 비정상 값을 조용히 0으로 삼킨다).
    private func value(_ fetch: () async throws -> String) async -> String? {
        nonEmpty(try? await fetch())
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return value
    }
}
