//
//  ParticipantAttendance.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/17/26.
//

import Foundation

/// 운영진 시점에서 본 일정 참여자 출석 정보
///
/// 참여자 식별 정보(`name`, `nickname` 등)에 더해, 출석 상태와 GPS 인증 여부,
/// 사유 결석 사유까지 함께 보유하므로 운영진 현황 화면 구성
///
/// - SeeAlso: ``ScheduleAttendanceInfo``, ``ParticipantAttendanceStatus``
public struct ParticipantAttendance: Equatable, Sendable, Identifiable {

    /// 멤버 식별자 (서버 응답)
    public let memberId: String

    /// 본명
    public let name: String

    /// 닉네임
    public let nickname: String

    /// 프로필 이미지 URL (없으면 빈 문자열)
    public let profileImageURL: String

    /// 학교 식별자 (서버 응답)
    public let schoolId: String

    /// 학교명
    public let schoolName: String

    /// 출석 상태 (참여자 시점)
    public let attendanceStatus: ParticipantAttendanceStatus

    /// GPS 위치 인증 완료 여부
    public let isLocationVerified: Bool

    /// 사유 결석 사유 (없으면 `nil`)
    public let excuseReason: String?

    public var id: String { memberId }

    /// 표시용 이름 (닉네임이 있으면 "닉네임/이름", 없으면 이름만)
    ///
    /// 형제 모델 ``OperatorPendingMember/displayName`` 과 같은 규칙입니다. 다만 이 모델의
    /// `nickname` 은 옵셔널이 아니라 빈 문자열로 부재를 표현하므로 공백 여부로 판정합니다.
    public var displayName: String {
        nickname.isEmpty ? name : "\(nickname)/\(name)"
    }

    public init(
        memberId: String,
        name: String,
        nickname: String,
        profileImageURL: String,
        schoolId: String,
        schoolName: String,
        attendanceStatus: ParticipantAttendanceStatus,
        isLocationVerified: Bool,
        excuseReason: String?
    ) {
        self.memberId = memberId
        self.name = name
        self.nickname = nickname
        self.profileImageURL = profileImageURL
        self.schoolId = schoolId
        self.schoolName = schoolName
        self.attendanceStatus = attendanceStatus
        self.isLocationVerified = isLocationVerified
        self.excuseReason = excuseReason
    }
}
