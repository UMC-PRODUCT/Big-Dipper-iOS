import Testing
@testable import UMCWatchApp

@Suite("WatchMandatoryNoticeCenter — 확인 전까지 유지되는 배너 상태")
struct WatchMandatoryNoticeTests {

    // MARK: - Test

    @Test("present 이후 confirm 전까지 pending 이 유지된다")
    func pendingPersistsUntilConfirmed() {
        let center = WatchMandatoryNoticeCenter()
        let notice = WatchMandatoryNotice(id: "1", title: "필독 공지")

        center.present(notice)

        #expect(center.pending == notice)
    }

    @Test("confirm 을 누르면 pending 이 nil 이 된다")
    func confirmClearsPending() {
        let center = WatchMandatoryNoticeCenter()
        center.present(WatchMandatoryNotice(id: "1", title: "필독 공지"))

        center.confirm()

        #expect(center.pending == nil)
    }

    @Test("다른 공지를 present 하면 이전 공지를 교체한다")
    func presentingAnotherNoticeReplacesThePrevious() {
        let center = WatchMandatoryNoticeCenter()
        center.present(WatchMandatoryNotice(id: "1", title: "첫 번째 공지"))

        center.present(WatchMandatoryNotice(id: "2", title: "두 번째 공지"))

        #expect(center.pending == WatchMandatoryNotice(id: "2", title: "두 번째 공지"))
    }
}
