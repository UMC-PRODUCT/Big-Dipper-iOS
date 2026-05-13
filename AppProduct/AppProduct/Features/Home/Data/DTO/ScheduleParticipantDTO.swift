//
//  ScheduleParticipantDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation

/// V2 일정 응답의 `participants` 배열 항목 DTO
///
/// V1 의 `participantMemberIds: [Int]` 를 대체하는 풀 객체 형태입니다.
///
/// - SeeAlso: ``ScheduleParticipant``
struct ScheduleParticipantDTO: Codable, Sendable, Equatable {

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

    private enum CodingKeys: String, CodingKey {
        case memberId
        case name
        case nickname
        case profileImageUrl
        case schoolId
        case schoolName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        memberId = try container.decodeIntFlexibleIfPresent(forKey: .memberId) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        schoolId = try container.decodeIntFlexibleIfPresent(forKey: .schoolId) ?? 0
        schoolName = try container.decodeIfPresent(String.self, forKey: .schoolName) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(name, forKey: .name)
        try container.encode(nickname, forKey: .nickname)
        try container.encodeIfPresent(profileImageUrl, forKey: .profileImageUrl)
        try container.encode(schoolId, forKey: .schoolId)
        try container.encode(schoolName, forKey: .schoolName)
    }
}

// MARK: - Domain Mapping

extension ScheduleParticipantDTO {

    /// DTO → 도메인 변환
    func toDomain() -> ScheduleParticipant {
        ScheduleParticipant(
            memberId: memberId,
            name: name,
            nickname: nickname,
            profileImageUrl: profileImageUrl ?? "",
            schoolId: schoolId,
            schoolName: schoolName
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeIntFlexible(forKey key: Key) throws -> Int {
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }
        if let value = try? decode(String.self, forKey: key),
           let intValue = Int(value) {
            return intValue
        }
        if let value = try? decode(Double.self, forKey: key) {
            return Int(value)
        }
        throw DecodingError.typeMismatch(
            Int.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Expected Int/String-number/Double for key '\(key.stringValue)'"
            )
        )
    }

    func decodeIntFlexibleIfPresent(forKey key: Key) throws -> Int? {
        if (try? decodeNil(forKey: key)) == true {
            return nil
        }
        return try? decodeIntFlexible(forKey: key)
    }
}
