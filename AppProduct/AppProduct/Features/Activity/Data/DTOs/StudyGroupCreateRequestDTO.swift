//
//  StudyGroupCreateRequestDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 2/26/26.
//

import Foundation

/// 스터디 그룹 생성 요청 DTO
///
/// `POST /api/v1/study-groups`
struct StudyGroupCreateRequestDTO: Codable, Sendable, Equatable {
    /// 기수 ID
    let gisuId: Int

    /// 그룹 이름
    let name: String

    /// 파트(API 값)
    let part: String

    /// 스터디원 챌린저 ID 목록
    let memberIds: [Int]

    /// 담당 파트장(멘토) 챌린저 ID 목록
    let mentorIds: [Int]
}
