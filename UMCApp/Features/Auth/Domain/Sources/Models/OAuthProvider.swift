//
//  OAuthProvider.swift
//  AuthDomain
//
//  Created by euijjang97 on 8/10/26.
//

import UMCFoundation

/// 서버가 내려주는 OAuth provider 타입.
///
/// 스웨거 enum 기준(APPLE, KAKAO, GOOGLE)으로 모델링하며, 지원하지 않는 값은 `.unknown`으로
/// 흡수해 화면에서 무시한다(서버가 provider를 추가해도 디코딩이 실패하지 않도록).
public enum OAuthProvider: Equatable, Sendable {
    /// Apple 로그인
    case apple
    /// Kakao 로그인
    case kakao
    /// Google 로그인
    case google
    /// 서버에서 내려온 알 수 없는 provider (하위 호환용)
    case unknown(String)

    /// 서버 raw 문자열("APPLE", "KAKAO", "GOOGLE")을 case로 변환한다.
    public init(raw: String) {
        switch raw.uppercased() {
        case "APPLE":
            self = .apple
        case "KAKAO":
            self = .kakao
        case "GOOGLE":
            self = .google
        default:
            self = .unknown(raw)
        }
    }

    /// 서버 전송/저장용 raw 문자열.
    public var raw: String {
        switch self {
        case .apple:
            return "APPLE"
        case .kakao:
            return "KAKAO"
        case .google:
            return "GOOGLE"
        case .unknown(let raw):
            return raw
        }
    }

    /// 앱 내부에서 사용하는 `SocialType`으로 변환한다. (`.unknown`은 nil)
    public var socialType: SocialType? {
        switch self {
        case .apple:
            return .apple
        case .kakao:
            return .kakao
        case .google:
            return .google
        case .unknown:
            return nil
        }
    }
}
