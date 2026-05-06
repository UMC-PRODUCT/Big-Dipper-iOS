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
