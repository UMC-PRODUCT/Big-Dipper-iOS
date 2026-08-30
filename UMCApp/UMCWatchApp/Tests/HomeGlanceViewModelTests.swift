import Foundation
import Testing
@testable import UMCWatchApp

@Suite("HomeGlanceViewModel — 글랜스 파생 표시값")
struct HomeGlanceViewModelTests {

    // MARK: - Test

    @Test("세션이 없으면 출석 목록으로 보낸다")
    func routesToListWithoutSession() {
        let viewModel = HomeGlanceViewModel(glance: .empty)

        #expect(viewModel.hasSession == false)
        #expect(viewModel.attendanceRoute == .attendanceList)
        #expect(viewModel.emptySessionMessage == "오늘 세션 없음")
    }

    @Test("세션이 있으면 해당 스케줄의 출석 화면으로 보낸다")
    func routesToSessionWhenPresent() {
        let viewModel = HomeGlanceViewModel(glance: Self.glance(sessionID: "1024"))

        #expect(viewModel.hasSession)
        #expect(viewModel.attendanceRoute == .attendanceSession(scheduleID: "1024"))
    }

    @Test("승인 대기 0건이면 배지를 감춘다")
    func hidesPendingApprovalLabelWhenZero() {
        let viewModel = HomeGlanceViewModel(glance: Self.glance(pendingApprovalCount: "0"))

        #expect(viewModel.pendingApprovalLabel == nil)
    }

    @Test("승인 대기 N건이면 건수를 문구로 낸다")
    func showsPendingApprovalLabelWhenPositive() {
        let viewModel = HomeGlanceViewModel(glance: Self.glance(pendingApprovalCount: "3"))

        #expect(viewModel.pendingApprovalLabel == "승인 대기 3건")
    }

    @Test("미확인 공지 0건이면 빈 상태 문구를 낸다")
    func showsEmptyPingLabelWhenZero() {
        let viewModel = HomeGlanceViewModel(glance: Self.glance(unreadPingCount: "0"))

        #expect(viewModel.hasUnreadPing == false)
        #expect(viewModel.unreadPingLabel == "새 공지 없음")
    }

    @Test("미확인 공지 N건이면 건수를 문구로 낸다")
    func showsUnreadPingCount() {
        let viewModel = HomeGlanceViewModel(glance: Self.glance(unreadPingCount: "5"))

        #expect(viewModel.hasUnreadPing)
        #expect(viewModel.unreadPingLabel == "미확인 5건")
    }

    @Test(
        "숫자가 아닌 카운트는 0건으로 취급한다",
        arguments: ["", "abc", "-1", "3건"]
    )
    func treatsNonNumericCountAsZero(_ rawValue: String) {
        let viewModel = HomeGlanceViewModel(
            glance: Self.glance(pendingApprovalCount: rawValue, unreadPingCount: rawValue)
        )

        #expect(viewModel.pendingApprovalLabel == nil)
        #expect(viewModel.unreadPingLabel == "새 공지 없음")
    }

    // MARK: - Function

    private static func glance(
        sessionID: String? = nil,
        pendingApprovalCount: String = "0",
        unreadPingCount: String = "0"
    ) -> WatchGlance {
        WatchGlance(
            session: sessionID.map {
                GlanceSession(id: $0, title: "5주차 정기 세션", startsAt: .now, status: .active)
            },
            pendingApprovalCount: pendingApprovalCount,
            unreadPingCount: unreadPingCount
        )
    }
}
