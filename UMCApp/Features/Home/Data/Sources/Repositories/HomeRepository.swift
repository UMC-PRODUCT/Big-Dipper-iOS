//
//  HomeRepository.swift
//  HomeData
//
//  Created by euijjang97 on 7/9/26.
//

import CoreDomain
import CoreNetwork
import Foundation
import HomeDomain
import UMCFoundation

/// 홈 화면(시즌/세대 카드) 관련 Repository 구현체
public final class HomeRepository: HomeRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let networkRequesting: any HomeNetworkRequesting
    private let memberProfileRepository: MemberProfileRepositoryProtocol

    // MARK: - Init

    /// 운영(DI) 진입점.
    ///
    /// 인증 어댑터 ``CoreNetwork/MoyaNetworkAdapter`` 와 정본 프로필 조회 파이프라인
    /// ``CoreDomain/MemberProfileRepositoryProtocol`` 을 주입받습니다. 테스트는
    /// `@testable` 접근으로 ``init(networkRequesting:memberProfileRepository:)`` 에
    /// 가짜 구현을 주입합니다.
    public convenience init(
        adapter: MoyaNetworkAdapter,
        memberProfileRepository: MemberProfileRepositoryProtocol
    ) {
        self.init(networkRequesting: adapter, memberProfileRepository: memberProfileRepository)
    }

    /// 네트워크 추상화를 직접 주입하는 지정 이니셜라이저 (모듈 내부 · 테스트 전용).
    init(
        networkRequesting: any HomeNetworkRequesting,
        memberProfileRepository: MemberProfileRepositoryProtocol
    ) {
        self.networkRequesting = networkRequesting
        self.memberProfileRepository = memberProfileRepository
    }

    // MARK: - Function

    public func fetchMyProfile() async throws -> HomeProfileResult {
        let profile = try await memberProfileRepository.fetchMyProfile()
        let generations = profile.toHomeGenerations()
        let seasonTypes = try await makeSeasonTypes(profile: profile)

        return HomeProfileResult(
            memberId: profile.memberId,
            seasonTypes: seasonTypes,
            generations: generations
        )
    }

    // MARK: - Private Function

    /// 소속 기수 목록과, 가장 이른 기수 시작일 기준 누적 활동일을 시즌 카드 값으로 구성한다.
    private func makeSeasonTypes(profile: Profile) async throws -> [SeasonType] {
        let generationNumbers = profile.generations
        let activityDays = try await calculateActivityDays(targetGisuIds: profile.targetGisuIds())

        var seasonTypes: [SeasonType] = []
        if !generationNumbers.isEmpty {
            seasonTypes.append(.gens(generationNumbers))
        }
        seasonTypes.append(.days(activityDays))
        return seasonTypes
    }

    /// 대상 기수들의 시작일 중 가장 이른 날짜부터 오늘(KST)까지의 일수를 계산한다.
    private func calculateActivityDays(targetGisuIds: [String]) async throws -> Int {
        guard !targetGisuIds.isEmpty else { return 0 }

        let startDates = try await withThrowingTaskGroup(of: Date?.self) { group in
            for gisuId in targetGisuIds {
                group.addTask {
                    try await self.fetchSeasonStartDate(gisuId: gisuId)
                }
            }

            var dates: [Date] = []
            for try await date in group {
                if let date {
                    dates.append(date)
                }
            }
            return dates
        }

        guard let earliestStartDate = startDates.min() else { return 0 }
        return calculateDayCount(from: earliestStartDate, to: Date())
    }

    private func fetchSeasonStartDate(gisuId: String) async throws -> Date? {
        let response = try await networkRequesting.request(
            HomeRouter.getGisuDetail(gisuId: gisuId)
        )

        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<GisuDetailDTO>.self,
                from: response.data
            )
            let dto = try apiResponse.unwrap()
            return ServerDateTimeConverter.parseUTCDateTime(dto.startAt)
        } catch let decodingError as DecodingError {
            #if DEBUG
            print("[HomeRepository] fetchSeasonStartDate decodingError=\(decodingError)")
            #endif
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }
    }

    /// KST 기준 두 날짜 사이의 일수 차이(당일 포함 1일차 기준 + 1)를 계산한다.
    private func calculateDayCount(from startDate: Date, to endDate: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = ServerDateTimeConverter.kstTimeZone

        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)
        let dayCount = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        return max(dayCount + 1, 1)
    }
}
