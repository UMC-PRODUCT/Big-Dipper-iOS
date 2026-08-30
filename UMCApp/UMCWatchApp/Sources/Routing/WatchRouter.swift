import Observation

// MARK: - WatchRouter

/// 워치 앱의 단일 네비게이션 스택 소유자.
///
/// 앱 셸(`UMCWatchApp`)이 소유하고 `.environment` 로 주입하는 **앱 생명주기 전역 관리자**라
/// 절대 규칙 #1 의 예외에 해당한다 — 그래서 `@Observable` 을 쓴다.
///
/// 경로를 타입 소거된 `NavigationPath` 가 아니라 `[WatchRoute]` 로 두는 이유: 워치는 단일
/// 타겟·단일 스택이라 iOS `PathStore` 의 역방향 의존 회피 논거가 없고, 구체 배열이어야
/// 스택 내용을 테스트로 검증할 수 있다.
@Observable
final class WatchRouter {

    // MARK: - Property

    var path: [WatchRoute] = []

    // MARK: - Function

    func push(_ route: WatchRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }
}
