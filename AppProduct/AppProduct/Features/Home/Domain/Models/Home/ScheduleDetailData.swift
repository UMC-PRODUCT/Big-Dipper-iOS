//
//  ScheduleDetailData.swift
//  AppProduct
//
//  Created by euijjang97 on 2/13/26.
//

import Foundation

/// 일정 상세/목록 도메인 모델 (V2)
///
/// V2 스키마에서 목록과 상세 응답이 동일하므로 하나의 도메인 모델이 양쪽 화면을 모두 지원합니다.
/// 서버에서 사라진 V1 필드(`isAllDay`, `dDay`)는 KST 기준 계산 프로퍼티로 대체합니다.
struct ScheduleDetailData: Equatable, Identifiable, ScheduleDDayDisplayable {

    // MARK: - Property

    var id: UUID = .init()
    let scheduleId: Int
    let name: String
    let description: String
    let tags: [String]
    let startsAt: Date
    let endsAt: Date
    /// 장소 (`nil` = 비대면)
    let location: ScheduleLocation?
    let participants: [ScheduleParticipant]
    let authorMemberId: Int
    /// 출석 정책 (`nil` = 출석 비필수)
    let attendancePolicy: AttendancePolicy?
    /// 현재 사용자의 출석 상태 (서버가 내려주지 않으면 `nil`)
    let attendanceStatus: AttendanceStatus?
    let isAttendanceChecked: Bool
    let isOnline: Bool
    let isParticipant: Bool

    // MARK: - Computed (V1 호환성)

    /// V1 의 `isAllDay` 대체 — `(start...end)` 가 KST 기준 단일 일자의 0~86_399_999ms 인지
    var isAllDay: Bool {
        guard startsAt <= endsAt else { return false }
        return (startsAt...endsAt).isAllDayInKST
    }

    /// V1 의 `dDay` 대체 — KST 기준 오늘 자정과 일정 시작 자정의 일수 차
    ///
    /// 양수: 미래, 음수: 과거, 0: 오늘
    var dDay: Int {
        let calendar = Calendar.kstGregorian
        let today = calendar.startOfDay(for: .now)
        let target = calendar.startOfDay(for: startsAt)
        let components = calendar.dateComponents([.day], from: today, to: target)
        return components.day ?? 0
    }

    /// V1 의 `requiresAttendanceApproval` 대체
    var requiresAttendanceApproval: Bool {
        attendancePolicy != nil
    }

    /// V1 의 `participantMemberIds` 대체 (호환 호출처 보조용)
    var participantMemberIds: [Int] {
        participants.map(\.memberId)
    }

    /// V1 의 `status` 문자열 대체 — 종료/참여 여부 기반 표시 텍스트
    ///
    /// 종료된 일정이면 `"종료됨"`, 그렇지 않으면 참여 여부에 따라
    /// `"참여 예정"` 또는 `"참여 안 함"` 을 반환합니다.
    var participationStatusText: String {
        if Date() > endsAt {
            return "종료됨"
        }
        return isParticipant ? "참여 예정" : "참여 안 함"
    }
}
