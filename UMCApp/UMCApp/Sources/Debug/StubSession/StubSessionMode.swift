//
//  StubSessionMode.swift
//  UMCApp
//
//  Created by jaewon Lee on 8/3/26.
//

#if DEBUG
import Foundation

/// 카카오 로그인 서버 미등록 기간 한정 stub 세션 토글 (단일 진실 원천).
///
/// 서버 팀이 카카오 개발자 콘솔에 iOS bundle id를 등록할 때까지 소셜 로그인이 불가능하므로,
/// 기본값이 `true`이면 앱 시작 시 인증·홈 데이터 Repository를 stub 구현체로 교체해
/// 로그인 없이 홈 화면에 진입한다 (`DIContainer+StubSession.swift`).
///
/// - Important: 릴리스 빌드에는 이 파일과 stub 구현 전체가 컴파일되지 않는다 (`#if DEBUG`).
///
/// ## 실서버로 전환하기
///
/// 명함 QR 딥링크처럼 **실제 서버 응답을 봐야 하는 검증**은 stub 세션에서 할 수 없다.
/// 세 가지 경로로 끌 수 있고, 위에서부터 우선한다.
///
/// 1. 실행 인자 `-realSession` (Xcode 스킴)
/// 2. 검증 화면의 토글 — `UserDefaults`에 남으므로 **기기 단독 실행에도 적용**된다.
///    앱을 다시 켜야 반영된다 (DI 등록이 시작 시 한 번만 돌기 때문).
/// 3. 아무것도 안 하면 기본값(stub 사용)
enum StubSessionMode {

    /// 검증 화면 토글이 쓰는 저장 키.
    private static let realSessionKey = "debug.stubSession.forceRealSession"

    /// stub Repository로 교체할지 여부. `UMCAppApp`이 시작 시 한 번만 읽는다.
    static var isEnabled: Bool { !isRealSessionForced }

    /// 실서버 세션이 강제됐는지. 실행 인자가 최우선이다.
    static var isRealSessionForced: Bool {
        if CommandLine.arguments.contains("-realSession") { return true }
        return UserDefaults.standard.bool(forKey: realSessionKey)
    }

    /// 검증 화면에서 전환한다. 다음 실행부터 적용된다.
    static func setRealSessionForced(_ isForced: Bool) {
        UserDefaults.standard.set(isForced, forKey: realSessionKey)
    }
}
#endif
