//
//  AuthAPI.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/9/26.
//

import Foundation
import Moya
internal import Alamofire

/// Auth 관련 API 엔드포인트 정의
enum AuthRouter: BaseTargetType {

    // MARK: - Cases

    /// 카카오 소셜 로그인
    case loginKakao(body: LoginKakaoRequestDTO)
    /// Apple 소셜 로그인
    case loginApple(body: LoginAppleRequestDTO)
    /// Google 소셜 로그인
    case loginGoogle(body: LoginGoogleRequestDTO)
    /// 이메일 로그인 (App Store 리뷰어용)
    case loginByEmail(body: EmailLoginRequestDTO)
    /// 이메일 회원가입 (App Store 리뷰어용)
    case registerByEmail(body: EmailRegisterRequestDTO)
    /// 이메일 중복 검사
    case checkEmailAvailability(query: CheckEmailAvailabilityQuery)
    /// 액세스 토큰 재발급
    case renewToken(body: RenewTokenRequestDTO)
    /// 내 OAuth 연동 정보 조회
    case getMyOAuth
    /// 로그인 OAuth 수단 추가 연동
    case addMemberOAuth(oAuthVerificationToken: String)
    /// 로그인 OAuth 수단 연동 해제
    case deleteMemberOAuth(
        memberOAuthId: Int,
        googleAccessToken: String?,
        kakaoAccessToken: String?
    )
    /// 이메일 인증 발송
    case sendEmailVerification(body: SendEmailVerificationRequestDTO)
    /// 이메일 인증코드 재전송
    case resendEmailVerification(body: ResendEmailVerificationRequestDTO)
    /// 이메일 인증코드 검증
    case verifyEmailCode(body: VerifyEmailCodeRequestDTO)
    /// 비밀번호 초기화
    case resetPassword(body: ResetPasswordRequestDTO)
    /// 회원가입
    case register(body: RegisterRequestDTO)
    /// 기존 챌린저 코드 인증
    case registerExistingChallenger(code: String)
    /// 학교 목록 조회
    case getSchools
    /// 약관 조회
    case getTerms(termsType: String)
    /// OAuth 회원 비밀번호 추가 등록
    case registerCredential(body: RegisterCredentialRequestDTO)
    /// 비밀번호 변경
    case changePassword(body: ChangePasswordRequestDTO)

    // MARK: - Path

    var path: String {
        switch self {
        case .loginKakao:
            return "/api/v1/auth/login/kakao"
        case .loginApple:
            return "/api/v1/auth/login/apple"
        case .loginGoogle:
            return "/api/v1/auth/login/google"
        case .loginByEmail:
            return "/api/v1/auth/login/email"
        case .registerByEmail:
            return "/api/v1/member/register/email"
        case .checkEmailAvailability:
            return "/api/v1/auth/email/availability"
        case .renewToken:
            return "/api/v1/auth/token/renew"
        case .getMyOAuth:
            return "/api/v1/member-oauth/me"
        case .addMemberOAuth:
            return "/api/v1/member-oauth"
        case .deleteMemberOAuth(let memberOAuthId, _, _):
            return "/api/v1/member-oauth/\(memberOAuthId)"
        case .sendEmailVerification:
            return "/api/v1/auth/email-verification"
        case .resendEmailVerification:
            return "/api/v1/auth/email-verification/resend"
        case .verifyEmailCode:
            return "/api/v1/auth/email-verification/code"
        case .resetPassword:
            return "/api/v1/auth/password/reset"
        case .register:
            return "/api/v1/member/register"
        case .registerExistingChallenger:
            return "/api/v1/challenger-record/member"
        case .getSchools:
            return "/api/v1/schools/all"
        case .getTerms(let termsType):
            return "/api/v1/terms/type/\(termsType)"
        case .registerCredential:
            return "/api/v1/auth/credentials"
        case .changePassword:
            return "/api/v1/auth/password"
        }
    }

    // MARK: - Method

    var method: Moya.Method {
        switch self {
        case .loginKakao, .loginApple, .loginGoogle, .loginByEmail, .registerByEmail,
             .renewToken, .sendEmailVerification, .resendEmailVerification,
             .verifyEmailCode, .register, .registerExistingChallenger:
            return .post
        case .addMemberOAuth:
            return .post
        case .deleteMemberOAuth:
            return .delete
        case .getMyOAuth, .getSchools, .getTerms,
             .checkEmailAvailability:
            return .get
        case .registerCredential:
            return .post
        case .resetPassword, .changePassword:
            return .patch
        }
    }

    // MARK: - Task

    var task: Moya.Task {
        switch self {
        case .loginKakao(let body):
            return .requestJSONEncodable(body)
        case .loginApple(let body):
            return .requestJSONEncodable(body)
        case .loginGoogle(let body):
            return .requestJSONEncodable(body)
        case .loginByEmail(let body):
            return .requestJSONEncodable(body)
        case .registerByEmail(let body):
            return .requestJSONEncodable(body)
        case .checkEmailAvailability(let query):
            return .requestParameters(
                parameters: query.toParameters,
                encoding: URLEncoding.queryString
            )
        case .renewToken(let body):
            return .requestJSONEncodable(body)
        case .getMyOAuth:
            return .requestPlain
        case .addMemberOAuth(let oAuthVerificationToken):
            return .requestJSONEncodable(
                AddMemberOAuthRequestDTO(
                    oAuthVerificationToken: oAuthVerificationToken
                )
            )
        case .deleteMemberOAuth(
            _,
            let googleAccessToken,
            let kakaoAccessToken
        ):
            return .requestJSONEncodable(
                DeleteMemberOAuthRequestDTO(
                    googleAccessToken: googleAccessToken,
                    kakaoAccessToken: kakaoAccessToken
                )
            )
        case .sendEmailVerification(let body):
            return .requestJSONEncodable(body)
        case .resendEmailVerification(let body):
            return .requestJSONEncodable(body)
        case .verifyEmailCode(let body):
            return .requestJSONEncodable(body)
        case .resetPassword(let body):
            return .requestJSONEncodable(body)
        case .register(let body):
            return .requestJSONEncodable(body)
        case .registerExistingChallenger(let code):
            return .requestJSONEncodable(
                RegisterExistingChallengerRequestDTO(code: code)
            )
        case .getSchools, .getTerms:
            return .requestPlain
        case .registerCredential(let body):
            return .requestJSONEncodable(body)
        case .changePassword(let body):
            return .requestJSONEncodable(body)
        }
    }
}
