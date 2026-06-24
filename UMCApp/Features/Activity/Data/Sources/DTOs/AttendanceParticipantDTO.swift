//
//  AttendanceParticipantDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/10/26.
//

import Foundation
import ActivityDomain

/// 출석 현황 응답의 `participants[]` 항목 DTO
///
/// 목록(`GET /api/v2/schedules/attendance`)·단일(`GET /api/v2/schedules/{id}/attendance`)
/// 양쪽 응답에서 동일한 형태로 사용됩니다.
///
/// - SeeAlso: ``ActivityDomain/ParticipantAttendance``, ``ActivityDomain/ParticipantAttendanceStatus``
struct AttendanceParticipantDTO: Codable, Sendable, Equatable {

    /// 멤버 식별자 (서버 응답 — 전 레이어 String 통일)
    let memberId: String

    /// 본명
    let name: String

    /// 닉네임
    let nickname: String

    /// 프로필 이미지 URL (없으면 `nil`)
    let profileImageURL: String?

    /// 학교 식별자 (서버 응답 — 전 레이어 String 통일)
    let schoolId: String

    /// 학교명
    let schoolName: String

    /// 출석 상태 raw 문자열
    ///
    /// `.unknown` 폴백 디코딩을 위해 enum 이 아닌 String 으로 받고 도메인 변환 시
    /// ``ActivityDomain/ParticipantAttendanceStatus`` 로 매핑합니다.
    let attendanceStatus: String?

    /// GPS 위치 인증 여부
    let isLocationVerified: Bool

    /// 사유 결석 사유 (없으면 `nil` 또는 빈 문자열)
    let excuseReason: String?

    private enum CodingKeys: String, CodingKey {
        case memberId
        case name
        case nickname
        case profileImageURL = "profileImageUrl"
        case schoolId
        case schoolName
        case attendanceStatus
        case isLocationVerified
        case excuseReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        memberId = try container.decodeFlexibleStringIfPresent(forKey: .memberId) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL)
        schoolId = try container.decodeFlexibleStringIfPresent(forKey: .schoolId) ?? ""
        schoolName = try container.decodeIfPresent(String.self, forKey: .schoolName) ?? ""
        attendanceStatus = try container.decodeIfPresent(String.self, forKey: .attendanceStatus)
        isLocationVerified = try container.decodeIfPresent(
            Bool.self, forKey: .isLocationVerified
        ) ?? false
        excuseReason = try container.decodeIfPresent(String.self, forKey: .excuseReason)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(name, forKey: .name)
        try container.encode(nickname, forKey: .nickname)
        try container.encodeIfPresent(profileImageURL, forKey: .profileImageURL)
        try container.encode(schoolId, forKey: .schoolId)
        try container.encode(schoolName, forKey: .schoolName)
        try container.encodeIfPresent(attendanceStatus, forKey: .attendanceStatus)
        try container.encode(isLocationVerified, forKey: .isLocationVerified)
        try container.encodeIfPresent(excuseReason, forKey: .excuseReason)
    }
}

// MARK: - Domain Mapping

extension AttendanceParticipantDTO {

    /// DTO → 도메인 변환
    ///
    /// `attendanceStatus` 가 nil/미지원 값이면 `.unknown` 으로 폴백하고, `excuseReason` 이
    /// 빈 문자열이면 `nil` 로 정규화합니다.
    func toDomain() -> ParticipantAttendance {
        let status = attendanceStatus
            .flatMap { ParticipantAttendanceStatus(rawValue: $0) } ?? .unknown

        let normalizedReason = excuseReason.flatMap { $0.isEmpty ? nil : $0 }

        return ParticipantAttendance(
            memberId: memberId,
            name: name,
            nickname: nickname,
            profileImageURL: profileImageURL ?? "",
            schoolId: schoolId,
            schoolName: schoolName,
            attendanceStatus: status,
            isLocationVerified: isLocationVerified,
            excuseReason: normalizedReason
        )
    }
}
