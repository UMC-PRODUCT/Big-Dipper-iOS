//
//  StudyGroupUpdateRequestDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 2/18/26.
//

import Foundation

/// 스터디 그룹 수정 요청 DTO
///
/// `PATCH /api/v1/study-groups/{studyGroupId}` — 이름만 수정 가능
struct StudyGroupUpdateRequestDTO: Encodable {
    let name: String
}
