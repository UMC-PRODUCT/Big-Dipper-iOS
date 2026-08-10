//
//  AuthRouter.swift
//  AuthData
//
//  Created by euijjang97 on 7/8/26.
//

import CoreNetwork
import Foundation
import Moya

/// Auth 관련 API 엔드포인트 정의.
///
/// - Note: 토큰 강제 갱신(`token-renew`)은 `NetworkClient.forceRefreshToken()`이 내부적으로
///   `TokenRefreshServiceImpl`(단일 비행 보장, Keychain 저장까지 원자적 처리)을 통해 이미
///   전체 흐름을 안전하게 구현하고 있다. 이 Router에 별도 `renewToken` 케이스를 추가해 동일 갱신을
///   중복 호출하면 두 경로가 동시에 리프레시 토큰을 회전시켜 경쟁 조건이 생길 수 있으므로,
///   세션 갱신은 기존 Core 인프라를 그대로 재사용한다.
public enum AuthRouter: BaseTargetType {

    // MARK: - Cases

    /// 카카오 소셜 로그인
    case loginKakao(body: LoginKakaoRequestDTO)
    /// Apple 소셜 로그인
    case loginApple(body: LoginAppleRequestDTO)
    /// Google 소셜 로그인
    case loginGoogle(body: LoginGoogleRequestDTO)
    /// 이메일(ID/PW) 로그인
    case loginByEmail(body: EmailLoginRequestDTO)
    /// 이메일 인증 코드 발송
    case sendEmailVerification(body: SendEmailVerificationRequestDTO)
    /// 이메일 인증 코드 재전송
    case resendEmailVerification(body: ResendEmailVerificationRequestDTO)
    /// 이메일 인증 코드 검증
    case verifyEmailCode(body: VerifyEmailCodeRequestDTO)
    /// 이메일 중복 확인
    case checkEmailAvailability(query: CheckEmailAvailabilityQuery)
    /// 학교 목록 조회
    case fetchSchools
    /// 약관 조회
    case fetchTerms(termsType: String)
    /// 소셜 회원가입
    case register(body: RegisterRequestDTO)
    /// 이메일(ID/PW) 회원가입
    case registerByEmail(body: EmailRegisterRequestDTO)
    /// OAuth 회원 비밀번호 추가 등록
    case registerCredential(body: RegisterCredentialRequestDTO)
    /// 기존 챌린저 코드 등록
    case registerExistingChallenger(body: RegisterExistingChallengerRequestDTO)
    /// 비밀번호 재설정
    case resetPassword(body: ResetPasswordRequestDTO)
    /// 로그인 상태에서의 비밀번호 변경
    case changePassword(body: ChangePasswordRequestDTO)
    /// 내 OAuth 연동 정보 조회
    case fetchMyOAuth
    /// 로그인 OAuth 수단 추가 연동
    case addMemberOAuth(body: AddMemberOAuthRequestDTO)
    /// 로그인 OAuth 수단 연동 해제
    case deleteMemberOAuth(memberOAuthId: String, body: DeleteMemberOAuthRequestDTO)

    // MARK: - Path

    public var path: String {
        switch self {
        case .loginKakao:
            return "/api/v1/auth/login/kakao"
        case .loginApple:
            return "/api/v1/auth/login/apple"
        case .loginGoogle:
            return "/api/v1/auth/login/google"
        case .loginByEmail:
            return "/api/v1/auth/login/email"
        case .sendEmailVerification:
            return "/api/v1/auth/email-verification"
        case .resendEmailVerification:
            return "/api/v1/auth/email-verification/resend"
        case .verifyEmailCode:
            return "/api/v1/auth/email-verification/code"
        case .checkEmailAvailability:
            return "/api/v1/auth/email/availability"
        case .fetchSchools:
            return "/api/v1/schools/all"
        case .fetchTerms(let termsType):
            return "/api/v1/terms/type/\(termsType)"
        case .register:
            return "/api/v1/member/register"
        case .registerByEmail:
            return "/api/v1/member/register/email"
        case .registerCredential:
            return "/api/v1/auth/credentials"
        case .registerExistingChallenger:
            return "/api/v1/challenger-record/member"
        case .resetPassword:
            return "/api/v1/auth/password/reset"
        case .changePassword:
            return "/api/v1/auth/password"
        case .fetchMyOAuth:
            return "/api/v1/member-oauth/me"
        case .addMemberOAuth:
            return "/api/v1/member-oauth"
        case .deleteMemberOAuth(let memberOAuthId, _):
            return "/api/v1/member-oauth/\(memberOAuthId)"
        }
    }

    // MARK: - Method

    public var method: Moya.Method {
        switch self {
        case .checkEmailAvailability, .fetchSchools, .fetchTerms, .fetchMyOAuth:
            return .get
        case .loginKakao, .loginApple, .loginGoogle, .loginByEmail,
             .sendEmailVerification, .resendEmailVerification, .verifyEmailCode,
             .register, .registerByEmail, .registerCredential, .registerExistingChallenger,
             .addMemberOAuth:
            return .post
        case .resetPassword, .changePassword:
            return .patch
        case .deleteMemberOAuth:
            return .delete
        }
    }

    // MARK: - Task

    public var task: Moya.Task {
        switch self {
        case .fetchSchools:
            return .requestPlain
        case .loginKakao(let body):
            return .requestJSONEncodable(body)
        case .loginApple(let body):
            return .requestJSONEncodable(body)
        case .loginGoogle(let body):
            return .requestJSONEncodable(body)
        case .loginByEmail(let body):
            return .requestJSONEncodable(body)
        case .sendEmailVerification(let body):
            return .requestJSONEncodable(body)
        case .resendEmailVerification(let body):
            return .requestJSONEncodable(body)
        case .verifyEmailCode(let body):
            return .requestJSONEncodable(body)
        case .checkEmailAvailability(let query):
            return .requestParameters(
                parameters: query.toParameters,
                encoding: URLEncoding.queryString
            )
        case .fetchTerms:
            return .requestPlain
        case .register(let body):
            return .requestJSONEncodable(body)
        case .registerByEmail(let body):
            return .requestJSONEncodable(body)
        case .registerCredential(let body):
            return .requestJSONEncodable(body)
        case .registerExistingChallenger(let body):
            return .requestJSONEncodable(body)
        case .resetPassword(let body):
            return .requestJSONEncodable(body)
        case .changePassword(let body):
            return .requestJSONEncodable(body)
        case .fetchMyOAuth:
            return .requestPlain
        case .addMemberOAuth(let body):
            return .requestJSONEncodable(body)
        case .deleteMemberOAuth(_, let body):
            return .requestJSONEncodable(body)
        }
    }
}
