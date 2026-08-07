//
//  StubScheduleRepository.swift
//  UMCApp
//
//  Created by jaewon Lee on 8/3/26.
//

#if DEBUG
import Foundation
import HomeDomain
import UMCFoundation

/// 카카오 로그인 서버 미등록 기간 한정 홈 일정 Repository stub (절대규칙 #5).
///
/// 요청 기간 기준 상대 날짜로 픽스처를 생성하므로 달을 이동해도 일정이 표시된다.
struct StubScheduleRepository: ScheduleRepositoryProtocol {

    fileprivate enum Constants {
        /// 상세 조회용 픽스처 생성 창 (60일). 가장 먼 픽스처(+23일)를 충분히 덮는다.
        static let detailLookupWindow: TimeInterval = 60 * 60 * 24 * 60
    }

    func fetchMySchedules(
        from: Date,
        to: Date,
        isAttendanceRequired: Bool
    ) async throws -> [Date: [ScheduleDetailData]] {
        StubSessionFixtures.schedules(from: from, to: to)
    }

    /// 상세는 목록 픽스처에서 같은 식별자를 찾아 돌려준다.
    ///
    /// 픽스처가 요청 기간 기준 상대 날짜로 만들어지므로, 어느 달에서 진입하든 모든 후보가
    /// 생성되도록 오늘부터 넉넉한 창을 잡는다.
    func fetchScheduleDetail(scheduleId: String) async throws -> ScheduleDetailData {
        let now = Date.now
        let candidates = StubSessionFixtures.schedules(
            from: now,
            to: now.addingTimeInterval(Constants.detailLookupWindow)
        )

        guard let schedule = candidates.values
            .flatMap({ $0 })
            .first(where: { $0.scheduleId == scheduleId })
        else {
            throw RepositoryError.invalidResponse(
                detail: "stub 세션에 없는 일정입니다 (scheduleId: \(scheduleId))"
            )
        }

        return schedule
    }

    /// 서버 없이 화면을 보는 용도라 생성은 고정 식별자만 돌려준다.
    func createSchedule(_ request: ScheduleCreationRequest) async throws -> String {
        StubSessionFixtures.createdScheduleId
    }

    /// 저장소가 없으므로 삭제는 no-op 이다 (호출부의 롤백 흐름만 통과시킨다).
    func deleteSchedule(scheduleId: String) async throws {}
}
#endif
