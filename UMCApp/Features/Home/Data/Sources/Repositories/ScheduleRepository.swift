//
//  ScheduleRepository.swift
//  HomeData
//
//  Created by euijjang97 on 7/11/26.
//

import CoreNetwork
import Foundation
import HomeDomain
import UMCFoundation

/// 홈 일정 캘린더 조회 Repository 구현체
public final class ScheduleRepository: ScheduleRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let networkRequesting: any HomeNetworkRequesting

    // MARK: - Init

    /// 운영(DI) 진입점.
    public convenience init(adapter: MoyaNetworkAdapter) {
        self.init(networkRequesting: adapter)
    }

    /// 네트워크 추상화를 직접 주입하는 지정 이니셜라이저 (모듈 내부 · 테스트 전용).
    init(networkRequesting: any HomeNetworkRequesting) {
        self.networkRequesting = networkRequesting
    }

    // MARK: - Function

    /// 기간 내 일정을 조회하고 KST 자정 기준 날짜별로 그룹핑하여 반환한다.
    public func fetchMySchedules(
        from: Date,
        to: Date,
        isAttendanceRequired: Bool
    ) async throws -> [Date: [ScheduleDetailData]] {
        let response = try await networkRequesting.request(
            ScheduleV2Router.getMySchedules(
                query: MySchedulesQuery(
                    from: from,
                    to: to,
                    isAttendanceRequired: isAttendanceRequired
                )
            )
        )

        let schedules: [ScheduleDetailData]
        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<[ScheduleDetailDTO]>.self,
                from: response.data
            )
            schedules = try apiResponse.unwrap().map { $0.toDomain() }
        } catch let decodingError as DecodingError {
            #if DEBUG
            print("[ScheduleRepository] fetchMySchedules decodingError=\(decodingError)")
            #endif
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }

        let calendar = Calendar.kstGregorian
        return Dictionary(grouping: schedules) { calendar.startOfDay(for: $0.startsAt) }
    }

    /// 일정을 생성하고 서버가 돌려준 식별자를 반환한다.
    ///
    /// 서버는 생성 결과로 일정 ID 스칼라 하나만 내려준다. 절대 규칙 #2 에 따라 정수를
    /// 문자열로 직렬화하므로 `String` 으로 받되, 숫자 리터럴로 오는 경우도 함께 흡수한다.
    public func createSchedule(_ request: ScheduleCreationRequest) async throws -> String {
        let response = try await networkRequesting.request(
            ScheduleV2Router.postSchedule(body: ScheduleCreateRequestDTO(domain: request))
        )

        let apiResponse: APIResponse<FlexibleIdentifier>
        do {
            apiResponse = try JSONDecoder().decode(
                APIResponse<FlexibleIdentifier>.self,
                from: response.data
            )
        } catch let decodingError as DecodingError {
            #if DEBUG
            print("[ScheduleRepository] createSchedule decodingError=\(decodingError)")
            #endif
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }

        return try apiResponse.unwrap().value
    }

    /// 일정을 삭제한다.
    ///
    /// 성공 응답 본문이 비어 있을 수 있어(204 등) 그 경우는 성공으로 간주한다.
    public func deleteSchedule(scheduleId: String) async throws {
        let response = try await networkRequesting.request(
            ScheduleV2Router.deleteSchedule(scheduleId: scheduleId)
        )

        guard !response.data.isEmpty else { return }

        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<EmptyResult>.self,
                from: response.data
            )
            try apiResponse.validateSuccess()
        } catch let decodingError as DecodingError {
            #if DEBUG
            print("[ScheduleRepository] deleteSchedule decodingError=\(decodingError)")
            #endif
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }
    }
}

// MARK: - 스칼라 식별자 응답

/// 스칼라 하나로 내려오는 식별자 응답을 문자열로 흡수하는 래퍼.
///
/// 서버는 정수를 문자열로 직렬화하지만(절대 규칙 #2), 생성 응답은 `result` 가 객체가 아닌
/// 스칼라라 키 기반 flexible 헬퍼를 쓸 수 없다. 문자열/숫자 어느 쪽으로 와도 같은 값으로
/// 읽히도록 단일 값 컨테이너에서 직접 처리한다.
struct FlexibleIdentifier: Codable, Sendable, Equatable {

    let value: String

    init(value: String) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
            return
        }
        if let number = try? container.decode(Int.self) {
            value = String(number)
            return
        }
        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "식별자가 문자열도 정수도 아닙니다."
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
