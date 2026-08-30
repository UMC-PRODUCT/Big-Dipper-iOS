import Foundation
import Observation
import CoreWatchConnectivity
import UMCFoundation

// MARK: - PingConfirmFailure

/// 확인 전송 실패. 어느 공지의 실패인지 함께 들고 있어야 다른 공지 상세로 넘어갔을 때
/// 남의 에러가 그대로 보이지 않는다.
struct PingConfirmFailure: Equatable, Sendable {

    // MARK: - Property

    let noticeID: String
    let error: AppError
}

// MARK: - PingInbox

/// The Ping 수신함 — 스냅샷 보관 · 낙관적 읽음 오버레이 · 확인 전송을 함께 소유한다.
///
/// **앱 셸이 소유하는 앱 생명주기 전역 관리자**라 화면 하나에 매이지 않는다(`WatchRouter` 와
/// 같은 자리). 목록과 상세가 같은 읽음 상태를 봐야 하는데, 확인 버튼은 상세에서 눌리고 결과는
/// 목록이 즉시 반영해야 하기 때문이다. 화면 로컬 상태로는 이 왕복이 성립하지 않는다.
///
/// `WCSessionDelegate` 콜백을 받는 ``WatchSessionCoordinator`` 가 `@MainActor` 라 이 타입도
/// 같은 격리에 둔다 — 경계를 하나 더 만들면 매 접근이 `await` 가 된다.
@MainActor
@Observable
final class PingInbox {

    // MARK: - Property

    @ObservationIgnored
    private let coordinator: WatchSessionCoordinator

    /// ``refresh()`` 가 왕복으로 직접 받아 온 스냅샷.
    ///
    /// `WatchSessionCoordinator.receivedState` 는 `applicationContext` 경로에서만 갱신되고
    /// `requestSync()` 결과는 반영하지 않는다. 그래서 수동 새로고침분은 여기 따로 담고,
    /// 화면에는 두 출처 중 **더 새로운 쪽**을 보여 준다.
    private var syncedSnapshot: WatchSessionState?

    /// 확인 버튼을 눌러 전송 큐에 올린 공지. iPhone 이 새 스냅샷을 밀어 줄 때까지 유효한
    /// 낙관적 오버레이다. 큐가 실제로 전달됐는지는 시스템이 보장하므로 되돌리지 않는다.
    private var readReceiptIDs: Set<String> = []

    /// 마지막 새로고침 실패. 캐시가 있으면 화면을 덮지 않고 캡션으로만 알린다.
    private(set) var syncFailure: AppError?

    private(set) var confirmFailure: PingConfirmFailure?

    /// iPhone 즉시 통신 가능 여부. 확인 전송 자체는 큐 채널이라 이 값과 무관하게 성공한다.
    var isReachable: Bool { coordinator.isReachable }

    /// 화면에 그릴 스냅샷 — 컨텍스트 수신분과 수동 동기화분 중 최신.
    var snapshot: WatchSessionState? {
        Self.latest(coordinator.receivedState, syncedSnapshot)
    }

    /// 목록 상태.
    ///
    /// 스냅샷이 하나라도 있으면 실패보다 캐시를 우선한다 — 워치는 iPhone 이 멀어지면 늘
    /// 도달 불가가 되는데, 그때마다 목록을 에러 화면으로 바꾸면 마지막 공지를 읽을 수 없다.
    var state: Loadable<[WatchPingItem]> {
        guard let snapshot else {
            return syncFailure.map(Loadable.failed) ?? .loading
        }
        guard snapshot.isSignedIn else {
            return .failed(.auth(.notLoggedIn))
        }
        return .loaded(
            WatchPingItem.list(from: snapshot.notices, readReceiptIDs: readReceiptIDs)
        )
    }

    /// 캐시를 보여 주는 중이고 최신화에 실패했다. 목록 상단 캡션의 근거다.
    var isShowingStaleSnapshot: Bool { snapshot != nil && syncFailure != nil }

    // MARK: - Init

    /// 코디네이터는 앱 셸이 소유한 **앱 수명 하나짜리** 인스턴스를 주입받는다.
    /// 여기서 새로 만들면 `WCSession.default.delegate` 를 가로채 셸 쪽 코디네이터가
    /// 콜백을 잃는다 — 활성화·수신 상태가 조용히 죽는다.
    init(coordinator: WatchSessionCoordinator) {
        self.coordinator = coordinator
    }

    // MARK: - Function

    /// 최신 스냅샷을 요청한다. 실패해도 이미 가진 스냅샷은 버리지 않는다.
    func refresh() async {
        do {
            syncedSnapshot = try await coordinator.requestSync()
            syncFailure = nil
        } catch {
            syncFailure = Self.appError(from: error)
        }
    }

