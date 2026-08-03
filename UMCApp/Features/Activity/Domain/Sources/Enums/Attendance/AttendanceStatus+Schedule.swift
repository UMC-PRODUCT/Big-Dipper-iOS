//
//  AttendanceStatus+Schedule.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 8/3/26.
//

import Foundation
import HomeDomain

// MARK: - HomeDomain 일정 출석 상태 브리지

extension AttendanceStatus {

    /// 일정 응답의 출석 상태(`HomeDomain`)를 출석 도메인 상태로 옮긴다.
    ///
    /// 두 enum 은 서버 contract 를 공유해 rawValue 가 같지만, `rawValue` 로 변환하면
    /// 한쪽에만 case 가 추가돼도 조용히 `nil`(또는 폴백)로 흡수돼 버린다. 명시적 switch 라
    /// case 가 늘어나면 컴파일이 깨져 대응 지점을 놓치지 않는다.
    ///
    /// - Note: Home 이 Activity 를 의존하지 않도록 두 enum 을 분리해 둔 설계라, 경계를
    ///   넘는 변환은 Activity 쪽에서 책임진다.
    public init(scheduleStatus: ScheduleAttendanceStatus) {
        switch scheduleStatus {
        case .beforeAttendance:
            self = .beforeAttendance
        case .pendingApproval:
            self = .pendingApproval
        case .present:
            self = .present
        case .late:
            self = .late
        case .absent:
            self = .absent
        }
    }
}
