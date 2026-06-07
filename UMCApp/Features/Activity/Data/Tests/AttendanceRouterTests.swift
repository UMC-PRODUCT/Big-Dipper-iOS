//
//  AttendanceRouterTests.swift
//  ActivityDataTests
//
//  Created by jaewon Lee on 6/7/26.
//

import Testing
import Foundation
import Moya
import Alamofire
@testable import ActivityData

// MARK: - Helpers

private func makeListQuery(
    from: Date? = nil,
    to: Date? = nil,
    attendanceStatus: String? = nil
) -> AttendanceListQuery {
    AttendanceListQuery(from: from, to: to, attendanceStatus: attendanceStatus)
}

private func makeDetailQuery(
    attendanceStatus: String? = nil
) -> AttendanceDetailQuery {
    AttendanceDetailQuery(attendanceStatus: attendanceStatus)
}

private func encodeToJSON(_ value: some Encodable) throws -> [String: Any] {
    let data = try JSONEncoder().encode(value)
    let obj = try JSONSerialization.jsonObject(with: data)
    return try #require(obj as? [String: Any])
}

// MARK: - Suite: path / method

@Suite("AttendanceRouter — path/method/task 계약")
struct AttendanceRouterPathMethodTests {

    // MARK: - fetchAttendanceList

    @Test("fetchAttendanceList — path가 /api/v2/schedules/attendance")
    func fetchAttendanceListPath() {
        let router = AttendanceRouter.fetchAttendanceList(query: makeListQuery())
        #expect(router.path == "/api/v2/schedules/attendance")
    }

    @Test("fetchAttendanceList — method가 .get")
    func fetchAttendanceListMethod() {
        let router = AttendanceRouter.fetchAttendanceList(query: makeListQuery())
        #expect(router.method == .get)
    }

    // MARK: - fetchAttendanceDetail

    @Test("fetchAttendanceDetail — scheduleId '42'가 path에 보간됨")
    func fetchAttendanceDetailPathInterpolation() {
        let router = AttendanceRouter.fetchAttendanceDetail(
            scheduleId: "42",
            query: makeDetailQuery()
        )
        #expect(router.path == "/api/v2/schedules/42/attendance")
    }

    @Test("fetchAttendanceDetail — method가 .get")
    func fetchAttendanceDetailMethod() {
        let router = AttendanceRouter.fetchAttendanceDetail(
            scheduleId: "42",
            query: makeDetailQuery()
        )
        #expect(router.method == .get)
    }

    // MARK: - decideAttendances

    @Test("decideAttendances — scheduleId '42'가 path에 보간됨")
    func decideAttendancesPathInterpolation() {
        let router = AttendanceRouter.decideAttendances(
            scheduleId: "42",
            body: []
        )
        #expect(router.path == "/api/v2/schedules/42/attendances/decide")
    }

    @Test("decideAttendances — method가 .post")
    func decideAttendancesMethod() {
        let router = AttendanceRouter.decideAttendances(scheduleId: "42", body: [])
        #expect(router.method == .post)
    }

    // MARK: - requestAttendance

    @Test("requestAttendance — scheduleId '42'가 path에 보간됨")
    func requestAttendancePathInterpolation() {
        let body = RequestAttendanceRequestDTO(
            latitude: 37.5, locationVerified: true, longitude: 127.0
        )
        let router = AttendanceRouter.requestAttendance(scheduleId: "42", body: body)
        #expect(router.path == "/api/v2/schedules/42/attendances/request")
    }

    @Test("requestAttendance — method가 .post")
    func requestAttendanceMethod() {
        let body = RequestAttendanceRequestDTO(
            latitude: 37.5, locationVerified: true, longitude: 127.0
        )
        let router = AttendanceRouter.requestAttendance(scheduleId: "42", body: body)
        #expect(router.method == .post)
    }

    // MARK: - excuseAttendance

    @Test("excuseAttendance — scheduleId '42'가 path에 보간됨")
    func excuseAttendancePathInterpolation() {
        let body = ExcuseAttendanceRequestDTO(
            excuseReason: "사유", isVerified: true, latitude: 37.5, longitude: 127.0
        )
        let router = AttendanceRouter.excuseAttendance(scheduleId: "42", body: body)
        #expect(router.path == "/api/v2/schedules/42/attendances/excuse")
    }

    @Test("excuseAttendance — method가 .post")
    func excuseAttendanceMethod() {
        let body = ExcuseAttendanceRequestDTO(
            excuseReason: "사유", isVerified: true, latitude: 37.5, longitude: 127.0
        )
        let router = AttendanceRouter.excuseAttendance(scheduleId: "42", body: body)
        #expect(router.method == .post)
    }

    // MARK: - updateScheduleLocation

