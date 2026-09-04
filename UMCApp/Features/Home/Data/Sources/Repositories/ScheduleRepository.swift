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

    /// 단일 일정 상세를 조회한다. 목록과 응답 스키마가 같아 같은 DTO/도메인 모델을 쓴다.
    public func fetchScheduleDetail(scheduleId: String) async throws -> ScheduleDetailData {
        let response = try await networkRequesting.request(
            ScheduleV2Router.getScheduleDetail(scheduleId: scheduleId)
        )

        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<ScheduleDetailDTO>.self,
                from: response.data
            )
            return try apiResponse.unwrap().toDomain()
        } catch let decodingError as DecodingError {
            #if DEBUG
            print("[ScheduleRepository] fetchScheduleDetail decodingError=\(decodingError)")
            #endif
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }
    }

    /// 일정을 생성하고 서버가 돌려준 식별자를 반환한다.
    ///
    /// 서버는 생성 결과로 일정 ID 스칼라 하나만 내려준다. 핵심 규칙 #2 에 따라 정수를
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

    /// 일정을 부분 수정한다. 전송할 필드 선별은 요청 DTO 의 인코딩이 담당한다.
    ///
    /// 성공 응답 본문이 비어 있을 수 있어(204 등) 그 경우는 성공으로 간주한다.
    public func updateSchedule(
        scheduleId: String,
        request: ScheduleUpdateRequest
    ) async throws {
        let response = try await networkRequesting.request(
            ScheduleV2Router.patchSchedule(
                scheduleId: scheduleId,
                body: ScheduleUpdateRequestDTO(domain: request)
            )
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
            print("[ScheduleRepository] updateSchedule decodingError=\(decodingError)")
            #endif
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }
    }

    /// 일정을 삭제한다.
    ///
    /// 성공 응답 본문이 비어 있을 수 있어(204 등) 그 경우는 성공으로 간주한다.
    /// 출석 기록을 이유로 거부된 응답은 강제 삭제 안내가 가능하도록 도메인 에러로 승격한다.
    public func deleteSchedule(scheduleId: String) async throws {
        let response = try await networkRequesting.request(
            ScheduleV2Router.deleteSchedule(scheduleId: scheduleId)
        )

        guard !response.data.isEmpty else { return }

        let apiResponse: APIResponse<EmptyResult>
        do {
            apiResponse = try JSONDecoder().decode(
                APIResponse<EmptyResult>.self,
                from: response.data
            )
        } catch let decodingError as DecodingError {
            #if DEBUG
            print("[ScheduleRepository] deleteSchedule decodingError=\(decodingError)")
            #endif
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }

        do {
            try apiResponse.validateSuccess()
        } catch let serverError as RepositoryError {
            throw Self.mapDeleteError(serverError)
        }
    }

    /// 출석 기록이 있는 일정을 강제 삭제한다. 권한 검증은 서버가 한다.
    public func forceDeleteSchedule(scheduleId: String) async throws {
        let response = try await networkRequesting.request(
            ScheduleV2Router.forceDeleteSchedule(scheduleId: scheduleId)
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
            print("[ScheduleRepository] forceDeleteSchedule decodingError=\(decodingError)")
            #endif
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }
    }

    /// 삭제 거부 응답 중 "출석 기록 존재" 케이스만 도메인 에러로 승격한다.
    ///
    /// 호출부가 강제 삭제로 에스컬레이션할지 판단하는 유일한 신호라 일반 서버 에러와 구분한다.
    ///
    /// ponytail: 서버가 이 거부에 전용 code 를 주지 않아 메시지 문자열 스니핑에 의존한다.
    /// 서버 문구가 바뀌면 일반 서버 에러로 조용히 되돌아간다 — 전용 code(예: `SCHEDULE-00xx`)가
    /// 생기면 code 우선 판정으로 교체하고 문자열은 fallback 으로 남긴다.
    private static func mapDeleteError(_ error: RepositoryError) -> Error {
        guard case .serverError(let code, let message) = error else { return error }

        let combined = "\(code ?? "") \(message ?? "")"
        let hasAttendanceRecords = combined.contains("출석 기록")
            || combined.contains("출석 데이터")
            || (combined.contains("출석") && combined.contains("삭제"))

        return hasAttendanceRecords ? DomainError.scheduleHasAttendanceRecords : error
    }
}

// MARK: - 스칼라 식별자 응답

/// 스칼라 하나로 내려오는 식별자 응답을 문자열로 흡수하는 래퍼.
///
/// 서버는 정수를 문자열로 직렬화하지만(핵심 규칙 #2), 생성 응답은 `result` 가 객체가 아닌
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
