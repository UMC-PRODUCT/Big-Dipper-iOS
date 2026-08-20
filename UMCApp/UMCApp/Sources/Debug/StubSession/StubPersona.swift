//
//  StubPersona.swift
//  UMCApp
//
//  Created by One on 8/18/26.
//

#if DEBUG
import Foundation

/// stub 세션이 어느 사람 행세를 할지 고르는 스위치.
///
/// **왜 필요한가**: 명함 기능 중 몇 가지는 두 기기가 *서로 다른 사람*이어야만 확인된다 —
/// 받은 명함의 내용 충실도, 같은 상대와 재교환했을 때의 upsert, 자기 명함 필터.
/// 카카오 로그인이 bundle id 미등록으로 막혀 있어 실계정 두 개를 만들 수 없고,
/// stub 신원이 하나뿐이라 두 기기가 항상 같은 사람이 됐다. 그래서 신원을 인자로 가른다.
///
/// ```bash
/// xcrun devicectl device process launch --device <A> dev.umc.product.debug
/// xcrun devicectl device process launch --device <B> dev.umc.product.debug -stubPersona b
/// ```
///
/// 실행 인자는 한 번 주면 `UserDefaults` 에 남는다 — 홈 화면에서 앱을 다시 켜도 유지된다
/// (``StubSessionMode`` 의 실서버 토글과 같은 방식).
enum StubPersona: String, CaseIterable {

    /// 기본 신원. 지금까지의 stub 픽스처와 같다 — 기존 검증 기록과 값이 어긋나지 않게 유지한다.
    case a
    /// 두 번째 신원. 학교·파트·기수·외부 링크가 전부 달라서, 받은 명함이 자기 것인지
    /// 상대 것인지 **눈으로** 갈린다.
    case b
    /// 파트 문자열이 **우리가 모르는 값**(`RUST`)인 신원.
    ///
    /// 서버가 파트를 추가했는데 앱이 아직 모르는 상황을 만든다. 이 신원으로 교환하면
    /// 상대 명함첩에 「운영진」이 아니라 「RUST」로 남아야 한다.
    case c

    // MARK: - Constants

    private static let storageKey = "debug.stubSession.persona"
    private static let launchArgument = "-stubPersona"

    // MARK: - Static Property

    /// 이번 실행의 신원. 실행 인자가 최우선이고, 주어졌으면 다음 실행을 위해 저장한다.
    ///
    /// `static let` 이라 **한 번만** 확정된다. 계산 프로퍼티로 두면 프로필을 읽을 때마다
    /// `UserDefaults` 에 쓰게 된다.
    static let current: StubPersona = resolve()

    // MARK: - Static Function

    private static func resolve() -> StubPersona {
        if let fromArgument = parseLaunchArgument() {
            UserDefaults.standard.set(fromArgument.rawValue, forKey: storageKey)
            return fromArgument
        }
        let stored = UserDefaults.standard.string(forKey: storageKey) ?? ""
        return StubPersona(rawValue: stored) ?? .a
    }

    private static func parseLaunchArgument() -> StubPersona? {
        let arguments = CommandLine.arguments
        guard let flagIndex = arguments.firstIndex(of: launchArgument),
              arguments.index(after: flagIndex) < arguments.endIndex else { return nil }
        return StubPersona(rawValue: arguments[arguments.index(after: flagIndex)].lowercased())
    }
}
#endif
