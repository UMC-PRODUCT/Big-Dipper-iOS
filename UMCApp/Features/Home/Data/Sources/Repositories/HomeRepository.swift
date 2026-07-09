import CoreNetwork
import Foundation
import HomeDomain
import UMCFoundation

/// 홈 화면(시즌/세대 카드) 관련 Repository 구현체
public struct HomeRepository: HomeRepositoryProtocol {

    // MARK: - Property

    private let adapter: MoyaNetworkAdapter

    // MARK: - Init

    public init(adapter: MoyaNetworkAdapter) {
        self.adapter = adapter
    }

    // MARK: - Function

    public func fetchMyProfile() async throws -> HomeProfileResult {
        let dto = try await fetchProfileDTO()
        let generations = dto.toHomeGenerations()
        let seasonTypes = try await makeSeasonTypes(dto: dto)

        return HomeProfileResult(
            memberId: dto.id,
            seasonTypes: seasonTypes,
            generations: generations
        )
    }

    // MARK: - Private Function

    private func fetchProfileDTO() async throws -> MyProfileResponseDTO {
        let response = try await adapter.request(HomeRouter.getGen)

        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<MyProfileResponseDTO>.self,
                from: response.data
            )
            return try apiResponse.unwrap()
        } catch let decodingError as DecodingError {
            #if DEBUG
            let rawBody = String(data: response.data, encoding: .utf8) ?? "<invalid utf8>"
            print("[HomeRepository] fetchMyProfile decodingError=\(decodingError)")
            print("[HomeRepository] fetchMyProfile rawBody=\(rawBody)")
            #endif
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }
    }

    /// 소속 기수 목록과, 가장 이른 기수 시작일 기준 누적 활동일을 시즌 카드 값으로 구성한다.
    private func makeSeasonTypes(dto: MyProfileResponseDTO) async throws -> [SeasonType] {
        let generationNumbers = dto.mergedGenerationNumbers()
        let activityDays = try await calculateActivityDays(targetGisuIds: dto.targetGisuIds())

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
        let response = try await adapter.request(HomeRouter.getGisuDetail(gisuId: gisuId))

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
