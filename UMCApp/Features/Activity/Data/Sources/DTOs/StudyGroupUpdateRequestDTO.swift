//
//  StudyGroupUpdateRequestDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/26/26.
//

import Foundation

/// 스터디 그룹 수정 요청 DTO
///
/// `PATCH /api/v1/study-groups/{groupId}` body — 이름만 수정 가능합니다.
struct StudyGroupUpdateRequestDTO: Encodable, Sendable {
    /// 변경할 그룹 이름
    let name: String
}
