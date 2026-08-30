import Foundation
import HomeDomain
import Testing
import UMCFoundation
@testable import UMCWatchApp

@MainActor
@Suite("WatchAttendanceViewModel — 출석 목록 파생 상태")
struct WatchAttendanceViewModelTests {

    // MARK: - Test

    @Test("초기 상태는 idle 이고 beginLoading 이 loading 으로 옮긴다")
    func transitionsFromIdleToLoading() {
        let viewModel = WatchAttendanceViewModel()

        #expect(viewModel.schedules.isIdle)

        viewModel.beginLoading()

        #expect(viewModel.schedules.isLoading)
    }

    @Test("출석 정책이 없거나 참여자가 아닌 일정은 걸러낸다")
    func filtersNonAttendanceSchedules() {
        let viewModel = WatchAttendanceViewModel()

        viewModel.apply(schedules: [
            .watchSample(id: "1", attendancePolicy: nil),
            .watchSample(id: "2", isParticipant: false),
            .watchSample(id: "3"),
        ])

        #expect(viewModel.schedules.value?.map(\.scheduleId) == ["3"])
    }

    @Test("시작 시각 오름차순으로 정렬한다")
    func sortsByStartDate() {
        let viewModel = WatchAttendanceViewModel()
        let now = Date()

        viewModel.apply(schedules: [
            .watchSample(id: "late", startsAt: now.addingTimeInterval(3_600)),
            .watchSample(id: "early", startsAt: now.addingTimeInterval(-3_600)),
            .watchSample(id: "middle", startsAt: now),
        ])

        #expect(viewModel.schedules.value?.map(\.scheduleId) == ["early", "middle", "late"])
    }

    @Test("마감된 일정도 목록에 남긴다 — 워치는 마감 여부를 상태 라벨로 보여준다")
    func keepsExpiredSchedules() {
        let viewModel = WatchAttendanceViewModel()
        let start = Date().addingTimeInterval(-86_400)
        let expired = ScheduleDetailData.watchSample(
            id: "512",
            startsAt: start,
            attendancePolicy: .watchSample(around: start)
        )

        viewModel.apply(schedules: [expired])

        #expect(viewModel.schedules.value?.map(\.scheduleId) == ["512"])
        #expect(viewModel.statusText(for: expired) == "마감")
    }

    @Test("fail 은 failed 로 전이한다")
    func transitionsToFailed() {
        let viewModel = WatchAttendanceViewModel()

        viewModel.fail(.unknown(message: "연결 끊김"))

        #expect(viewModel.schedules.error == .unknown(message: "연결 끊김"))
    }

    @Test("정시 창과 지각 창만 진행 중으로 본다")
    func marksOnlyOpenWindowsAsInProgress() {
        let viewModel = WatchAttendanceViewModel()
        let now = Date()

        let onTime = ScheduleDetailData.watchSample(
            startsAt: now,
            attendancePolicy: .watchSample(around: now)
        )
        let lateWindow = ScheduleDetailData.watchSample(
            startsAt: now.addingTimeInterval(-900),
            attendancePolicy: .watchSample(around: now.addingTimeInterval(-900))
        )
        let tooEarly = ScheduleDetailData.watchSample(
            startsAt: now.addingTimeInterval(3_600),
            attendancePolicy: .watchSample(around: now.addingTimeInterval(3_600))
        )
        let expired = ScheduleDetailData.watchSample(
            startsAt: now.addingTimeInterval(-86_400),
            attendancePolicy: .watchSample(around: now.addingTimeInterval(-86_400))
        )

        #expect(viewModel.isInProgress(onTime, now: now))
        #expect(viewModel.isInProgress(lateWindow, now: now))
        #expect(viewModel.isInProgress(tooEarly, now: now) == false)
        #expect(viewModel.isInProgress(expired, now: now) == false)

        #expect(viewModel.status(for: onTime, now: now) == .active)
        #expect(viewModel.status(for: lateWindow, now: now) == .warning)
        #expect(viewModel.status(for: tooEarly, now: now) == .pending)
        #expect(viewModel.status(for: expired, now: now) == .error)
    }

    @Test("결과 푸시를 받기 전에는 대기(loading)다")
    func outcomeStaysLoadingUntilPushArrives() {
        let viewModel = WatchAttendanceViewModel()

        #expect(viewModel.outcome(for: "1024").isLoading)

        viewModel.apply(outcome: .present, for: "1024")

        #expect(viewModel.outcome(for: "1024") == .loaded(.present))
        #expect(viewModel.outcome(for: "2048").isLoading)
    }

    @Test("schedule(id:) 는 로드된 목록에서만 찾는다")
    func findsScheduleOnlyWhenLoaded() {
        let viewModel = WatchAttendanceViewModel()

        #expect(viewModel.schedule(id: "1024") == nil)

        viewModel.apply(schedules: [.watchSample(id: "1024")])

        #expect(viewModel.schedule(id: "1024")?.scheduleId == "1024")
        #expect(viewModel.schedule(id: "2048") == nil)
    }

    @Test("진행 중 행은 결과가 있어도 세션으로, 끝난 행만 결과로 보낸다")
    func routesInProgressRowToSession() {
        let viewModel = WatchAttendanceViewModel()
        let now = Date()

        let onTime = ScheduleDetailData.watchSample(
            id: "1024",
            startsAt: now,
            attendancePolicy: .watchSample(around: now)
        )
        let expired = ScheduleDetailData.watchSample(
            id: "512",
            startsAt: now.addingTimeInterval(-86_400),
            attendancePolicy: .watchSample(around: now.addingTimeInterval(-86_400))
        )
        viewModel.apply(outcome: .pending, for: "1024")
        viewModel.apply(outcome: .present, for: "512")

        #expect(
            viewModel.rowRoute(for: onTime, now: now) == .attendanceSession(scheduleID: "1024")
        )
        #expect(viewModel.rowRoute(for: expired, now: now) == .attendanceResult(scheduleID: "512"))
    }

    @Test("결과가 없는 마감 일정은 세션 화면으로 보낸다")
    func routesOutcomelessRowToSession() {
        let viewModel = WatchAttendanceViewModel()
        let now = Date()
        let expired = ScheduleDetailData.watchSample(
            id: "512",
            startsAt: now.addingTimeInterval(-86_400),
            attendancePolicy: .watchSample(around: now.addingTimeInterval(-86_400))
        )

        #expect(
            viewModel.rowRoute(for: expired, now: now) == .attendanceSession(scheduleID: "512")
        )
    }
}