    @Test("updateScheduleLocation — scheduleId '42'가 path에 보간됨")
    func updateScheduleLocationPathInterpolation() {
        let body = UpdateScheduleLocationRequestDTO(
            latitude: 37.5, longitude: 127.0, locationName: "한성대입구역"
        )
        let router = AttendanceRouter.updateScheduleLocation(scheduleId: "42", body: body)
        #expect(router.path == "/api/v2/schedules/42")
    }

    @Test("updateScheduleLocation — method가 .patch")
    func updateScheduleLocationMethod() {
        let body = UpdateScheduleLocationRequestDTO(
            latitude: 37.5, longitude: 127.0, locationName: "한성대입구역"
        )
        let router = AttendanceRouter.updateScheduleLocation(scheduleId: "42", body: body)
        #expect(router.method == .patch)
    }
}

// MARK: - Suite: task shape

@Suite("AttendanceRouter — task 형태 계약")
struct AttendanceRouterTaskTests {

    // MARK: - fetchAttendanceList task

    @Test("fetchAttendanceList — 모든 파라미터 nil 시 task가 .requestPlain (detail과 동일 분기)")
    func fetchAttendanceListTaskAllNil() {
        let router = AttendanceRouter.fetchAttendanceList(query: makeListQuery())
        if case .requestPlain = router.task {
            // 기대하는 case — 빈 파라미터는 detail과 동일하게 .requestPlain
        } else {
            Issue.record("task가 .requestPlain 여야 함 — 실제: \(router.task)")
        }
    }

    @Test("fetchAttendanceList — from/to/status 지정 시 task가 .requestParameters (키 3개 포함)")
    func fetchAttendanceListTaskWithAllParams() {
        let fixedDate = Date(timeIntervalSince1970: 0)
        let query = makeListQuery(
            from: fixedDate,
            to: fixedDate,
            attendanceStatus: "PRESENT"
        )
        let router = AttendanceRouter.fetchAttendanceList(query: query)
        if case let .requestParameters(parameters, encoding) = router.task {
            #expect(parameters["attendanceStatus"] as? String == "PRESENT")
            #expect(parameters["from"] != nil)
            #expect(parameters["to"] != nil)
            let usesURLEncoding = encoding is URLEncoding
            #expect(usesURLEncoding)
        } else {
            Issue.record("task가 .requestParameters 여야 함 — 실제: \(router.task)")
        }
    }

    // MARK: - fetchAttendanceDetail task

    @Test("fetchAttendanceDetail — attendanceStatus nil → task가 .requestPlain")
    func fetchAttendanceDetailTaskRequestPlain() {
        let router = AttendanceRouter.fetchAttendanceDetail(
            scheduleId: "42",
            query: makeDetailQuery(attendanceStatus: nil)
        )
        if case .requestPlain = router.task {
            // 기대하는 case
        } else {
            Issue.record("task가 .requestPlain 여야 함 — 실제: \(router.task)")
        }
    }

    @Test("fetchAttendanceDetail — attendanceStatus 지정 시 task가 .requestParameters (attendanceStatus 키 포함)")
    func fetchAttendanceDetailTaskWithStatus() {
        let router = AttendanceRouter.fetchAttendanceDetail(
            scheduleId: "42",
            query: makeDetailQuery(attendanceStatus: "LATE")
        )
        if case let .requestParameters(parameters, encoding) = router.task {
            #expect(parameters["attendanceStatus"] as? String == "LATE")
            let usesURLEncoding = encoding is URLEncoding
            #expect(usesURLEncoding)
        } else {
            Issue.record("task가 .requestParameters 여야 함 — 실제: \(router.task)")
        }
    }

    // MARK: - decideAttendances task

    @Test("decideAttendances — task가 .requestJSONEncodable")
    func decideAttendancesTaskIsJSONEncodable() {
        let items = [
            DecideAttendanceItemDTO(isApproved: true, participantMemberId: "7", reason: "")
        ]
        let router = AttendanceRouter.decideAttendances(scheduleId: "42", body: items)
        if case .requestJSONEncodable = router.task {
            // 기대하는 case
        } else {
            Issue.record("task가 .requestJSONEncodable 여야 함 — 실제: \(router.task)")
        }
    }

    // MARK: - requestAttendance task

    @Test("requestAttendance — task가 .requestJSONEncodable")
    func requestAttendanceTaskIsJSONEncodable() {
        let body = RequestAttendanceRequestDTO(
            latitude: 37.5, locationVerified: true, longitude: 127.0
        )
        let router = AttendanceRouter.requestAttendance(scheduleId: "42", body: body)
        if case .requestJSONEncodable = router.task {
            // 기대하는 case
        } else {
            Issue.record("task가 .requestJSONEncodable 여야 함 — 실제: \(router.task)")
        }
    }

