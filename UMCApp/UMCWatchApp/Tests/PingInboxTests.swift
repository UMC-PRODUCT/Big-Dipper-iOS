import Foundation
import Testing
import CoreWatchConnectivity
import UMCFoundation
@testable import UMCWatchApp

@Suite("PingInbox — The Ping 수신함")
@MainActor
struct PingInboxTests {

    // MARK: - Function

    private func snapshot(
        isSignedIn: Bool = true,
        notices: [WatchNotice] = [],
        generatedAt: Date = Date(timeIntervalSince1970: 1_800_000_000)
    ) -> WatchSessionState {
        WatchSessionState(
            isSignedIn: isSignedIn,
            schedules: [],
            notices: notices,
            generatedAt: generatedAt
        )
    }

    private func notice(id: String, isRead: Bool = false) -> WatchNotice {
        WatchNotice(
            noticeId: id,
            title: "공지 \(id)",
            content: "본문",
            writer: "운영진",
            postedAt: Date(timeIntervalSince1970: 1_800_000_000),
            isMustRead: false,
            isAlert: false,
            isRead: isRead
        )
    }

    // MARK: - Test · 상태

    @Test("스냅샷이 없으면 로딩이다")
    func stateIsLoadingWithoutSnapshot() {
        let inbox = PingInbox.preview(snapshot: nil)

        #expect(inbox.state.isLoading)
    }

    @Test("스냅샷이 없고 동기화가 실패했으면 실패를 그린다")
    func stateFailsWhenNothingToShow() {
        let inbox = PingInbox.preview(snapshot: nil, syncFailure: .network(.noNetwork))

        #expect(inbox.state.error == .network(.noNetwork))
    }

    @Test("스냅샷이 있으면 동기화 실패보다 캐시를 우선한다")
    func cachedSnapshotWinsOverSyncFailure() {
        let inbox = PingInbox.preview(
            snapshot: snapshot(notices: [notice(id: "1")]),
            syncFailure: .network(.noNetwork)
        )

        #expect(inbox.state.value?.map(\.id) == ["1"])
        #expect(inbox.isShowingStaleSnapshot)
    }

    @Test("로그아웃 스냅샷은 목록 대신 인증 실패를 낸다")
    func signedOutSnapshotFailsWithAuthError() {
        let inbox = PingInbox.preview(snapshot: snapshot(isSignedIn: false))

        #expect(inbox.state.error == .auth(.notLoggedIn))
    }

    @Test("공지가 없으면 빈 목록으로 로드된다 — 실패가 아니다")
    func emptySnapshotLoadsEmptyList() {
        let inbox = PingInbox.preview(snapshot: snapshot())

        #expect(inbox.state.value?.isEmpty == true)
    }

    @Test("낙관적 읽음이 목록에 반영된다")
    func readReceiptAppliesToList() {
        let inbox = PingInbox.preview(
            snapshot: snapshot(notices: [notice(id: "1"), notice(id: "2")]),
            readReceiptIDs: ["2"]
        )

        #expect(inbox.item(id: "2")?.isRead == true)
        #expect(inbox.item(id: "1")?.isRead == false)
    }

    @Test("목록에 없는 식별자는 nil 이다")
    func itemLookupReturnsNilForUnknownID() {
        let inbox = PingInbox.preview(snapshot: snapshot(notices: [notice(id: "1")]))

        #expect(inbox.item(id: "999") == nil)
    }

    // MARK: - Test · 스냅샷 선택

    @Test("두 출처 중 generatedAt 이 새로운 스냅샷을 고른다")
    func latestPicksNewerSnapshot() {
        let older = snapshot(generatedAt: Date(timeIntervalSince1970: 100))
        let newer = snapshot(generatedAt: Date(timeIntervalSince1970: 200))

        #expect(PingInbox.latest(older, newer)?.generatedAt == newer.generatedAt)
        #expect(PingInbox.latest(newer, older)?.generatedAt == newer.generatedAt)
    }

    @Test("동률이면 iPhone 이 퍼블리시한 컨텍스트를 택한다")
    func latestPrefersContextOnTie() {
        let generatedAt = Date(timeIntervalSince1970: 100)
        let context = snapshot(notices: [notice(id: "context")], generatedAt: generatedAt)
        let synced = snapshot(notices: [notice(id: "synced")], generatedAt: generatedAt)

        #expect(PingInbox.latest(context, synced)?.notices.first?.noticeId == "context")
    }

    @Test("한쪽만 있으면 그쪽을, 둘 다 없으면 nil 을 낸다")
    func latestFallsBackToWhicheverExists() {
        let only = snapshot()

        #expect(PingInbox.latest(only, nil)?.generatedAt == only.generatedAt)
        #expect(PingInbox.latest(nil, only)?.generatedAt == only.generatedAt)
        #expect(PingInbox.latest(nil, nil) == nil)
    }

    // MARK: - Test · 에러 매핑

    @Test("도달 불가와 타임아웃은 네트워크 축으로 옮긴다")
    func mapsTransportFailuresToNetworkErrors() {
        let unreachable = PingInbox.appError(from: WatchConnectivityError.notReachable)
        let timedOut = PingInbox.appError(from: WatchConnectivityError.replyTimedOut)
        #expect(unreachable == .network(.noNetwork))
        #expect(timedOut == .network(.timeout))
    }

    @Test("iPhone 로그아웃 응답은 인증 에러로 옮긴다")
    func mapsRemoteNotSignedInToAuthError() {
        let error = WatchConnectivityError.remote(.init(reason: .notSignedIn))

        #expect(PingInbox.appError(from: error) == .auth(.notLoggedIn))
    }

    @Test("스키마 불일치는 손상과 구분해 업데이트 안내를 낸다")
    func schemaMismatchAsksForUpdate() {
        let mismatch = PingInbox.appError(from: WatchConnectivityError.unsupportedSchemaVersion(2))
        let malformed = PingInbox.appError(from: WatchConnectivityError.malformedPayload("깨짐"))

        #expect(mismatch == .domain(.custom(message: "iPhone 앱을 업데이트해 주세요.")))
        #expect(mismatch != malformed)
    }

    @Test("iPhone 서버 호출 실패는 응답 에러로 옮긴다")
    func mapsUpstreamFailureToInvalidResponse() {
        let error = WatchConnectivityError.remote(.init(reason: .upstreamFailed))

        #expect(PingInbox.appError(from: error) == .network(.invalidResponse))
    }

    @Test("통신 계약 밖의 에러는 unknown 으로 떨어지되 문구를 남긴다")
    func mapsUnknownErrorsWithMessage() {
        struct SomeError: Error {}

        guard case .unknown(let message) = PingInbox.appError(from: SomeError()) else {
            Issue.record("unknown 으로 매핑되지 않았다")
            return
        }
        #expect(!message.isEmpty)
    }
}
