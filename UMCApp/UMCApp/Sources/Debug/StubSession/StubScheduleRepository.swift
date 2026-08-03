//
//  StubScheduleRepository.swift
//  UMCApp
//
//  Created by jaewon Lee on 8/3/26.
//

#if DEBUG
import Foundation
import HomeDomain

/// 카카오 로그인 서버 미등록 기간 한정 홈 일정 Repository stub (절대규칙 #5).
///
/// 요청 기간 기준 상대 날짜로 픽스처를 생성하므로 달을 이동해도 일정이 표시된다.
struct StubScheduleRepository: ScheduleRepositoryProtocol {

    func fetchMySchedules(
        from: Date,
        to: Date,
        isAttendanceRequired: Bool
    ) async throws -> [Date: [ScheduleDetailData]] {
        StubSessionFixtures.schedules(from: from, to: to)
    }

    /// 서버 없이 화면을 보는 용도라 생성은 고정 식별자만 돌려준다.
    func createSchedule(_ request: ScheduleCreationRequest) async throws -> String {
        StubSessionFixtures.createdScheduleId
    }

    /// 저장소가 없으므로 삭제는 no-op 이다 (호출부의 롤백 흐름만 통과시킨다).
    func deleteSchedule(scheduleId: String) async throws {}
}
#endif
