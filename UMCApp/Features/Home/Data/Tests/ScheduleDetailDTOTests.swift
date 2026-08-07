//
//  ScheduleDetailDTOTests.swift
//  HomeDataTests
//
//  Created by euijjang97 on 8/1/26.
//
//  서버가 정수를 String/Number 어느 쪽으로 내려주든 동일한 도메인 값이 나오는지(절대 규칙 #2),
//  옵셔널 객체(`location`/`attendancePolicy`)와 누락 키가 크래시 없이 흡수되는지,
//  출석 상태 raw 문자열이 ``ScheduleAttendanceStatus`` 로 올바르게 매핑되는지 검증한다.
//

import Foundation
import Testing
import HomeDomain
import UMCFoundation
@testable import HomeData

@Suite("ScheduleDetailDTO — 디코딩 & 도메인 매핑")
struct ScheduleDetailDTOTests {

    // MARK: - 서버 정수 직렬화 유연성

    @Test("서버가 정수를 String으로 내려줘도 도메인에서 String으로 보존된다")
    func decodesStringSerializedIdentifiers() throws {
        let dto = try decodeScheduleDetail(makeFullJSON(numericIdentifiers: false))
        let domain = dto.toDomain()

        #expect(domain.scheduleId == "12")
        #expect(domain.authorMemberId == "7")
        #expect(domain.participants.first?.memberId == "7")
        #expect(domain.participants.first?.schoolId == "3")
        #expect(domain.participants.first?.id == "7")
    }

    @Test("서버가 정수를 숫자로 내려줘도 String 직렬화와 동일한 도메인 값을 만든다")
    func decodesNumberSerializedIdentifiersIdentically() throws {
        let stringSerialized = try decodeScheduleDetail(
            makeFullJSON(numericIdentifiers: false)
        ).toDomain()
        let numberSerialized = try decodeScheduleDetail(
            makeFullJSON(numericIdentifiers: true)
        ).toDomain()

        #expect(numberSerialized.scheduleId == "12")
        #expect(numberSerialized.authorMemberId == "7")
        #expect(numberSerialized.participants.first?.memberId == "7")
        #expect(numberSerialized.participants.first?.schoolId == "3")
        #expect(numberSerialized == stringSerialized)
    }

    // MARK: - 옵셔널 객체 & 누락 키

    @Test("location/attendancePolicy가 명시적 null이면 도메인에서 nil이다")
    func nullOptionalObjectsBecomeNil() throws {
        let json = """
        {
            "scheduleId": "12",
            "name": "비대면 세미나",
            "description": "",
            "tags": [],
            "startsAt": "2026-08-01T01:00:00Z",
            "endsAt": "2026-08-01T03:00:00Z",
            "isParticipant": true,
            "location": null,
            "participants": [],
            "authorMemberId": "7",
            "attendancePolicy": null,
            "attendanceStatus": null,
            "isAttendanceChecked": false,
            "isOnline": true
        }
        """

        let domain = try decodeScheduleDetail(json).toDomain()

        #expect(domain.location == nil)
        #expect(domain.attendancePolicy == nil)
        #expect(domain.attendanceStatus == nil)
        #expect(domain.requiresAttendanceApproval == false)
    }

    @Test("location/attendancePolicy/participants 키 자체가 없어도 안전하게 기본값으로 흡수된다")
    func missingKeysFallBackToDefaults() throws {
        let json = """
        {
            "scheduleId": "12",
            "name": "정기 회의",
            "description": "메모",
            "tags": ["회의"],
            "startsAt": "2026-08-01T01:00:00Z",
            "endsAt": "2026-08-01T03:00:00Z",
            "isParticipant": false
        }
        """

        let domain = try decodeScheduleDetail(json).toDomain()

        #expect(domain.location == nil)
        #expect(domain.attendancePolicy == nil)
        #expect(domain.attendanceStatus == nil)
        #expect(domain.participants.isEmpty)
        #expect(domain.participantMemberIds.isEmpty)
        #expect(domain.authorMemberId == "")
        #expect(domain.isAttendanceChecked == false)
        #expect(domain.isOnline == false)
    }

    @Test("location이 있으면 좌표/장소명이 그대로 도메인에 전달된다")
    func decodesLocation() throws {
        let domain = try decodeScheduleDetail(makeFullJSON(numericIdentifiers: false)).toDomain()

        #expect(domain.location?.latitude == 37.5665)
        #expect(domain.location?.longitude == 126.9780)
        #expect(domain.location?.locationName == "서울시청")
    }

    @Test("participants의 profileImageUrl이 null이면 도메인에서 빈 문자열로 정규화된다")
    func nullProfileImageUrlBecomesEmptyString() throws {
        let domain = try decodeScheduleDetail(makeFullJSON(numericIdentifiers: false)).toDomain()

        #expect(domain.participants.first?.profileImageUrl == "")
        #expect(domain.participants.first?.name == "홍길동")
        #expect(domain.participants.first?.schoolName == "UMC대학교")
    }

    // MARK: - 출석 상태 매핑

    @Test(
        "attendanceStatus raw 문자열이 도메인 enum으로 매핑된다",
        arguments: [
            ("PRESENT", ScheduleAttendanceStatus.present),
            ("EXCUSED", .present),
            ("LATE", .late),
            ("ABSENT", .absent),
            ("PENDING", .beforeAttendance),
            ("LATE_PENDING", .pendingApproval),
            ("FUTURE_NEW_TYPE_PENDING", .pendingApproval),
            ("TOTALLY_UNKNOWN", .beforeAttendance)
        ]
    )
    func mapsAttendanceStatus(rawValue: String, expected: ScheduleAttendanceStatus) throws {
        let json = makeMinimalJSON(extraFields: "\"attendanceStatus\": \"\(rawValue)\"")

        let domain = try decodeScheduleDetail(json).toDomain()

        #expect(domain.attendanceStatus == expected)
    }

