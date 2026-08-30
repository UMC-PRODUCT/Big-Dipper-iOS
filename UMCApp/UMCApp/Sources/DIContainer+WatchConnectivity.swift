//
//  DIContainer+WatchConnectivity.swift
//  UMCApp
//
//  Created by euijjang97 on 8/30/26.
//

import CoreDI
import CoreNetwork
import CoreWatchConnectivity
import Foundation

// WatchConnectivity(워치 연동) 의존성 등록 + WCSession 활성화.
//
// 코디네이터 하나가 세션의 전부다 — Repository/UseCase 계층이 없는 이유는 아직 나를 수 있는
// 것이 세션 스냅샷 하나뿐이라, 구현체가 하나뿐인 프로토콜만 늘어나기 때문이다.
extension DIContainer {

    /// ``WatchSessionCoordinator`` 를 앱 수명 싱글톤으로 등록한다.
    ///
    /// 인스턴스를 팩토리 **밖에서** 미리 만드는 이유가 둘이다.
    /// - `WatchSessionCoordinator` 는 `@MainActor` 라 nonisolated 인 팩토리 클로저 안에서
    ///   생성할 수 없다. MainActor 인 이 메서드에서 만들어 캡처만 한다
    ///   (`@MainActor` 클래스는 암묵적 `Sendable` 이라 캡처가 안전하다).
    /// - 로그아웃의 `resetCache()` 뒤에도 **같은 인스턴스**가 돌아온다. 새로 만들면
    ///   `WCSession.default.delegate` 는 옛 인스턴스를 가리킨 채라, 새 인스턴스의
    ///   `isActivated`/`isReachable` 이 영원히 `false` 로 굳는다.
    @MainActor
    func registerWatchConnectivityDependencies() {
        let coordinator = WatchSessionCoordinator()
        register(WatchSessionCoordinator.self) { coordinator }
    }

    /// 요청 처리기를 붙이고 WCSession 을 활성화한다. 앱 시작 시 한 번만 호출한다.
    ///
    /// 핸들러가 `@Sendable` 이라 non-Sendable 인 `DIContainer` 를 캡처할 수 없다. `Sendable` 인
    /// ``TokenStore`` 만 미리 꺼내 캡처한다. 캡처해도 낡지 않는 이유는 `TokenStore` 가 앱 수명
    /// 단일 인스턴스이기 때문이다 — 로그아웃의 `resetCache()` 뒤에도 같은 인스턴스가 돌아와
    /// 재로그인으로 저장한 토큰이 이 핸들러에도 그대로 보인다
    /// (``DIContainer/configured(modelContext:)``).
    ///
    /// 등록은 `activate()` **전에** 해야 한다 — 시스템이 앱을 백그라운드로 깨워 배달한 요청이
    /// 「핸들러 미등록」(`.unsupportedRequest`)으로 거절되지 않는다.
    @MainActor
    func activateWatchSession() {
        let coordinator = resolve(WatchSessionCoordinator.self)
        let tokenStore = resolve(TokenStore.self)
        coordinator.setRequestHandler { message in
            await WatchRequestResponder.reply(to: message, tokenStore: tokenStore)
        }
        coordinator.activate()
    }
}

// MARK: - WatchRequestResponder

/// 워치가 `sendMessage` 로 보낸 왕복 요청에 iPhone 이 답하는 규칙.
///
/// 코디네이터에서 분리한 이유는 이 판단이 앱 계층(로그인 여부·도메인)에 속하기 때문이다.
/// 값만 받아 값만 돌려주므로 WCSession 없이 그대로 테스트할 수 있다.
enum WatchRequestResponder {

    // MARK: - Function

    static func reply(to message: WatchMessage, tokenStore: TokenStore) async -> WatchReply {
        switch message {
        case .syncRequest:
            return await syncReply(tokenStore: tokenStore)

        case .attendanceRequest:
            // GPS 출석 위임은 서버 왕복 + 위치 검증이 필요해 별도 이슈다. 조용히 `.ack` 를
            // 돌려주면 워치는 출석이 접수된 줄 알고 결석을 확정당한다.
            return .failure(.init(reason: .unsupportedRequest, message: "출석 위임 미구현"))

        case .noticeRead, .sessionState, .attendanceChanged:
            // `.noticeRead` 는 `transferUserInfo` 단방향 채널로만 오고(수신은
            // `receivedUserInfo()` 스트림 담당), 뒤 둘은 iPhone → Watch 방향이라 이 핸들러로
            // 올 수 없다. 도착했다면 상대 구현이 채널을 잘못 골랐다는 뜻이다.
            return .failure(.init(reason: .unsupportedRequest))
        }
    }

    // MARK: - Private

    /// 스냅샷을 채우는 생산자(Home/Notice 도메인에서 실제 일정·공지를 모으는 로직)는 별도
    /// 이슈다. 여기서 빈 목록을 **정직하게** 돌려주는 이유는 이번 범위가 왕복이 성립하는지의
    /// 배선 검증이고, 워치는 `isSignedIn` 만으로도 로그인 안내와 빈 상태를 갈라 그릴 수 있기
    /// 때문이다.
    private static func syncReply(tokenStore: TokenStore) async -> WatchReply {
        guard await tokenStore.getAccessToken() != nil else {
            return .failure(.init(reason: .notSignedIn))
        }
        return .state(
            WatchSessionState(
                isSignedIn: true,
                schedules: [],
                notices: [],
                generatedAt: Date()
            )
        )
    }
}
