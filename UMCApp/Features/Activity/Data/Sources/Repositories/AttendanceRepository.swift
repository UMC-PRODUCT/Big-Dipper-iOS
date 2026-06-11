//
//  AttendanceRepository.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/10/26.
//

import Foundation
import ActivityDomain
import CoreNetwork
import UMCFoundation
import Moya

/// 출석 Repository 구현체
///
/// 챌린저 본인 출석(``ChallengerAttendanceRepositoryProtocol``)과 운영진 출석 관리
/// (``OperatorAttendanceRepositoryProtocol``)를 한 구현체에서 동시에 제공합니다.
/// ``NetworkRequesting`` 으로 요청을 보낸 뒤 `APIResponse<DTO>` 를 디코딩하고
/// `toDomain()` 으로 도메인 모델에 매핑합니다.
///
/// - Note: 서버 식별자는 전 레이어 `String` 으로 통일되어 있으며, 응답 DTO 의
///   유연 디코딩이 숫자/문자열 혼용을 흡수합니다.
public final class AttendanceRepository: ChallengerAttendanceRepositoryProtocol,
                                         OperatorAttendanceRepositoryProtocol,
                                         @unchecked Sendable {

    // MARK: - Property

    private let networkRequesting: any NetworkRequesting
    private let decoder: JSONDecoder

    // MARK: - Init

    /// 운영(DI) 진입점.
    ///
    /// 인증 어댑터 ``CoreNetwork/MoyaNetworkAdapter`` 를 주입받습니다. 테스트는
    /// `@testable` 접근으로 ``init(networkRequesting:decoder:)`` 에 가짜 구현을 주입합니다.
    public convenience init(
        adapter: MoyaNetworkAdapter,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.init(networkRequesting: adapter, decoder: decoder)
    }

    /// 네트워크 추상화를 직접 주입하는 지정 이니셜라이저 (모듈 내부 · 테스트 전용).
    init(
        networkRequesting: any NetworkRequesting,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.networkRequesting = networkRequesting
        self.decoder = decoder
    }

    // MARK: - Challenger 액션

    public func requestAttendance(
        scheduleId: String,
        latitude: Double,
        longitude: Double,
        locationVerified: Bool
    ) async throws -> AttendanceDecisionResult {
        try await performAttendanceAction(
            .requestAttendance(
                scheduleId: scheduleId,
                body: RequestAttendanceRequestDTO(
                    latitude: latitude,
                    locationVerified: locationVerified,
                    longitude: longitude
                )
            )
        )
    }

    public func submitExcuse(
        scheduleId: String,
        excuseReason: String,
        isVerified: Bool,
        latitude: Double,
        longitude: Double
    ) async throws -> AttendanceDecisionResult {
        try await performAttendanceAction(
            .excuseAttendance(
                scheduleId: scheduleId,
                body: ExcuseAttendanceRequestDTO(
                    excuseReason: excuseReason,
                    isVerified: isVerified,
                    latitude: latitude,
                    longitude: longitude
                )
            )
        )
    }

    // MARK: - Operator 조회

    public func fetchAttendanceList(
        from: Date?,
        to: Date?,
        attendanceStatus: ParticipantAttendanceStatus?
    ) async throws -> [ScheduleAttendanceInfo] {
        let response = try await networkRequesting.request(
            AttendanceRouter.fetchAttendanceList(
                query: AttendanceListQuery(
                    from: from,
                    to: to,
                    attendanceStatus: attendanceStatus?.serverQueryValue
                )
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<[ScheduleAttendanceInfoDTO]>.self,
            from: response.data
        )
        return try apiResponse.unwrap().map { $0.toDomain() }
    }

    public func fetchAttendanceDetail(
        scheduleId: String,
        attendanceStatus: ParticipantAttendanceStatus?
    ) async throws -> ScheduleAttendanceInfo {
        let response = try await networkRequesting.request(
            AttendanceRouter.fetchAttendanceDetail(
                scheduleId: scheduleId,
                query: AttendanceDetailQuery(
                    attendanceStatus: attendanceStatus?.serverQueryValue
                )
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<ScheduleAttendanceInfoDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().toDomain()
    }

    // MARK: - Operator 액션

    public func decideAttendances(
        scheduleId: String,
        decisions: [AttendanceDecisionInput]
    ) async throws -> [AttendanceDecisionResult] {
        let body = decisions.map {
            DecideAttendanceItemDTO(
                isApproved: $0.isApproved,
                participantMemberId: $0.participantMemberId,
                reason: $0.reason
            )
        }
        let response = try await networkRequesting.request(
            AttendanceRouter.decideAttendances(scheduleId: scheduleId, body: body)
        )
        let apiResponse = try decoder.decode(
            APIResponse<[AttendanceDecisionResponseDTO]>.self,
            from: response.data
        )
        return try apiResponse.unwrap().map { $0.toDomain() }
    }

    public func updateScheduleLocation(
        scheduleId: String,
        locationName: String,
        latitude: Double,
        longitude: Double
    ) async throws {
        let response = try await networkRequesting.request(
            AttendanceRouter.updateScheduleLocation(
                scheduleId: scheduleId,
                body: UpdateScheduleLocationRequestDTO(
                    latitude: latitude,
                    longitude: longitude,
                    locationName: locationName
                )
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        try apiResponse.validateSuccess()
    }
}

// MARK: - Private Helper

private extension AttendanceRepository {

    /// 출석 단일 결정 액션(요청/사유)의 공통 호출·디코딩·에러 변환.
    ///
    /// 요청 호출을 `do` 블록 안에 두어 비-2xx 응답으로 발생한
    /// ``NetworkError/requestFailed(statusCode:data:)`` 까지 잡아 도메인 에러로 승격합니다.
    /// (요청을 `do` 밖에 두면 본문 기반 도메인 에러 변환이 실행되지 않습니다.)
    func performAttendanceAction(
        _ target: AttendanceRouter
    ) async throws -> AttendanceDecisionResult {
        do {
            let response = try await networkRequesting.request(target)
            let apiResponse = try decoder.decode(
                APIResponse<AttendanceDecisionResponseDTO>.self,
                from: response.data
            )
            return try apiResponse.unwrap().toDomain()
        } catch let error as NetworkError {
            throw Self.mapAttendanceActionError(error) ?? error
        }
    }

    /// 출석 액션 실패(`NetworkError.requestFailed`)의 응답 본문을 도메인 에러로 변환.
    ///
    /// 서버가 "이미 출석" 사유를 머신 코드 없이 본문 메시지로만 전달하므로 본문을 파싱해
    /// ``DomainError/attendanceAlreadySubmitted`` 로 승격하고, 그 외에는
    /// ``RepositoryError/serverError(code:message:)`` 로 정규화합니다. 변환 불가하면
    /// `nil` 을 반환해 원본 ``NetworkError`` 를 그대로 전파합니다.
    static func mapAttendanceActionError(_ error: NetworkError) -> Error? {
        guard
            case .requestFailed(_, let data) = error,
            let data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        let result = json["result"] as? String
        let message = json["message"] as? String

        if let result, result.contains("이미 출석") {
            return DomainError.attendanceAlreadySubmitted
        }

        let detail = (result?.isEmpty == false ? result : message)
        guard detail != nil || json["code"] != nil else { return nil }
        return RepositoryError.serverError(code: json["code"] as? String, message: detail)
    }
}
