//
//  ScheduleAttendanceInfo.swift
//  AppProduct
//
//  Created by JEONG on 5/6/26.
//

import Foundation

/// 운영진 출석 현황 도메인 모델 (목록/단일 공용)
///
/// V2 신규 엔드포인트 응답을 도메인으로 변환한 값입니다.
/// - 목록: `GET /api/v2/schedules/attendance` (배열)
/// - 단일: `GET /api/v2/schedules/{id}/attendance` (객체)
///
/// 두 엔드포인트의 응답 스키마는 동일하므로 단일 도메인 모델로 표현합니다.
/// 클라이언트는 이 모델을 받아 필터링/카운팅을 수행합니다.
///
/// 서버에서 직책 역할별로 조회 범위가 자동 분기되므로
/// (중앙 총괄단/운영진/회장단/파트장/기타), 클라이언트는 권한 분기 없이 호출합니다.
///
/// - SeeAlso: ``ParticipantAttendance``, ``ScheduleAttendanceFilter``
struct ScheduleAttendanceInfo: Equatable, Sendable, Identifiable {

    /// 일정 식별자
    let scheduleId: Int

    /// 일정 제목
    let name: String

    /// 일정 설명 (메모)
    let description: String

    /// 시작 일시
    let startsAt: Date

    /// 종료 일시
    let endsAt: Date

    /// 장소 (`nil` = 비대면)
    let location: ScheduleLocation?

    /// 비대면 일정 여부
    ///
    /// 서버 `isOnline` 필드 직접 노출 (`location` 이 `nil` 인 경우와 일치하는 것이 정상).
    let isOnline: Bool

    /// 작성자 멤버 ID
    let authorMemberId: Int

    /// 출석 정책 (`nil` = 정책 미부착, SCHEDULE-0021 발생 가능)
    let attendancePolicy: AttendancePolicy?

    /// 카테고리 태그 (e.g., `"LEADERSHIP"`)
    let tags: [String]

    /// 참여자별 출석 정보
    let participants: [ParticipantAttendance]

    var id: Int { scheduleId }

    // MARK: - Helpers

    /// 출석 인원 카운트 (`PRESENT` + `EXCUSED` + `LATE`)
    ///
    /// V1 출석 통계의 `presentCount` 를 V2 응답에서 직접 계산할 때 사용합니다.
    var presentCount: Int {
        participants.filter {
            switch $0.attendanceStatus {
            case .present, .excused, .late:
                return true
            default:
                return false
            }
        }.count
    }

    /// 승인 대기 인원 카운트
    var pendingCount: Int {
        participants.filter(\.attendanceStatus.isPending).count
    }

    /// 전체 참여자 수
    var totalCount: Int { participants.count }

    /// 출석률 (0.0 - 1.0)
    var attendanceRate: Double {
        guard totalCount > 0 else { return 0.0 }
        return Double(presentCount) / Double(totalCount)
    }
}
