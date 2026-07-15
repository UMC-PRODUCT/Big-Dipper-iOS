//
//  AuthRouterTests.swift
//  AuthDataTests
//
//  Created by euijjang97 on 7/9/26.
//

import Testing
import Foundation
import Moya
@testable import AuthData

// MARK: - Suite: 신규 10개 케이스 — path/method 계약

@Suite("AuthRouter — 회원가입 슬라이스 신규 케이스 path/method 계약")
struct AuthRouterRegistrationPathMethodTests {

    @Test("sendEmailVerification — path/method")
    func sendEmailVerification() {
        let router = AuthRouter.sendEmailVerification(
            body: SendEmailVerificationRequestDTO(email: "a@umc.kr", purpose: "REGISTER")
        )
        #expect(router.path == "/api/v1/auth/email-verification")
        #expect(router.method == .post)
    }

    @Test("resendEmailVerification — path/method")
    func resendEmailVerification() {
        let router = AuthRouter.resendEmailVerification(
            body: ResendEmailVerificationRequestDTO(emailVerificationId: "51")
        )
        #expect(router.path == "/api/v1/auth/email-verification/resend")
        #expect(router.method == .post)
    }

    @Test("verifyEmailCode — path/method")
    func verifyEmailCode() {
        let router = AuthRouter.verifyEmailCode(
            body: VerifyEmailCodeRequestDTO(emailVerificationId: "51", verificationCode: "123456")
        )
        #expect(router.path == "/api/v1/auth/email-verification/code")
        #expect(router.method == .post)
    }

    @Test("checkEmailAvailability — path/method")
    func checkEmailAvailability() {
        let router = AuthRouter.checkEmailAvailability(
            query: CheckEmailAvailabilityQuery(email: "a@umc.kr")
        )
        #expect(router.path == "/api/v1/auth/email/availability")
        #expect(router.method == .get)
    }

    @Test("fetchSchools — path/method")
    func fetchSchools() {
        let router = AuthRouter.fetchSchools
        #expect(router.path == "/api/v1/schools/all")
        #expect(router.method == .get)
    }

    @Test(
        "fetchTerms — termsType이 path에 보간되고 method는 .get",
        arguments: ["SERVICE", "PRIVACY", "MARKETING"]
    )
    func fetchTerms(termsType: String) {
        let router = AuthRouter.fetchTerms(termsType: termsType)
        #expect(router.path == "/api/v1/terms/type/\(termsType)")
        #expect(router.method == .get)
    }

    @Test("register — path/method")
    func register() {
        let router = AuthRouter.register(body: makeRegisterRequestDTO())
        #expect(router.path == "/api/v1/member/register")
        #expect(router.method == .post)
    }

    @Test("registerByEmail — path/method")
    func registerByEmail() {
        let router = AuthRouter.registerByEmail(body: makeEmailRegisterRequestDTO())
        #expect(router.path == "/api/v1/member/register/email")
        #expect(router.method == .post)
    }

    @Test("registerCredential — path/method")
    func registerCredential() {
        let router = AuthRouter.registerCredential(
            body: RegisterCredentialRequestDTO(rawPassword: "pw123456")
        )
        #expect(router.path == "/api/v1/auth/credentials")
        #expect(router.method == .post)
    }

    @Test("registerExistingChallenger — path/method")
    func registerExistingChallenger() {
        let router = AuthRouter.registerExistingChallenger(
            body: RegisterExistingChallengerRequestDTO(code: "ABC123")
        )
        #expect(router.path == "/api/v1/challenger-record/member")
        #expect(router.method == .post)
    }
}

// MARK: - Suite: 신규 케이스 task 형태 계약

@Suite("AuthRouter — 신규 케이스 task 형태 계약")
struct AuthRouterRegistrationTaskTests {

    @Test("본문 전송 케이스(7종) — task는 .requestJSONEncodable")
    func jsonEncodableTasks() {
        let routers: [AuthRouter] = [
            .sendEmailVerification(
                body: SendEmailVerificationRequestDTO(email: "a@umc.kr", purpose: "REGISTER")
            ),
            .resendEmailVerification(
                body: ResendEmailVerificationRequestDTO(emailVerificationId: "51")
            ),
            .verifyEmailCode(
                body: VerifyEmailCodeRequestDTO(
                    emailVerificationId: "51",
                    verificationCode: "123456"
                )
            ),
            .register(body: makeRegisterRequestDTO()),
            .registerByEmail(body: makeEmailRegisterRequestDTO()),
            .registerCredential(body: RegisterCredentialRequestDTO(rawPassword: "pw123456")),
            .registerExistingChallenger(
                body: RegisterExistingChallengerRequestDTO(code: "ABC123")
            ),
        ]
        for router in routers {
            guard case .requestJSONEncodable = router.task else {
                Issue.record("task가 .requestJSONEncodable 이어야 함 — 실제: \(router.task)")
                continue
            }
        }
    }

    @Test("fetchSchools/fetchTerms — task는 .requestPlain")
    func plainTasks() {
        #expect(isRequestPlain(AuthRouter.fetchSchools.task))
        #expect(isRequestPlain(AuthRouter.fetchTerms(termsType: "SERVICE").task))
    }

    @Test(
        "checkEmailAvailability — task는 .requestParameters(URLEncoding.queryString) + email 키 포함"
    )
    func checkEmailAvailabilityTask() {
        let router = AuthRouter.checkEmailAvailability(
            query: CheckEmailAvailabilityQuery(email: "a@umc.kr")
        )
        guard case let .requestParameters(parameters, encoding) = router.task else {
            Issue.record("task가 .requestParameters 여야 함 — 실제: \(router.task)")
            return
        }
        #expect(parameters["email"] as? String == "a@umc.kr")
        #expect(encoding is URLEncoding)
    }
}

