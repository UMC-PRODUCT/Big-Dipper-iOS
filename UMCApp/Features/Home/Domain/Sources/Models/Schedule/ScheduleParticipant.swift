//
//  ScheduleParticipant.swift
//  HomeDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// 일정 참여자 도메인 모델
///
/// 서버 V2 일정 응답의 `participants` 배열 항목을 도메인으로 변환한 값이다.
/// 화면에서 즉시 이름/프로필을 표시할 수 있도록 식별자뿐 아니라 멤버 정보를 함께 보유한다.
public struct ScheduleParticipant: Equatable, Sendable, Identifiable {

    // MARK: - Property

    public var id: String { memberId }

    /// 멤버 식별자. 서버 정수를 핵심 규칙 #2에 따라 `String`으로 보존한다.
    public let memberId: String

    /// 본명
    public let name: String

    /// 닉네임
    public let nickname: String

    /// 프로필 이미지 URL (없으면 빈 문자열)
    public let profileImageUrl: String

    /// 학교 식별자. 서버 정수를 핵심 규칙 #2에 따라 `String`으로 보존한다.
    public let schoolId: String

    /// 학교명
    public let schoolName: String

    // MARK: - Init

    public init(
        memberId: String,
        name: String,
        nickname: String,
        profileImageUrl: String,
        schoolId: String,
        schoolName: String
    ) {
        self.memberId = memberId
        self.name = name
        self.nickname = nickname
        self.profileImageUrl = profileImageUrl
        self.schoolId = schoolId
        self.schoolName = schoolName
    }
}
