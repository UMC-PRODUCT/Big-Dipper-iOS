import Foundation
import HomeDomain
import Testing
import UMCFoundation
@testable import UMCWatchApp

@MainActor
@Suite("WatchAttendanceSessionViewModel — 정시·지각·지오펜스 파생")
struct WatchAttendanceSessionViewModelTests {

    // MARK: - Test

    @Test("지오펜스 경계는 50m 를 포함한다", arguments: [(49.9, true), (50.0, true), (50.1, false)])
    func geofenceBoundaryIncludesRadius(_ distanceMeters: Double, _ isInside: Bool) {
        let viewModel = Self.viewModel()

        viewModel.apply(distanceMeters: distanceMeters)

        #expect(viewModel.geofence.value?.isInside == isInside)
        #expect(viewModel.canCheckIn == isInside)
    }

    @Test("반경 안이고 시간창이 열려 있으면 출석할 수 있다")
    func allowsCheckInInsideOpenWindow() {
        let viewModel = Self.viewModel()

        viewModel.apply(distanceMeters: 12)

        #expect(viewModel.isOnTime)
        #expect(viewModel.canCheckIn)
        #expect(viewModel.disabledReason == nil)
    }

    @Test("측정 전에는 시간창과 무관하게 위치 확인 중 사유가 먼저 나온다")
    func locationReasonPrecedesTimeReason() {
        let tooEarly = Self.viewModel(startOffset: 3_600)

        #expect(tooEarly.disabledReason == "현재 위치를 확인하는 중입니다")

        tooEarly.remeasure()

        #expect(tooEarly.disabledReason == "현재 위치를 확인하는 중입니다")
    }

    @Test("반경 밖이면 이동 안내가 시간 사유보다 앞선다")
    func outOfRangeReasonPrecedesTimeReason() {
        let expired = Self.viewModel(startOffset: -86_400)

        expired.apply(distanceMeters: 72)

        #expect(expired.isOutOfRange)
        #expect(expired.disabledReason == "50m 이내로 이동한 뒤 다시 시도해 주세요")
    }

    @Test("측정 실패는 별도 사유로 구분한다")
    func failedMeasurementHasOwnReason() {
        let viewModel = Self.viewModel()

        viewModel.failGeofence(.unknown(message: "위치 권한 없음"))

        #expect(viewModel.disabledReason == "위치를 확인할 수 없습니다")
        #expect(viewModel.canCheckIn == false)
    }

    @Test(
        "위치가 확정된 뒤에는 시간창 사유가 드러난다",
        arguments: [(3_600.0, "출석 시작 전입니다"), (-86_400.0, "출석 인정 시간이 지났습니다")]
    )
    func exposesTimeReasonAfterMeasurement(_ startOffset: TimeInterval, _ reason: String) {
        let viewModel = Self.viewModel(startOffset: startOffset)

        viewModel.apply(distanceMeters: 12)

        #expect(viewModel.disabledReason == reason)
        #expect(viewModel.canCheckIn == false)
    }

    @Test("비대면 일정은 지오펜스를 요구하지 않는다")
    func onlineScheduleSkipsGeofence() {
        let viewModel = Self.viewModel(location: nil)

        #expect(viewModel.canCheckIn)
        #expect(viewModel.disabledReason == nil)
        #expect(viewModel.locationText == "비대면")
    }

    @Test("remeasure 는 확정된 측정값을 측정 중으로 되돌린다")
    func remeasureResetsToLoading() {
        let viewModel = Self.viewModel()
        viewModel.apply(distanceMeters: 72)

        viewModel.remeasure()

        #expect(viewModel.geofence.isLoading)
        #expect(viewModel.isOutOfRange == false)
        #expect(viewModel.locationText == "위치 확인 중")
    }

    @Test("마감 시각은 시간창을 따라간다")
    func deadlineFollowsTimeWindow() {
        let now = Date()
        let onTime = Self.viewModel(now: now)
        let lateWindow = Self.viewModel(startOffset: -900, now: now)
        let expired = Self.viewModel(startOffset: -86_400, now: now)

        #expect(onTime.deadline == onTime.schedule.attendancePolicy?.onTimeEndAt)
        #expect(lateWindow.isLateWindow)
        #expect(lateWindow.deadline == lateWindow.schedule.attendancePolicy?.lateEndAt)
        #expect(expired.deadline == nil)
    }

    @Test("서버 정책이 없으면 마감 시각을 지어내지 않는다")
    func hidesDeadlineWithoutPolicy() {
        let viewModel = WatchAttendanceSessionViewModel(
            schedule: .watchSample(attendancePolicy: nil)
        )

        #expect(viewModel.deadline == nil)
    }

    @Test("출석 요청은 출석 가능할 때만 기록된다")
    func requestsAttendanceOnlyWhenAllowed() {
        let blocked = Self.viewModel()
        blocked.apply(distanceMeters: 72)

        blocked.requestAttendance()

        #expect(blocked.didRequestAttendance == false)

        let allowed = Self.viewModel()
        allowed.apply(distanceMeters: 12)

        allowed.requestAttendance()

        #expect(allowed.didRequestAttendance)
    }

    // MARK: - Function

    private static func viewModel(
        startOffset: TimeInterval = 0,
        location: ScheduleLocation? = .watchSample,
        now: Date = Date()
    ) -> WatchAttendanceSessionViewModel {
        let startsAt = now.addingTimeInterval(startOffset)
        return WatchAttendanceSessionViewModel(
            schedule: .watchSample(
                startsAt: startsAt,
                location: location,
                attendancePolicy: .watchSample(around: startsAt)
            ),
            now: { now }
        )
    }
}
