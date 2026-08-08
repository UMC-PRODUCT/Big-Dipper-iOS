//
//  ScheduleUpdatePipelineTests.swift
//  HomeDataTests
//
//  Created by euijjang97 on 8/8/26.
//
//  PATCH 부분 전송 계약(설정하지 않은 필드는 본문에서 생략)과, 강제 삭제 에스컬레이션의 유일한
//  신호인 "출석 기록 존재" 삭제 거부가 도메인 에러로 승격되는지 검증한다.
//

import Foundation
import Testing
import Moya
import CoreNetwork
import UMCFoundation
import HomeDomain
@testable import HomeData

// MARK: - Test Double

/// ``HomeNetworkRequesting`` 가짜 구현 (고정 본문 1회 응답).
private struct StubScheduleNetwork: HomeNetworkRequesting {

    let body: Data

    func request<T: TargetType>(_ target: T) async throws -> Response {
        Response(statusCode: 200, data: body)
    }
}

@Suite("일정 수정/삭제 파이프라인")
struct ScheduleUpdatePipelineTests {

    // MARK: - PATCH 부분 전송

    @Test("설정하지 않은 필드는 요청 본문에서 생략된다")
    func omitsUnsetFields() throws {
        let dto = ScheduleUpdateRequestDTO(domain: ScheduleUpdateRequest(name: "세미나"))

        let body = try encodeToJSONObject(dto)

        #expect(body.keys.sorted() == ["name"])
    }

    @Test("설정한 필드는 값과 함께 전송된다 (false 도 생략되지 않는다)")
    func encodesSetFields() throws {
        let startsAt = Date(timeIntervalSince1970: 1_770_000_000)
        let dto = ScheduleUpdateRequestDTO(
            domain: ScheduleUpdateRequest(
                startsAt: startsAt,
                participantMemberIds: ["7", "정수아님"],
                isOnline: false,
                isAttendanceRequired: false
            )
        )

        let body = try encodeToJSONObject(dto)

        #expect(
            body["startsAt"] as? String == ServerDateTimeConverter.toUTCDateTimeString(startsAt)
        )
        #expect(body["participantMemberIds"] as? [Int] == [7])
        #expect(body["isOnline"] as? Bool == false)
        #expect(body["isAttendanceRequired"] as? Bool == false)
        #expect(body["name"] == nil)
    }

    // MARK: - 삭제 거부 매핑

    @Test("출석 기록으로 거부된 삭제는 도메인 에러로 승격된다")
    func mapsAttendanceRecordRejection() async throws {
        let repository = makeRepository(
            responseBody: #"""
            {
                "success": false,
                "code": "SCHEDULE-0011",
                "message": "출석 기록이 있어 삭제할 수 없습니다.",
                "result": null
            }
            """#
        )

        await #expect(throws: DomainError.scheduleHasAttendanceRecords) {
            try await repository.deleteSchedule(scheduleId: "12")
        }
    }

    @Test("그 밖의 삭제 실패는 서버 에러 그대로 전달된다")
    func keepsUnrelatedServerError() async throws {
        let repository = makeRepository(
            responseBody: #"""
            {
                "success": false,
                "code": "SCHEDULE-0009",
                "message": "일정을 찾을 수 없습니다.",
                "result": null
            }
            """#
        )

        await #expect(
            throws: RepositoryError.serverError(
                code: "SCHEDULE-0009",
                message: "일정을 찾을 수 없습니다."
            )
        ) {
            try await repository.deleteSchedule(scheduleId: "12")
        }
    }

    // MARK: - Helper

    private func makeRepository(responseBody: String) -> ScheduleRepository {
        ScheduleRepository(networkRequesting: StubScheduleNetwork(body: Data(responseBody.utf8)))
    }

    private func encodeToJSONObject(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}
