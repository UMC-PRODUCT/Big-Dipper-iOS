//
//  StudyGroupCreateRequestDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/26/26.
//

import Foundation

/// 스터디 그룹 생성 요청 DTO
///
/// `POST /api/v1/study-groups` body. 운영진이 새 스터디 그룹을 만들 때 기수·이름·파트와
/// 함께 스터디원/멘토 식별자 목록을 전달합니다.
///
/// - Note: 서버가 이 엔드포인트의 식별자를 정수로 받으므로 `gisuId`·`memberIds`·`mentorIds`
///   를 `Int`/`[Int]` 로 보냅니다. 응답의 정수는 `String` 으로 다루지만 요청 본문은 정수
///   그대로 보내며, `String`→`Int` 변환은 ``StudyRepository`` 에서 이 DTO 를 만들 때 합니다.
///   `part` 는 ``UMCFoundation/UMCPartType`` 의 `apiValue` 문자열입니다.
struct StudyGroupCreateRequestDTO: Encodable, Sendable {
    /// 기수 식별자
    let gisuId: Int
    /// 그룹 이름
    let name: String
    /// 파트 API 값 (``UMCPartType/apiValue``)
    let part: String
    /// 스터디원 챌린저 식별자 목록
    let memberIds: [Int]
    /// 담당 파트장(멘토) 챌린저 식별자 목록
    let mentorIds: [Int]
}
