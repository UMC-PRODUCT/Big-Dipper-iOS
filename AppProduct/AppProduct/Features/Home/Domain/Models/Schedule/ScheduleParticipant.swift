//
//  ScheduleParticipant.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation

/// 일정 참여자 도메인 모델
///
/// 서버 V2 일정 응답의 `participants` 배열 항목을 도메인으로 변환한 값입니다.
/// V1 의 `participantMemberIds: [Int]` 가 풀 객체 배열로 확장됨에 따라
/// 화면에서 즉시 이름/프로필 등을 표시할 수 있도록 멤버 정보를 함께 보유합니다.
struct ScheduleParticipant: Equatable, Sendable, Identifiable {

    /// 멤버 식별자
    let memberId: Int

    /// 본명
    let name: String

    /// 닉네임
    let nickname: String

    /// 프로필 이미지 URL (없으면 빈 문자열)
    let profileImageUrl: String

    /// 학교 식별자
    let schoolId: Int

    /// 학교명
    let schoolName: String

    var id: Int { memberId }
}