    // MARK: - 출석 정책

    @Test("attendancePolicy 세 시각이 모두 유효하면 도메인 정책으로 변환된다")
    func decodesAttendancePolicy() throws {
        let domain = try decodeScheduleDetail(makeFullJSON(numericIdentifiers: false)).toDomain()
        let expectedLateEnd = ServerDateTimeConverter.parseUTCDateTime("2026-08-01T01:30:00Z")

        #expect(domain.requiresAttendanceApproval)
        #expect(domain.attendancePolicy?.lateEndAt == expectedLateEnd)
        #expect(domain.attendanceWindowEndsAt == domain.endsAt)
    }

    @Test("attendancePolicy의 시각 하나라도 파싱 불가하면 정책 전체가 nil이 된다")
    func invalidPolicyTimestampDropsPolicy() throws {
        let policy = """
        "attendancePolicy": {
            "checkInStartAt": "2026-08-01T00:30:00Z",
            "onTimeEndAt": "not-a-date",
            "lateEndAt": "2026-08-01T01:30:00Z"
        }
        """
        let json = makeMinimalJSON(extraFields: policy)

        let domain = try decodeScheduleDetail(json).toDomain()

        #expect(domain.attendancePolicy == nil)
        #expect(domain.requiresAttendanceApproval == false)
        #expect(domain.attendanceWindowEndsAt == domain.endsAt)
    }

    // MARK: - Bool 유연 디코딩

    @Test(
        "isOnline/isAttendanceChecked는 Bool/String/Int 어느 표현으로 와도 true로 해석된다",
        arguments: ["true", "\"true\"", "1"]
    )
    func decodesFlexibleBooleans(rawValue: String) throws {
        let json = makeMinimalJSON(
            extraFields: "\"isOnline\": \(rawValue), \"isAttendanceChecked\": \(rawValue)"
        )

        let domain = try decodeScheduleDetail(json).toDomain()

        #expect(domain.isOnline)
        #expect(domain.isAttendanceChecked)
    }

    // MARK: - 라운드트립

    @Test("encode(to:) 후 다시 디코딩하면 동일한 DTO가 복원된다")
    func encodeDecodeRoundTripPreservesValues() throws {
        let original = try decodeScheduleDetail(makeFullJSON(numericIdentifiers: true))

        let encoded = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(ScheduleDetailDTO.self, from: encoded)

        #expect(restored == original)
        #expect(restored.toDomain() == original.toDomain())
    }

    @Test("옵셔널 필드가 비어 있어도 라운드트립이 유지된다")
    func encodeDecodeRoundTripWithoutOptionalFields() throws {
        let original = try decodeScheduleDetail(makeMinimalJSON(extraFields: nil))

        let encoded = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(ScheduleDetailDTO.self, from: encoded)

        #expect(restored == original)
        #expect(restored.location == nil)
        #expect(restored.attendancePolicy == nil)
        #expect(restored.attendanceStatus == nil)
    }
}

// MARK: - Helpers

private func decodeScheduleDetail(_ json: String) throws -> ScheduleDetailDTO {
    try JSONDecoder().decode(ScheduleDetailDTO.self, from: Data(json.utf8))
}

/// 모든 확장 필드를 채운 응답 본문. `numericIdentifiers` 로 서버의 정수 직렬화 방식을 전환한다.
private func makeFullJSON(numericIdentifiers: Bool) -> String {
    let scheduleId = numericIdentifiers ? "12" : "\"12\""
    let memberId = numericIdentifiers ? "7" : "\"7\""
    let schoolId = numericIdentifiers ? "3" : "\"3\""

    return """
    {
        "scheduleId": \(scheduleId),
        "name": "정기 세미나",
        "description": "1층 대강당",
        "tags": ["세미나", "필수"],
        "startsAt": "2026-08-01T01:00:00Z",
        "endsAt": "2026-08-01T03:00:00Z",
        "isParticipant": true,
        "location": {
            "latitude": 37.5665,
            "longitude": 126.9780,
            "locationName": "서울시청"
        },
        "participants": [
            {
                "memberId": \(memberId),
                "name": "홍길동",
                "nickname": "길동",
                "profileImageUrl": null,
                "schoolId": \(schoolId),
                "schoolName": "UMC대학교"
            }
        ],
        "authorMemberId": \(memberId),
        "attendancePolicy": {
            "checkInStartAt": "2026-08-01T00:30:00Z",
            "onTimeEndAt": "2026-08-01T01:10:00Z",
            "lateEndAt": "2026-08-01T01:30:00Z"
        },
        "attendanceStatus": "PRESENT",
        "isAttendanceChecked": true,
        "isOnline": false
    }
    """
}

/// 필수 필드만 담은 응답 본문. `extraFields` 는 JSON 최상위에 그대로 병합된다.
private func makeMinimalJSON(extraFields: String?) -> String {
    let trailing = extraFields.map { ",\n    \($0)" } ?? ""

    return """
    {
        "scheduleId": "12",
        "name": "정기 세미나",
        "description": "",
        "tags": [],
        "startsAt": "2026-08-01T01:00:00Z",
        "endsAt": "2026-08-01T03:00:00Z",
        "isParticipant": true\(trailing)
    }
    """
}
