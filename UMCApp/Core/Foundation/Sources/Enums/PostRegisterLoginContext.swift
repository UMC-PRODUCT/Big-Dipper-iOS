/// 회원가입 직후 세션 복구에 필요한 소셜 로그인 재인증 자격 정보.
///
/// 소셜 신규가입 시 서버가 토큰을 내려주지 않으면(`RegisterResult.sessionEstablished == false`),
/// 가입 직전 사용했던 소셜 자격으로 재로그인해 세션을 확립해야 한다. `AppFlow.showSignUp`이
/// Feature(AuthPresentation)를 import할 수 없는 Core 계층에서 이 컨텍스트를 요구하므로
/// `SocialType`과 동일하게 `Core/Foundation`에 배치한다(선례 참고).
public enum PostRegisterLoginContext: Equatable, Sendable {
    case kakao(accessToken: String, email: String)
    case apple(authorizationCode: String, email: String?, fullName: String?)
    case google(accessToken: String)
}
