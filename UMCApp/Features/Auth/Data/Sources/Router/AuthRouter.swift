import CoreNetwork
import Foundation
import Moya

/// Auth 관련 API 엔드포인트 정의.
///
/// - Note: 토큰 강제 갱신(`token-renew`)은 `NetworkClient.forceRefreshToken()`이 내부적으로
///   `TokenRefreshServiceImpl`(단일 비행 보장, Keychain 저장까지 원자적 처리)을 통해 이미
///   전체 흐름을 안전하게 구현하고 있다. 이 Router에 별도 `renewToken` 케이스를 추가해 동일 갱신을
///   중복 호출하면 두 경로가 동시에 리프레시 토큰을 회전시켜 경쟁 조건이 생길 수 있으므로,
///   이번 슬라이스에서는 `me` 케이스만 정의하고 세션 갱신은 기존 Core 인프라를 그대로 재사용한다.
public enum AuthRouter: BaseTargetType {

    // MARK: - Cases

    /// 내 프로필 조회
    case getMe
    /// 카카오 소셜 로그인
    case loginKakao(body: LoginKakaoRequestDTO)
    /// Apple 소셜 로그인
    case loginApple(body: LoginAppleRequestDTO)
    /// Google 소셜 로그인
    case loginGoogle(body: LoginGoogleRequestDTO)

    // MARK: - Path

    public var path: String {
        switch self {
        case .getMe:
            return "/api/v1/member/me"
        case .loginKakao:
            return "/api/v1/auth/login/kakao"
        case .loginApple:
            return "/api/v1/auth/login/apple"
        case .loginGoogle:
            return "/api/v1/auth/login/google"
        }
    }

    // MARK: - Method

    public var method: Moya.Method {
        switch self {
        case .getMe:
            return .get
        case .loginKakao, .loginApple, .loginGoogle:
            return .post
        }
    }

    // MARK: - Task

    public var task: Moya.Task {
        switch self {
        case .getMe:
            return .requestPlain
        case .loginKakao(let body):
            return .requestJSONEncodable(body)
        case .loginApple(let body):
            return .requestJSONEncodable(body)
        case .loginGoogle(let body):
            return .requestJSONEncodable(body)
        }
    }
}
