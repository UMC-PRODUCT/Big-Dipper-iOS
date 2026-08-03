//
//  StubSessionMode.swift
//  UMCApp
//
//  Created by jaewon Lee on 8/3/26.
//

#if DEBUG
/// 카카오 로그인 서버 미등록 기간 한정 stub 세션 토글 (단일 진실 원천).
///
/// 서버 팀이 카카오 개발자 콘솔에 iOS bundle id를 등록할 때까지 소셜 로그인이 불가능하므로,
/// 이 플래그가 `true`이면 앱 시작 시 인증·홈 데이터 Repository를 stub 구현체로 교체해
/// 로그인 없이 홈 화면에 진입한다 (`DIContainer+StubSession.swift`).
///
/// - Important: stub 모드 on/off는 **이 파일의 `isEnabled` 한 곳**에서만 제어한다.
///   서버가 bundle id를 등록하면 `false`로 바꾸는 것만으로 실서버 경로로 복귀한다.
///   릴리스 빌드에는 이 파일과 stub 구현 전체가 컴파일되지 않는다 (`#if DEBUG`).
enum StubSessionMode {
    static let isEnabled = true
}
#endif