    // MARK: - excuseAttendance task

    @Test("excuseAttendance — task가 .requestJSONEncodable")
    func excuseAttendanceTaskIsJSONEncodable() {
        let body = ExcuseAttendanceRequestDTO(
            excuseReason: "사유", isVerified: true, latitude: 37.5, longitude: 127.0
        )
        let router = AttendanceRouter.excuseAttendance(scheduleId: "42", body: body)
        if case .requestJSONEncodable = router.task {
            // 기대하는 case
        } else {
            Issue.record("task가 .requestJSONEncodable 여야 함 — 실제: \(router.task)")
        }
    }

    // MARK: - updateScheduleLocation task

    @Test("updateScheduleLocation — task가 .requestJSONEncodable")
    func updateScheduleLocationTaskIsJSONEncodable() {
        let body = UpdateScheduleLocationRequestDTO(
            latitude: 37.5, longitude: 127.0, locationName: "한성대입구역"
        )
        let router = AttendanceRouter.updateScheduleLocation(scheduleId: "42", body: body)
        if case .requestJSONEncodable = router.task {
            // 기대하는 case
        } else {
            Issue.record("task가 .requestJSONEncodable 여야 함 — 실제: \(router.task)")
        }
    }
}

// MARK: - Suite: DTO JSON 인코딩 계약

@Suite("AttendanceRouter — DTO JSON 인코딩 계약")
struct AttendanceRouterDTOEncodingTests {

    // MARK: - RequestAttendanceRequestDTO

    @Test("RequestAttendanceRequestDTO — latitude/longitude/locationVerified 키 정확히 인코딩")
    func requestAttendanceDTOEncodesCorrectly() throws {
        let dto = RequestAttendanceRequestDTO(
            latitude: 37.5678,
            locationVerified: true,
            longitude: 127.0123
        )
        let json = try encodeToJSON(dto)

        #expect(json["latitude"] as? Double == 37.5678)
        #expect(json["longitude"] as? Double == 127.0123)
        #expect(json["locationVerified"] as? Bool == true)
        #expect(json.keys.count == 3)
    }

    @Test("RequestAttendanceRequestDTO — isVerified 키 없음 (서버 필드명 locationVerified 만 존재)")
    func requestAttendanceDTOHasNoIsVerifiedKey() throws {
        let dto = RequestAttendanceRequestDTO(
            latitude: 37.5, locationVerified: false, longitude: 127.0
        )
        let json = try encodeToJSON(dto)
        #expect(json["isVerified"] == nil)
        #expect(json["locationVerified"] as? Bool == false)
    }

    // MARK: - ExcuseAttendanceRequestDTO

    @Test("ExcuseAttendanceRequestDTO — excuseReason/isVerified/latitude/longitude 키 정확히 인코딩")
    func excuseAttendanceDTOEncodesCorrectly() throws {
        let dto = ExcuseAttendanceRequestDTO(
            excuseReason: "지각 사유",
            isVerified: false,
            latitude: 37.1,
            longitude: 127.2
        )
        let json = try encodeToJSON(dto)

        #expect(json["excuseReason"] as? String == "지각 사유")
        #expect(json["isVerified"] as? Bool == false)
        #expect(json["latitude"] as? Double == 37.1)
        #expect(json["longitude"] as? Double == 127.2)
        #expect(json.keys.count == 4)
    }

    @Test("ExcuseAttendanceRequestDTO — locationVerified 키 없음 (서버 필드명 isVerified 만 존재)")
    func excuseAttendanceDTOHasNoLocationVerifiedKey() throws {
        let dto = ExcuseAttendanceRequestDTO(
            excuseReason: "사유", isVerified: true, latitude: 37.5, longitude: 127.0
        )
        let json = try encodeToJSON(dto)
        #expect(json["locationVerified"] == nil)
        #expect(json["isVerified"] as? Bool == true)
    }

    // MARK: - DecideAttendanceItemDTO

    @Test("DecideAttendanceItemDTO — participantMemberId가 JSON 문자열로 직렬화됨 (Int 아님)")
    func decideAttendanceDTOParticipantMemberIdIsString() throws {
        let dto = DecideAttendanceItemDTO(
            isApproved: true,
            participantMemberId: "7",
            reason: "승인"
        )
        let json = try encodeToJSON(dto)

        // 핵심 계약: String "7" 이어야 하며 숫자 7이 아님
        #expect(json["participantMemberId"] as? String == "7")
        // Int로 역변환 불가임을 명시 확인
        #expect(json["participantMemberId"] as? Int == nil)
        #expect(json["isApproved"] as? Bool == true)
        #expect(json["reason"] as? String == "승인")
        #expect(json.keys.count == 3)
    }

