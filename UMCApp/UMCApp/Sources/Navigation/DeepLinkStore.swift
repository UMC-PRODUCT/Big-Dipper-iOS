//
//  DeepLinkStore.swift
//  UMCApp
//

import Foundation
import Observation

/// 아직 열지 못한 딥링크 한 개.
///
/// `onOpenURL` 은 앱이 부트스트랩·로그인 화면에 있을 때도 들어온다. 그 시점에는 탭 셸이
/// 아예 없어 밀어 넣을 `NavigationStack` 도 없으므로, 링크를 여기 세워 두고 탭 셸이 뜨는
/// 순간 꺼내 간다. 공유 링크를 받은 사람이 로그인부터 해야 하는 경우가 정확히 이 경로다.
///
/// - Note: 절대 규칙 #1(`@Observable` 전용)의 앱 생명주기 전역 관리자에 해당한다.
///   한 칸짜리 우편함이라 링크가 연달아 오면 마지막 것만 남는다 — 딥링크는 사용자가 한 번에
///   하나씩 여는 동작이라 큐를 둘 이유가 없다.
@Observable
final class DeepLinkStore {

    // MARK: - Property

    var pending: AppDeepLink?

    // MARK: - Function

    /// 링크를 세워 둔다. 내부 링크가 아니면 아무 일도 하지 않는다.
    ///
    /// - Returns: 내부 링크로 인식해 받아 뒀는지 여부. `false` 면 다른 핸들러(소셜 로그인)가
    ///   처리할 URL 이다.
    @discardableResult
    func receive(_ url: URL) -> Bool {
        guard let link = AppDeepLink.parse(url) else { return false }
        pending = link
        return true
    }

    /// 세워 둔 링크를 꺼내 비운다.
    func take() -> AppDeepLink? {
        defer { pending = nil }
        return pending
    }
}
