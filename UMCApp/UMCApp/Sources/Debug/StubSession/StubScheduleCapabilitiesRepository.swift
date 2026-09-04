//
//  StubScheduleCapabilitiesRepository.swift
//  UMCApp
//
//  Created by euijjang97 on 8/9/26.
//

#if DEBUG
import Foundation
import HomeDomain

/// 카카오 로그인 서버 미등록 기간 한정 일정 권한 Repository stub (핵심규칙 #5).
///
/// stub 세션은 운영진 화면까지 둘러보는 용도라 출석 정책 부착까지 열어 둔다.
struct StubScheduleCapabilitiesRepository: ScheduleCapabilitiesRepositoryProtocol {

    func fetchCapabilities() async throws -> ScheduleCapabilities {
        ScheduleCapabilities(
            canCreateSchedule: true,
            canCreateAttendanceRequiredSchedule: true,
            maxParticipantCount: "30"
        )
    }
}
#endif
