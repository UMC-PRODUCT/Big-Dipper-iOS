//
//  ScheduleRepositoryProtocol.swift
//  AppProduct
//
//  Created by euijjang97 on 2/12/26.
//

import Foundation

/// 일정 생성/관리 데이터 접근 Repository Protocol
///
/// HomeRepositoryProtocol에서 일정 생성 책임을 분리하여
/// 단일 책임 원칙(SRP)을 강화한 Repository입니다.
///
/// - SeeAlso: ``ScheduleRepository``, ``GenerateScheduleUseCase``
protocol ScheduleRepositoryProtocol: Sendable {

    /// 출석 포함 일정을 생성합니다.
    ///
    /// - Parameter schedule: 일정 생성 요청 DTO (제목, 날짜, 장소, 참여자 등)
    /// - Returns: 생성된 일정 ID (V2 응답의 `result.scheduleId`)
    /// - Throws: 서버 에러 또는 네트워크 에러
    @discardableResult
    func generateSchedule(
        schedule: GenerateScheduleRequetDTO
    ) async throws -> Int

    /// 일정을 단순 삭제합니다 (출석부 연동 없이).
    ///
    /// 스터디 그룹 일정 2단계 호출 실패 시 베스트 에포트 롤백 등에 사용합니다.
    ///
    /// - Parameter scheduleId: 삭제할 일정 ID
    /// - Throws: 서버 에러 또는 네트워크 에러
    func deleteSchedule(
        scheduleId: Int
    ) async throws

    /// 일정 정보를 부분 수정합니다.
    ///
    /// - Parameters:
    ///   - scheduleId: 수정할 일정 ID
    ///   - schedule: 일정 수정 요청 DTO (변경 필드만 포함 가능)
    /// - Throws: 서버 에러 또는 네트워크 에러
    func updateSchedule(
        scheduleId: Int,
        schedule: UpdateScheduleRequestDTO
    ) async throws

    /// 일정과 연결된 출석부를 함께 삭제합니다.
    ///
    /// - Parameter scheduleId: 삭제할 일정 ID
    /// - Throws: 서버 에러 또는 네트워크 에러
    func deleteScheduleWithAttendance(
        scheduleId: Int
    ) async throws
}
