//
//  ParticipantAttendance.swift
//  AppProduct
//
//  Created by JEONG on 5/6/26.
//

import Foundation

/// 운영진 출석 현황 화면의 참여자별 출석 정보 도메인 모델
///
/// `GET /api/v2/schedules/attendance` 또는 `GET /api/v2/schedules/{id}/attendance`
/// 응답의 `participants[]` 항목을 도메인으로 변환한 값입니다.
///
/// V1 의 `ScheduleParticipant` 와 달리 출석 상태(`attendanceStatus`),
/// GPS 인증 여부(`isLocationVerified`), 사유 결석 사유(`excuseReason`) 를 포함합니다.
///
/// - SeeAlso: ``ScheduleAttendanceInfo``, ``AttendanceStatusV2``
struct ParticipantAttendance: Equatable, Sendable, Identifiable {

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

    /// 출석 상태 (V2)
    let attendanceStatus: AttendanceStatusV2

    /// GPS 위치 인증 완료 여부
    let isLocationVerified: Bool

    /// 사유 결석 사유 (없으면 `nil`)
    let excuseReason: String?

    var id: Int { memberId }
}
