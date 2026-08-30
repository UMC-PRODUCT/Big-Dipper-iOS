import Testing
@testable import UMCWatchApp

@Suite("WatchRouter — 단일 네비게이션 스택")
struct WatchRouterTests {

    // MARK: - Test

    @Test("push 하면 스택이 쌓이고 순서가 유지된다")
    func pushAppendsRoutesInOrder() {
        let router = WatchRouter()

        router.push(.attendanceList)
        router.push(.attendanceSession(scheduleID: "1024"))

        #expect(router.path == [.attendanceList, .attendanceSession(scheduleID: "1024")])
    }

    @Test("pop 은 마지막 라우트만 제거한다")
    func popRemovesLastRoute() {
        let router = WatchRouter()
        router.push(.pingList)
        router.push(.pingDetail(noticeID: "42"))

        router.pop()

        #expect(router.path == [.pingList])
    }

    @Test("빈 스택에서 pop 해도 크래시하지 않는다")
    func popOnEmptyStackIsSafe() {
        let router = WatchRouter()

        router.pop()

        #expect(router.path.isEmpty)
    }

    @Test("popToRoot 는 스택을 비운다")
    func popToRootClearsStack() {
        let router = WatchRouter()
        router.push(.attendanceList)
        router.push(.attendanceResult(scheduleID: "1024"))

        router.popToRoot()

        #expect(router.path.isEmpty)
    }

    @Test("같은 식별자의 라우트는 같고, 다른 식별자면 다르다")
    func routeEqualityFollowsIdentifier() {
        #expect(
            WatchRoute.attendanceSession(scheduleID: "1024")
                == .attendanceSession(scheduleID: "1024")
        )
        #expect(
            WatchRoute.attendanceSession(scheduleID: "1024")
                != .attendanceSession(scheduleID: "2048")
        )
        #expect(WatchRoute.pingDetail(noticeID: "42") != .attendanceResult(scheduleID: "42"))
    }

    @Test("폴백 3종이 모두 라우트로 감싸져 스택에 쌓인다")
    func fallbackRoutesArePushable() {
        let router = WatchRouter()

        for fallback in WatchFallbackRoute.allCases {
            router.push(.fallback(fallback))
        }

        #expect(router.path == WatchFallbackRoute.allCases.map(WatchRoute.fallback))
        #expect(router.path.count == 3)
    }
}
