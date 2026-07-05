//
//  AttendanceDecisionResponseDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/10/26.
//

import Foundation
import ActivityDomain
import UMCFoundation

/// 출석 결정 응답 DTO
///
/// 다음 세 엔드포인트의 공통 응답 구조입니다.
/// - `POST /api/v2/schedules/{scheduleId}/attendances/decide`
/// - `POST /api/v2/schedules/{scheduleId}/attendances/excuse`
/// - `POST /api/v2/schedules/{scheduleId}/attendances/request`
///
/// - SeeAlso: ``ActivityDomain/AttendanceDecisionResult``
struct AttendanceDecisionResponseDTO: Codable, Sendable, Equatable {

    /// 결정 시각 (UTC ISO8601, 미결정 시 `nil`)
    let decidedAt: String?

    /// 승인자 정보 (없으면 `nil`)
    let decisionMakerMemberInfo: DecisionMakerMemberInfoDTO?

    /// 운영진 결정 사유
    let decisionReason: String?

    /// 사유 결석 내용
    let excuseReason: String?

    /// 승인 대기 여부
    let isPendingDecision: Bool

    /// 위도 (사유 출석 보고 좌표)
    let latitude: Double?

    /// 경도 (사유 출석 보고 좌표)
    let longitude: Double?

    /// 출석 상태 raw 문자열 (`.unknown` 폴백 디코딩)
    let status: String

    private enum CodingKeys: String, CodingKey {
        case decidedAt
        case decisionMakerMemberInfo
        case decisionReason
        case excuseReason
        case isPendingDecision
        case latitude
        case longitude
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        decidedAt = try container.decodeIfPresent(String.self, forKey: .decidedAt)
        decisionMakerMemberInfo = try container.decodeIfPresent(
            DecisionMakerMemberInfoDTO.self, forKey: .decisionMakerMemberInfo
        )
        decisionReason = try container.decodeIfPresent(String.self, forKey: .decisionReason)
        excuseReason = try container.decodeIfPresent(String.self, forKey: .excuseReason)
        isPendingDecision = try container.decodeIfPresent(
            Bool.self, forKey: .isPendingDecision
        ) ?? false
        latitude = try container.decodeDoubleFlexibleIfPresent(forKey: .latitude)
        longitude = try container.decodeDoubleFlexibleIfPresent(forKey: .longitude)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(decidedAt, forKey: .decidedAt)
        try container.encodeIfPresent(decisionMakerMemberInfo, forKey: .decisionMakerMemberInfo)
        try container.encodeIfPresent(decisionReason, forKey: .decisionReason)
        try container.encodeIfPresent(excuseReason, forKey: .excuseReason)
        try container.encode(isPendingDecision, forKey: .isPendingDecision)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encode(status, forKey: .status)
    }
}

// MARK: - Nested DTO

extension AttendanceDecisionResponseDTO {

    /// 승인자 멤버 정보 DTO
    struct DecisionMakerMemberInfoDTO: Codable, Sendable, Equatable {

        /// 멤버 식별자 (서버 응답 — 전 레이어 String 통일)
        let memberId: String
        let name: String
        let nickname: String

        /// 학교 식별자 (서버 응답 — 전 레이어 String 통일)
        let schoolId: String
        let schoolName: String

        private enum CodingKeys: String, CodingKey {
            case memberId, name, nickname, schoolId, schoolName
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            memberId = container.decodeFlexibleStringOrNil(forKey: .memberId) ?? ""
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
            nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
            schoolId = container.decodeFlexibleStringOrNil(forKey: .schoolId) ?? ""
            schoolName = try container.decodeIfPresent(String.self, forKey: .schoolName) ?? ""
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(memberId, forKey: .memberId)
            try container.encode(name, forKey: .name)
            try container.encode(nickname, forKey: .nickname)
            try container.encode(schoolId, forKey: .schoolId)
            try container.encode(schoolName, forKey: .schoolName)
        }
    }
}

// MARK: - Domain Mapping

extension AttendanceDecisionResponseDTO {

    /// DTO → 도메인 변환
    ///
    /// - `status` 미지원 값은 `.unknown` 으로 폴백.
    /// - 빈 사유 문자열은 `nil` 로 정규화.
    /// - 서버의 `hasDecisionMakerMember` 플래그는 매핑하지 않습니다. 도메인 모델이
    ///   `decisionMakerMemberInfo != nil` 로 파생하므로(단일 정보원), 플래그를 전달하면
    ///   `info == nil && flag == true` 같은 불일치를 다시 들여오게 됩니다.
    func toDomain() -> AttendanceDecisionResult {
        let mappedStatus = ParticipantAttendanceStatus(rawValue: status) ?? .unknown

        let makerInfo = decisionMakerMemberInfo.map {
            AttendanceDecisionResult.DecisionMakerInfo(
                memberId: $0.memberId,
                name: $0.name,
                nickname: $0.nickname,
                schoolId: $0.schoolId,
                schoolName: $0.schoolName
            )
        }

        return AttendanceDecisionResult(
            status: mappedStatus,
            decidedAt: decidedAt.flatMap { ServerDateTimeConverter.parseUTCDateTime($0) },
            decisionReason: decisionReason.flatMap { $0.isEmpty ? nil : $0 },
            excuseReason: excuseReason.flatMap { $0.isEmpty ? nil : $0 },
            latitude: latitude,
            longitude: longitude,
            decisionMakerMemberInfo: makerInfo,
            isPendingDecision: isPendingDecision
        )
    }
}
