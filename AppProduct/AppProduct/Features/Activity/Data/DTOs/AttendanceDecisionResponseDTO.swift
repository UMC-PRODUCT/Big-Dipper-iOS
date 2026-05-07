//
//  AttendanceDecisionResponseDTO.swift
//  AppProduct
//

import Foundation

/// 출석 결정 응답 DTO
///
/// `POST /api/v2/schedules/{scheduleId}/attendances/decide`,
/// `POST /api/v2/schedules/{scheduleId}/attendances/excuse`,
/// `POST /api/v2/schedules/{scheduleId}/attendances/request`
/// 공통 응답 구조.
struct AttendanceDecisionResponseDTO: Codable, Sendable {

    let decidedAt: String?
    let decisionMakerMemberInfo: DecisionMakerMemberInfoDTO?
    let decisionReason: String?
    let excuseReason: String?
    let hasDecisionMakerMember: Bool
    let isPendingDecision: Bool
    let latitude: Double?
    let longitude: Double?
    /// AttendanceStatusV2 raw 값 — unknown 폴백 디코딩
    let status: String

    private enum CodingKeys: String, CodingKey {
        case decidedAt
        case decisionMakerMemberInfo
        case decisionReason
        case excuseReason
        case hasDecisionMakerMember
        case isPendingDecision
        case latitude
        case longitude
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        decidedAt = try container.decodeIfPresent(String.self, forKey: .decidedAt)
        decisionMakerMemberInfo = try container.decodeIfPresent(
            DecisionMakerMemberInfoDTO.self,
            forKey: .decisionMakerMemberInfo
        )
        decisionReason = try container.decodeIfPresent(String.self, forKey: .decisionReason)
        excuseReason = try container.decodeIfPresent(String.self, forKey: .excuseReason)
        hasDecisionMakerMember = try container.decodeIfPresent(
            Bool.self, forKey: .hasDecisionMakerMember
        ) ?? false
        isPendingDecision = try container.decodeIfPresent(
            Bool.self, forKey: .isPendingDecision
        ) ?? false
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(decidedAt, forKey: .decidedAt)
        try container.encodeIfPresent(decisionMakerMemberInfo, forKey: .decisionMakerMemberInfo)
        try container.encodeIfPresent(decisionReason, forKey: .decisionReason)
        try container.encodeIfPresent(excuseReason, forKey: .excuseReason)
        try container.encode(hasDecisionMakerMember, forKey: .hasDecisionMakerMember)
        try container.encode(isPendingDecision, forKey: .isPendingDecision)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encode(status, forKey: .status)
    }
}

// MARK: - Nested DTO

extension AttendanceDecisionResponseDTO {

    struct DecisionMakerMemberInfoDTO: Codable, Sendable {
        let memberId: Int
        let name: String
        let nickname: String
        let schoolId: Int
        let schoolName: String

        private enum CodingKeys: String, CodingKey {
            case memberId, name, nickname, schoolId, schoolName
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            memberId = try container.decodeIfPresent(Int.self, forKey: .memberId) ?? 0
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
            nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
            schoolId = try container.decodeIfPresent(Int.self, forKey: .schoolId) ?? 0
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

    func toDomain() -> AttendanceDecisionResult {
        let attendanceStatus = AttendanceStatusV2(rawValue: status) ?? .unknown

        let decidedAtDate: Date? = {
            guard let raw = decidedAt else { return nil }
            return ISO8601DateFormatter().date(from: raw)
        }()

        let makerInfo: AttendanceDecisionResult.DecisionMakerInfo? = decisionMakerMemberInfo.map {
            AttendanceDecisionResult.DecisionMakerInfo(
                memberId: $0.memberId,
                name: $0.name,
                nickname: $0.nickname,
                schoolId: $0.schoolId,
                schoolName: $0.schoolName
            )
        }

        return AttendanceDecisionResult(
            status: attendanceStatus,
            decidedAt: decidedAtDate,
            decisionReason: decisionReason.flatMap { $0.isEmpty ? nil : $0 },
            excuseReason: excuseReason.flatMap { $0.isEmpty ? nil : $0 },
            latitude: latitude,
            longitude: longitude,
            decisionMakerMemberInfo: makerInfo,
            hasDecisionMakerMember: hasDecisionMakerMember,
            isPendingDecision: isPendingDecision
        )
    }
}
