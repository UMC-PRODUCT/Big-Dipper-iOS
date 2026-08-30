//
//  WatchRequestResponderTests.swift
//  UMCAppTests
//
//  Created by euijjang97 on 8/30/26.
//

import CoreNetwork
import CoreWatchConnectivity
import Foundation
import Testing

@testable import UMCApp

// MARK: - Helpers

/// 액세스 토큰 유무만 주입하는 최소 스텁. 응답기가 읽는 것이 그 하나뿐이다.
private struct StubTokenStore: TokenStore {
    let accessToken: String?

    func getAccessToken() async -> String? { accessToken }
    func getRefreshToken() async -> String? { nil }
    func save(accessToken: String, refreshToken: String) async throws {}
    func clear() async throws {}
}

private let attendanceRequest = WatchAttendanceRequest(
    scheduleId: "1",
    latitude: 37.5,
    longitude: 127.0,
    locationVerified: true,
    measuredAt: Date()
)

// MARK: - Tests

@Suite("WatchRequestResponder — 워치 왕복 요청 응답 규칙")
struct WatchRequestResponderTests {

    @Test("로그아웃 상태의 syncRequest 는 notSignedIn 으로 거절한다")
    func rejectsSyncRequestWhenSignedOut() async throws {
        let reply = await WatchRequestResponder.reply(
            to: .syncRequest,
            tokenStore: StubTokenStore(accessToken: nil)
        )

        guard case .failure(let failure) = reply else {
            Issue.record("기대: .failure, 실제: \(reply)")
            return
        }
        #expect(failure.reason == .notSignedIn)
    }

    @Test("로그인 상태의 syncRequest 는 빈 스냅샷을 돌려준다")
    func returnsEmptySnapshotWhenSignedIn() async throws {
        let reply = await WatchRequestResponder.reply(
            to: .syncRequest,
            tokenStore: StubTokenStore(accessToken: "access-token")
        )

        guard case .state(let state) = reply else {
            Issue.record("기대: .state, 실제: \(reply)")
            return
        }
        #expect(state.isSignedIn)
        // 스냅샷 생산자는 별도 이슈다. 목록이 채워지기 시작하면 이 기대치를 갱신한다.
        #expect(state.schedules.isEmpty)
        #expect(state.notices.isEmpty)
    }

    @Test("출석 위임 요청은 unsupportedRequest 로 거절한다")
    func rejectsAttendanceRequest() async throws {
        let reply = await WatchRequestResponder.reply(
            to: .attendanceRequest(attendanceRequest),
            tokenStore: StubTokenStore(accessToken: "access-token")
        )

        guard case .failure(let failure) = reply else {
            Issue.record("기대: .failure, 실제: \(reply)")
            return
        }
        #expect(failure.reason == .unsupportedRequest)
    }
}
