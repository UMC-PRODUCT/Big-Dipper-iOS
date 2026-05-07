//
//  V2AttendanceParticipantDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation

/// V2 출석 현황 응답의 `participants[]` 항목 DTO
///
/// `GET /api/v2/schedules/attendance`, `GET /api/v2/schedules/{id}/attendance`
/// 양쪽 응답에서 동일한 형태로 사용됩니다.
///
/// - SeeAlso: ``ParticipantAttendance``, ``AttendanceStatusV2``
struct V2AttendanceParticipantDTO: Codable, Sendable, Equatable {

    /// 멤버 식별자
    let memberId: Int

    /// 본명
    let name: String

    /// 닉네임
    let nickname: String

    /// 프로필 이미지 URL
    let profileImageUrl: String?

    /// 학교 식별자
    let schoolId: Int

    /// 학교명
    let schoolName: String

    /// 출석 상태 raw 문자열
    ///
    /// `unknown` 폴백 디코딩을 위해 enum 이 아닌 String 으로 받고
    /// 도메인 변환 시 ``AttendanceStatusV2`` 로 매핑합니다.
    let attendanceStatus: String?

    /// GPS 위치 인증 여부
    let isLocationVerified: Bool

    /// 사유 결석 사유 (없으면 `nil` 또는 빈 문자열)
    let excuseReason: String?

    private enum CodingKeys: String, CodingKey {
        case memberId
        case name
        case nickname
        case profileImageUrl
        case schoolId
        case schoolName
        case attendanceStatus
        case isLocationVerified
        case excuseReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        memberId = try container.decodeIfPresent(Int.self, forKey: .memberId) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        schoolId = try container.decodeIfPresent(Int.self, forKey: .schoolId) ?? 0
        schoolName = try container.decodeIfPresent(String.self, forKey: .schoolName) ?? ""
        attendanceStatus = try container.decodeIfPresent(String.self, forKey: .attendanceStatus)
        isLocationVerified = try container.decodeIfPresent(Bool.self, forKey: .isLocationVerified) ?? false
        excuseReason = try container.decodeIfPresent(String.self, forKey: .excuseReason)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(name, forKey: .name)
        try container.encode(nickname, forKey: .nickname)
        try container.encodeIfPresent(profileImageUrl, forKey: .profileImageUrl)
        try container.encode(schoolId, forKey: .schoolId)
        try container.encode(schoolName, forKey: .schoolName)
        try container.encodeIfPresent(attendanceStatus, forKey: .attendanceStatus)
        try container.encode(isLocationVerified, forKey: .isLocationVerified)
        try container.encodeIfPresent(excuseReason, forKey: .excuseReason)
    }
}

// MARK: - Domain Mapping

extension V2AttendanceParticipantDTO {

    /// DTO → 도메인 변환
    ///
    /// `attendanceStatus` 가 nil 이거나 알 수 없는 값이면 ``AttendanceStatusV2/unknown`` 으로 매핑.
    /// `excuseReason` 이 빈 문자열이면 `nil` 로 정규화합니다.
    func toDomain() -> ParticipantAttendance {
        let status: AttendanceStatusV2 = {
            guard let raw = attendanceStatus else { return .unknown }
            return AttendanceStatusV2(rawValue: raw) ?? .unknown
        }()

        let normalizedReason: String? = {
            guard let reason = excuseReason, !reason.isEmpty else { return nil }
            return reason
        }()

        return ParticipantAttendance(
            memberId: memberId,
            name: name,
            nickname: nickname,
            profileImageUrl: profileImageUrl ?? "",
            schoolId: schoolId,
            schoolName: schoolName,
            attendanceStatus: status,
            isLocationVerified: isLocationVerified,
            excuseReason: normalizedReason
        )
    }
}
