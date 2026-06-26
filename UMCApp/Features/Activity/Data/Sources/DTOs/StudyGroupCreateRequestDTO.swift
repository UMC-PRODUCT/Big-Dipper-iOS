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
/// - Note: 서버 식별자는 전 레이어 `String` 으로 통일하므로 `gisuId`·`memberIds`·`mentorIds`
///   를 문자열로 직렬화합니다. 레거시는 정수로 전송했으나, 신규 모듈은 형제
///   ``DecideAttendanceItemDTO`` 처럼 식별자를 문자열 와이어로 보냅니다. `part` 는
///   ``UMCFoundation/UMCPartType`` 의 `apiValue` 문자열입니다.
struct StudyGroupCreateRequestDTO: Encodable, Sendable {
    /// 기수 식별자 (서버 응답)
    let gisuId: String
    /// 그룹 이름
    let name: String
    /// 파트 API 값 (``UMCPartType/apiValue``)
    let part: String
    /// 스터디원 챌린저 식별자 목록 (서버 응답)
    let memberIds: [String]
    /// 담당 파트장(멘토) 챌린저 식별자 목록 (서버 응답)
    let mentorIds: [String]
}