    /// 읽음 확인을 iPhone 으로 보낸다.
    ///
    /// `transferUserInfo` 큐 채널을 쓰므로 **연결이 끊겨 있어도 성공**하고, 앱이 종료돼도
    /// 시스템이 전송을 이어 간다. 계약상 `.noticeRead` 는 이 채널만 허용한다.
    /// 던지지 않고 상태로 남기는 이유: 뷰가 확인 실패 하나 때문에 자체 상태를 갖지 않게 한다.
    func confirmRead(noticeID: String, at readAt: Date = .now) {
        do {
            try coordinator.enqueue(
                .noticeRead(WatchNoticeRead(noticeId: noticeID, readAt: readAt))
            )
            readReceiptIDs.insert(noticeID)
            confirmFailure = nil
        } catch {
            confirmFailure = PingConfirmFailure(
                noticeID: noticeID,
                error: Self.appError(from: error)
            )
        }
    }

    /// 목록에서 공지 하나를 꺼낸다. 상세 화면은 라우트로 식별자만 받는다.
    func item(id noticeID: String) -> WatchPingItem? {
        state.value?.first { $0.id == noticeID }
    }

    /// 두 출처 중 더 새로운 스냅샷. `generatedAt` 동률이면 델리게이트가 밀어 준 쪽을 택한다 —
    /// 그쪽이 iPhone 이 마지막으로 퍼블리시한 값이다.
    static func latest(
        _ context: WatchSessionState?,
        _ synced: WatchSessionState?
    ) -> WatchSessionState? {
        switch (context, synced) {
        case (let context?, let synced?):
            return context.generatedAt >= synced.generatedAt ? context : synced
        case (let context?, nil):
            return context
        case (nil, let synced?):
            return synced
        case (nil, nil):
            return nil
        }
    }

    /// 통신 실패를 화면이 말할 수 있는 문구로 옮긴다.
    ///
    /// 분류가 무너지면 「업데이트가 필요하다」와 「잠깐 멀어졌다」가 같은 문장이 되어,
    /// 사용자가 할 수 있는 행동이 사라진다.
    static func appError(from error: Error) -> AppError {
        guard let error = error as? WatchConnectivityError else {
            return .unknown(message: error.localizedDescription)
        }

        switch error {
        case .notSupported:
            return .domain(.custom(message: "이 기기에서는 iPhone 연동을 쓸 수 없습니다."))
        case .sessionNotActivated:
            return .domain(.custom(message: "iPhone 연결을 준비하는 중입니다."))
        case .notReachable:
            return .network(.noNetwork)
        case .replyTimedOut:
            return .network(.timeout)
        case .payloadTooLarge:
            return .domain(.custom(message: "공지가 많아 일부만 받았습니다. iPhone 에서 확인해 주세요."))
        case .unsupportedSchemaVersion:
            return .domain(.custom(message: "iPhone 앱을 업데이트해 주세요."))
        case .remote(let failure):
            return appError(from: failure)
        case .malformedPayload, .unexpectedReply, .unsupportedChannel:
            return .unknown(message: "공지를 읽지 못했습니다.")
        case .transportFailure(let underlying):
            return .unknown(message: underlying.localizedDescription)
        }
    }

    /// iPhone 이 「처리하지 못했다」고 응답한 경우. 워치 쪽 통신 실패와 원인이 다르다.
    private static func appError(from failure: WatchRemoteFailure) -> AppError {
        switch failure.reason {
        case .notSignedIn:
            return .auth(.notLoggedIn)
        case .upstreamFailed:
            return .network(.invalidResponse)
        case .malformedPayload, .unsupportedSchemaVersion, .unsupportedRequest:
            return .domain(.custom(message: "iPhone 앱을 업데이트해 주세요."))
        }
    }
}

#if DEBUG
extension PingInbox {

    /// 프리뷰·테스트 전용 시딩.
    ///
    /// `WatchSessionCoordinator.receivedState` 는 `WCSessionDelegate` 콜백으로만 채워져
    /// 시뮬레이터 프리뷰와 유닛 테스트에서는 영원히 `nil` 이다. 수동 동기화분 자리에 값을
    /// 밀어 넣어 같은 계산 경로(``state``)를 그대로 통과시킨다.
    static func preview(
        snapshot: WatchSessionState?,
        syncFailure: AppError? = nil,
        readReceiptIDs: Set<String> = []
    ) -> PingInbox {
        let inbox = PingInbox(coordinator: WatchSessionCoordinator())
        inbox.syncedSnapshot = snapshot
        inbox.syncFailure = syncFailure
        inbox.readReceiptIDs = readReceiptIDs
        return inbox
    }
}

extension WatchSessionState {

    static let pingSample = WatchSessionState(
        isSignedIn: true,
        schedules: [],
        notices: WatchPingItem.samples.map(\.notice),
        generatedAt: .now.addingTimeInterval(-5 * 60)
    )

    static let pingEmpty = WatchSessionState(
        isSignedIn: true,
        schedules: [],
        notices: [],
        generatedAt: .now
    )

    static let pingSignedOut = WatchSessionState(
        isSignedIn: false,
        schedules: [],
        notices: [],
        generatedAt: .now
    )
}
#endif