// MARK: - Suite: 기존 로그인 케이스 회귀 계약

@Suite("AuthRouter — 기존 로그인 케이스 회귀 계약")
struct AuthRouterExistingCasesTests {

    @Test("loginKakao — path/method/task")
    func loginKakao() {
        let router = AuthRouter.loginKakao(
            body: LoginKakaoRequestDTO(accessToken: "kakao-token", email: "a@umc.kr")
        )
        #expect(router.path == "/api/v1/auth/login/kakao")
        #expect(router.method == .post)
        guard case .requestJSONEncodable = router.task else {
            Issue.record("task가 .requestJSONEncodable 이어야 함 — 실제: \(router.task)")
            return
        }
    }
}

// MARK: - Suite: 신규 Request DTO / Query 인코딩 계약

@Suite("AuthRouter — 신규 Request DTO/Query 인코딩 계약")
struct AuthRouterRequestDTOEncodingTests {

    @Test("TermsAgreementDTO — { termsId, isAgreed } 로 인코딩")
    func termsAgreementDTOEncoding() throws {
        let json = try encodeToJSON(TermsAgreementDTO(termsId: "1", isAgreed: true))
        #expect(json["termsId"] as? String == "1")
        #expect(json["isAgreed"] as? Bool == true)
        #expect(json.keys.count == 2)
    }

    @Test("EmailRegisterRequestDTO — termsAgreements가 배열로 중첩 인코딩됨")
    func emailRegisterDTOEncoding() throws {
        let dto = makeEmailRegisterRequestDTO()
        let json = try encodeToJSON(dto)

        #expect(json["rawPassword"] as? String == "pw123456")
        #expect(json["schoolId"] as? String == "1")
        let agreements = try #require(json["termsAgreements"] as? [[String: Any]])
        #expect(agreements.count == 1)
        #expect(agreements.first?["termsId"] as? String == "1")
    }

    @Test("RegisterRequestDTO — profileImageId가 nil이면 키가 인코딩되지 않는다")
    func registerDTOOmitsNilProfileImageId() throws {
        let dto = makeRegisterRequestDTO(profileImageId: nil)
        let json = try encodeToJSON(dto)
        #expect(json["profileImageId"] == nil)
        #expect(json["oAuthVerificationToken"] as? String == "oauth-token")
    }

    @Test("CheckEmailAvailabilityQuery.toParameters — email 단일 키")
    func checkEmailAvailabilityQueryParameters() {
        let query = CheckEmailAvailabilityQuery(email: "a@umc.kr")
        #expect(query.toParameters["email"] as? String == "a@umc.kr")
        #expect(query.toParameters.keys.count == 1)
    }
}

// MARK: - Suite: 비밀번호 재설정(ResetPassword) 케이스 계약

@Suite("AuthRouter — 비밀번호 재설정(ResetPassword) 케이스 계약")
struct AuthRouterResetPasswordTests {

    @Test("resetPassword — path는 /api/v1/auth/password/reset, method는 .patch")
    func resetPasswordPathMethod() {
        let router = AuthRouter.resetPassword(
            body: ResetPasswordRequestDTO(
                emailVerificationToken: "email-token",
                newPassword: "newPassword123"
            )
        )
        #expect(router.path == "/api/v1/auth/password/reset")
        #expect(router.method == .patch)
    }

    @Test("resetPassword — task는 .requestJSONEncodable")
    func resetPasswordTask() {
        let router = AuthRouter.resetPassword(
            body: ResetPasswordRequestDTO(
                emailVerificationToken: "email-token",
                newPassword: "newPassword123"
            )
        )
        guard case .requestJSONEncodable = router.task else {
            Issue.record("task가 .requestJSONEncodable 이어야 함 — 실제: \(router.task)")
            return
        }
    }

    @Test("ResetPasswordRequestDTO — { emailVerificationToken, newPassword } 로 인코딩")
    func resetPasswordRequestDTOEncoding() throws {
        let dto = ResetPasswordRequestDTO(
            emailVerificationToken: "email-token",
            newPassword: "newPassword123"
        )
        let json = try encodeToJSON(dto)
        #expect(json["emailVerificationToken"] as? String == "email-token")
        #expect(json["newPassword"] as? String == "newPassword123")
        #expect(json.keys.count == 2)
    }
}

// MARK: - Test Helpers

private func makeRegisterRequestDTO(profileImageId: String? = "img-1") -> RegisterRequestDTO {
    RegisterRequestDTO(
        oAuthVerificationToken: "oauth-token",
        name: "홍길동",
        nickname: "길동이",
        emailVerificationToken: "email-token",
        schoolId: "1",
        profileImageId: profileImageId,
        termsAgreements: [TermsAgreementDTO(termsId: "1", isAgreed: true)]
    )
}

private func makeEmailRegisterRequestDTO() -> EmailRegisterRequestDTO {
    EmailRegisterRequestDTO(
        rawPassword: "pw123456",
        name: "홍길동",
        nickname: "길동이",
        emailVerificationToken: "email-token",
        schoolId: "1",
        termsAgreements: [TermsAgreementDTO(termsId: "1", isAgreed: true)]
    )
}

private func isRequestPlain(_ task: Moya.Task) -> Bool {
    if case .requestPlain = task { return true }
    return false
}

private func encodeToJSON(_ value: some Encodable) throws -> [String: Any] {
    let data = try JSONEncoder().encode(value)
    let object = try JSONSerialization.jsonObject(with: data)
    return try #require(object as? [String: Any])
}