    @Test("DecideAttendanceItemDTO — isApproved false 시 정확히 인코딩")
    func decideAttendanceDTOIsApprovedFalse() throws {
        let dto = DecideAttendanceItemDTO(
            isApproved: false,
            participantMemberId: "99",
            reason: "반려 사유"
        )
        let json = try encodeToJSON(dto)
        #expect(json["isApproved"] as? Bool == false)
        #expect(json["participantMemberId"] as? String == "99")
    }

    // MARK: - UpdateScheduleLocationRequestDTO

    @Test("UpdateScheduleLocationRequestDTO — { location: { latitude, longitude, locationName } } 중첩 구조로 인코딩")
    func updateScheduleLocationDTOEncodesNestedStructure() throws {
        let dto = UpdateScheduleLocationRequestDTO(
            latitude: 37.5678,
            longitude: 127.0123,
            locationName: "한성대입구역"
        )
        let json = try encodeToJSON(dto)

        // 최상위 키는 "location" 하나만
        #expect(json.keys.count == 1)
        let location = try #require(json["location"] as? [String: Any])
        #expect(location["latitude"] as? Double == 37.5678)
        #expect(location["longitude"] as? Double == 127.0123)
        #expect(location["locationName"] as? String == "한성대입구역")
        #expect(location.keys.count == 3)
    }

    // MARK: - AttendanceListQuery.toParameters

    @Test("AttendanceListQuery.toParameters — 모든 값 nil → 빈 딕셔너리")
    func attendanceListQueryAllNilIsEmpty() {
        let query = makeListQuery()
        #expect(query.toParameters.isEmpty)
    }

    @Test("AttendanceListQuery.toParameters — attendanceStatus만 지정 시 해당 키만 포함")
    func attendanceListQueryStatusOnly() {
        let query = makeListQuery(attendanceStatus: "ABSENT")
        let params = query.toParameters
        #expect(params.keys.count == 1)
        #expect(params["attendanceStatus"] as? String == "ABSENT")
    }

    @Test("AttendanceListQuery.toParameters — from/to 지정 시 UTC ISO8601 문자열로 변환됨")
    func attendanceListQueryFromToConvertedToUTCString() {
        // epoch 0 = 1970-01-01T00:00:00.000Z (결정론적)
        let fixedDate = Date(timeIntervalSince1970: 0)
        let query = makeListQuery(from: fixedDate, to: fixedDate)
        let params = query.toParameters

        #expect(params["from"] != nil)
        #expect(params["to"] != nil)
        #expect(params["attendanceStatus"] == nil)

        // ISO8601 with fractional seconds, UTC — 문자열 형태 검증
        let fromStr = params["from"] as? String
        let toStr = params["to"] as? String
        #expect(fromStr?.hasPrefix("1970-01-01T00:00:00") == true)
        #expect(toStr?.hasPrefix("1970-01-01T00:00:00") == true)
        // UTC suffix ('Z' 또는 '+00:00') 포함 확인
        let endsWithZ = fromStr?.hasSuffix("Z") == true
        let endsWithOffset = fromStr?.hasSuffix("+00:00") == true
        #expect(endsWithZ || endsWithOffset)
    }

    @Test("AttendanceListQuery.toParameters — from/to/status 모두 지정 시 키 3개")
    func attendanceListQueryAllParams() {
        let fixedDate = Date(timeIntervalSince1970: 1_000)
        let query = makeListQuery(from: fixedDate, to: fixedDate, attendanceStatus: "PRESENT")
        let params = query.toParameters
        #expect(params.keys.count == 3)
        #expect(params["attendanceStatus"] as? String == "PRESENT")
        #expect(params["from"] != nil)
        #expect(params["to"] != nil)
    }

    // MARK: - [DecideAttendanceItemDTO] 배열 와이어 형태

    @Test("[DecideAttendanceItemDTO] — 최상위 JSON 배열로 직렬화 + 각 항목 participantMemberId가 String")
    func decideAttendanceArrayEncodesAsTopLevelArray() throws {
        let items = [
            DecideAttendanceItemDTO(isApproved: true, participantMemberId: "7", reason: "승인"),
            DecideAttendanceItemDTO(isApproved: false, participantMemberId: "8", reason: "반려"),
        ]
        let data = try JSONEncoder().encode(items)
        let array = try #require(
            try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        )

        #expect(array.count == 2)
        #expect(array[0]["participantMemberId"] as? String == "7")
        #expect(array[1]["participantMemberId"] as? String == "8")
        #expect(array[0]["isApproved"] as? Bool == true)
        #expect(array[1]["isApproved"] as? Bool == false)
    }
}
