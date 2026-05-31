//
//  AuthRepository.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/9/26.
//

import Foundation
import Moya

/// Auth Repository 구현체
///
/// - 인증 불요 API (login, renewToken): MoyaNetworkAdapter.requestWithoutAuth
/// - 인증 필요 API (getMyOAuth): MoyaNetworkAdapter.request
final class AuthRepository: AuthRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let adapter: MoyaNetworkAdapter
    private let decoder: JSONDecoder

    // MARK: - Init

    init(
        adapter: MoyaNetworkAdapter,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.adapter = adapter
        self.decoder = decoder
    }

    // MARK: - Function

    /// 카카오 소셜 로그인을 수행합니다.
    ///
    /// - Parameters:
    ///   - accessToken: 카카오 SDK에서 발급받은 액세스 토큰
    ///   - email: 카카오 계정 이메일
    /// - Returns: 기존 회원/신규 회원 분기 결과
    func loginKakao(
        accessToken: String,
        email: String
    ) async throws -> OAuthLoginResult {
        let response = try await adapter.requestWithoutAuth(
            AuthRouter.loginKakao(
                body: LoginKakaoRequestDTO(
                    accessToken: accessToken,
                    email: email
                )
            )
        )
        #if DEBUG
        if let json = String(data: response.data, encoding: .utf8) {
            print("[Auth] 카카오 로그인 응답: \(json)")
        }
        #endif
        let apiResponse = try decoder.decode(
            APIResponse<OAuthLoginResponseDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().toDomain()
    }

    /// Apple 소셜 로그인을 수행합니다.
    ///
    /// - Parameters:
    ///   - authorizationCode: Apple Sign In에서 발급받은 인증 코드
    ///   - email: Apple에서 제공한 이메일(최초 로그인 시)
    ///   - fullName: Apple에서 제공한 이름(최초 로그인 시)
    /// - Returns: 기존 회원/신규 회원 분기 결과
    func loginApple(
        authorizationCode: String,
        email: String?,
        fullName: String?
    ) async throws -> OAuthLoginResult {
        let response = try await adapter.requestWithoutAuth(
            AuthRouter.loginApple(
                body: LoginAppleRequestDTO(
                    authorizationCode: authorizationCode,
                    email: email,
                    fullName: fullName,
                    clientType: "IOS"
                )
            )
        )
        #if DEBUG
        if let json = String(data: response.data, encoding: .utf8) {
            print("[Auth] 애플 로그인 응답: \(json)")
        }
        #endif
        let apiResponse = try decoder.decode(
            APIResponse<OAuthLoginResponseDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().toDomain()
    }

    /// 이메일 로그인을 수행합니다.
    ///
    /// - Parameter body: email / password
    /// - Returns: 회원 ID + 토큰 쌍
    func loginByEmail(
        _ body: EmailLoginRequestDTO
    ) async throws -> LoginByIdPwResult {
        do {
            let response = try await adapter.requestWithoutAuth(
                AuthRouter.loginByEmail(body: body)
            )
            #if DEBUG
            if let json = String(data: response.data, encoding: .utf8) {
                print("[Auth] 이메일 로그인 응답: \(json)")
            }
            #endif
            let apiResponse = try decoder.decode(
                APIResponse<LoginByIdPwResponseDTO>.self,
                from: response.data
            )
            return try apiResponse.unwrap().toDomain()
        } catch let error as NetworkError {
            throw Self.parseServerError(from: error) ?? error
        }
    }

    /// 이메일 회원가입을 수행합니다.
    ///
    /// - Parameter body: 회원가입 요청 DTO
    /// - Returns: 생성된 회원 ID + 토큰 쌍 (가입과 동시에 발급)
    func registerByEmail(
        _ body: EmailRegisterRequestDTO
    ) async throws -> RegisterByIdPwResult {
        do {
            let response = try await adapter.requestWithoutAuth(
                AuthRouter.registerByEmail(body: body)
            )
            #if DEBUG
            if let json = String(data: response.data, encoding: .utf8) {
                print("[Auth] 이메일 회원가입 응답: \(json)")
            }
            #endif
            let apiResponse = try decoder.decode(
                APIResponse<RegisterByIdPwResponseDTO>.self,
                from: response.data
            )
            return try apiResponse.unwrap().toDomain()
        } catch let error as NetworkError {
            throw Self.parseServerError(from: error) ?? error
        }
    }

    /// 이메일 중복 검사를 수행합니다.
    ///
    /// - Parameter email: 검사 대상 이메일 주소
    /// - Returns: 사용 가능 여부 (true = 사용 가능)
    func checkEmailAvailability(
        email: String
    ) async throws -> Bool {
        do {
            let response = try await adapter.requestWithoutAuth(
                AuthRouter.checkEmailAvailability(
                    query: CheckEmailAvailabilityQuery(email: email)
                )
            )
            let apiResponse = try decoder.decode(
                APIResponse<CheckEmailAvailabilityResponseDTO>.self,
                from: response.data
            )
            return try apiResponse.unwrap().available
        } catch let error as NetworkError {
            throw Self.parseServerError(from: error) ?? error
        }
    }

    /// 리프레시 토큰으로 새 토큰 쌍을 발급받습니다.
    func renewToken(
        refreshToken: String
    ) async throws -> TokenPair {
        let response = try await adapter.requestWithoutAuth(
            AuthRouter.renewToken(
                body: RenewTokenRequestDTO(refreshToken: refreshToken)
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<TokenRenewResponseDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().toDomain()
    }

    /// 내 OAuth 연동 정보 목록을 조회합니다.
    func getMyOAuth() async throws -> [MemberOAuth] {
        let response = try await adapter.request(AuthRouter.getMyOAuth)
        let apiResponse = try decoder.decode(
            APIResponse<[MemberOAuthDTO]>.self,
            from: response.data
        )
        return try apiResponse.unwrap().map { $0.toDomain() }
    }

    /// OAuth 수단을 추가 연동하고 갱신된 전체 연동 목록을 반환합니다.
    ///
    /// - Parameter oAuthVerificationToken: 소셜 로그인으로 발급받은 검증 토큰
    /// - Returns: 연동 완료 후 전체 OAuth 목록
    func addMemberOAuth(
        oAuthVerificationToken: String
    ) async throws -> [MemberOAuth] {
        let response = try await adapter.request(
            AuthRouter.addMemberOAuth(
                oAuthVerificationToken: oAuthVerificationToken
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<[MemberOAuthDTO]>.self,
            from: response.data
        )
        return try apiResponse.unwrap().map { $0.toDomain() }
    }

    /// OAuth 수단 연동을 해제합니다.
    ///
    /// - Parameters:
    ///   - memberOAuthId: 해제할 OAuth 연동 ID
    ///   - googleAccessToken: Google 해제 검증용 액세스 토큰
    ///   - kakaoAccessToken: Kakao 해제 검증용 액세스 토큰
    func deleteMemberOAuth(
        memberOAuthId: Int,
        googleAccessToken: String?,
        kakaoAccessToken: String?
    ) async throws {
        let response = try await adapter.request(
            AuthRouter.deleteMemberOAuth(
                memberOAuthId: memberOAuthId,
                googleAccessToken: googleAccessToken,
                kakaoAccessToken: kakaoAccessToken
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        try apiResponse.validateSuccess()
    }

    /// 이메일 인증 코드를 발송합니다.
    ///
    /// - Parameters:
    ///   - email: 인증할 이메일 주소
    ///   - purpose: 인증 목적 (회원가입/비밀번호 초기화)
    /// - Returns: 발급된 이메일 인증 ID
    func sendEmailVerification(
        email: String,
        purpose: EmailVerificationPurpose
    ) async throws -> String {
        do {
            let response = try await adapter.requestWithoutAuth(
                AuthRouter.sendEmailVerification(
                    body: SendEmailVerificationRequestDTO(
                        email: email,
                        purpose: purpose.rawValue
                    )
                )
            )
            let apiResponse = try decoder.decode(
                APIResponse<EmailVerificationResponseDTO>.self,
                from: response.data
            )
            return try apiResponse.unwrap().emailVerificationId
        } catch let error as NetworkError {
            throw Self.mapEmailVerificationError(from: error) ?? error
        }
    }

    /// 이메일 인증 코드를 재전송합니다.
    ///
    /// - Parameter emailVerificationId: 발송 시 발급된 인증 ID
    func resendEmailVerification(
        emailVerificationId: String
    ) async throws {
        do {
            let response = try await adapter.requestWithoutAuth(
                AuthRouter.resendEmailVerification(
                    body: ResendEmailVerificationRequestDTO(
                        emailVerificationId: emailVerificationId
                    )
                )
            )
            let apiResponse = try decoder.decode(
                APIResponse<EmptyResult>.self,
                from: response.data
            )
            try apiResponse.validateSuccess()
        } catch let error as NetworkError {
            throw Self.mapEmailVerificationError(from: error) ?? error
        }
    }

    /// 비밀번호를 초기화합니다.
    ///
    /// - Parameters:
    ///   - emailVerificationToken: `purpose=PASSWORD_RESET`로 발급된 토큰
    ///   - newPassword: 새 비밀번호 (평문)
    func resetPassword(
        emailVerificationToken: String,
        newPassword: String
    ) async throws {
        do {
            let response = try await adapter.requestWithoutAuth(
                AuthRouter.resetPassword(
                    body: ResetPasswordRequestDTO(
                        emailVerificationToken: emailVerificationToken,
                        newPassword: newPassword
                    )
                )
            )
            let apiResponse = try decoder.decode(
                APIResponse<EmptyResult>.self,
                from: response.data
            )
            try apiResponse.validateSuccess()
        } catch let error as NetworkError {
            throw Self.parseServerError(from: error) ?? error
        }
    }

    /// 이메일 인증 코드를 검증합니다.
    ///
    /// - Parameters:
    ///   - emailVerificationId: 이메일 인증 ID
    ///   - verificationCode: 사용자가 입력한 인증 코드
    /// - Returns: 이메일 인증 토큰
    func verifyEmailCode(
        emailVerificationId: String,
        verificationCode: String
    ) async throws -> String {
        let response = try await adapter.requestWithoutAuth(
            AuthRouter.verifyEmailCode(
                body: VerifyEmailCodeRequestDTO(
                    emailVerificationId: emailVerificationId,
                    verificationCode: verificationCode
                )
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<VerifyEmailCodeResponseDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().emailVerificationToken
    }

    /// 회원가입을 수행합니다.
    ///
    /// - Parameter request: 회원가입 요청 DTO
    /// - Returns: 생성된 회원 ID (서버 응답 String 기준)
    func register(
        request: RegisterRequestDTO
    ) async throws -> String {
        do {
            let response = try await adapter.requestWithoutAuth(
                AuthRouter.register(body: request)
            )
            let apiResponse = try decoder.decode(
                APIResponse<RegisterResponseDTO>.self,
                from: response.data
            )
            let dto = try apiResponse.unwrap()
            return dto.memberId
        } catch let NetworkError.requestFailed(statusCode, data) {
            #if DEBUG
            if let data,
               let json = String(data: data, encoding: .utf8) {
                print("[Auth] register 에러 응답(\(statusCode)): \(json)")
            }
            #endif
            let networkError = NetworkError.requestFailed(
                statusCode: statusCode,
                data: data
            )
            throw Self.parseServerError(from: networkError) ?? networkError
        }
    }

    /// 기존 챌린저 코드로 인증합니다.
    func registerExistingChallenger(
        code: String
    ) async throws {
        do {
            let response = try await adapter.request(
                AuthRouter.registerExistingChallenger(code: code)
            )
            let apiResponse = try decoder.decode(
                APIResponse<EmptyResult>.self,
                from: response.data
            )
            try apiResponse.validateSuccess()
        } catch let error as NetworkError {
            throw Self.parseServerError(from: error) ?? error
        }
    }

    /// 학교 목록을 조회합니다.
    func getSchools() async throws -> [School] {
        let response = try await adapter.requestWithoutAuth(
            AuthRouter.getSchools
        )
        let apiResponse = try decoder.decode(
            APIResponse<SchoolListResponseDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().schools.map { $0.toDomain() }
    }

    /// 비밀번호를 변경합니다.
    ///
    /// - Parameters:
    ///   - currentPassword: 현재 비밀번호 (평문)
    ///   - newPassword: 새 비밀번호 (평문)
    func changePassword(
        currentPassword: String,
        newPassword: String
    ) async throws {
        do {
            let response = try await adapter.request(
                AuthRouter.changePassword(
                    body: ChangePasswordRequestDTO(
                        currentPassword: currentPassword,
                        newPassword: newPassword
                    )
                )
            )
            let apiResponse = try decoder.decode(
                APIResponse<EmptyResult>.self,
                from: response.data
            )
            try apiResponse.validateSuccess()
        } catch let error as NetworkError {
            throw Self.parseServerError(from: error) ?? error
        }
    }

    /// OAuth 회원 비밀번호를 추가 등록합니다.
    ///
    /// - Parameter rawPassword: 평문 비밀번호
    func registerCredential(rawPassword: String) async throws {
        let response = try await adapter.request(
            AuthRouter.registerCredential(
                body: RegisterCredentialRequestDTO(rawPassword: rawPassword)
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        try apiResponse.validateSuccess()
    }

    /// 약관 정보를 조회합니다.
    ///
    /// - Parameter termsType: 약관 종류 (SERVICE, PRIVACY)
    /// - Returns: 약관 정보
    func getTerms(
        termsType: String
    ) async throws -> Terms {
        guard let type = TermsType(rawValue: termsType) else {
            throw RepositoryError.decodingError(
                detail: "Unknown termsType: \(termsType)"
            )
        }

        let response = try await adapter.requestWithoutAuth(
            AuthRouter.getTerms(termsType: termsType)
        )

        do {
            let apiResponse = try decoder.decode(
                APIResponse<TermsDTO>.self,
                from: response.data
            )
            return try apiResponse.unwrap().toDomain(termsType: type)
        } catch let decodingError as DecodingError {
            let rawResponse = String(
                data: response.data,
                encoding: .utf8
            ) ?? "<non-utf8 response>"
            throw RepositoryError.decodingError(
                detail: """
                getTerms(\(termsType)) decoding failed
                - reason: \(describeDecodingError(decodingError))
                - response: \(rawResponse)
                """
            )
        }
    }
}

// MARK: - Private Helpers

private extension AuthRepository {
    /// 이메일 인증 발송/재전송 에러 코드 → AuthError 매핑
    ///
    /// - `AUTHENTICATION-0026 EMAIL_ALREADY_EXISTS` (409): 회원가입 시 이미 가입된 이메일
    /// - `AUTHENTICATION-0027 EMAIL_VERIFICATION_THROTTLED` (429): 60초 throttle
    /// - `AUTHENTICATION-0025 INVALID_EMAIL_FORMAT` (400): 잘못된 이메일 형식
    static func mapEmailVerificationError(from error: NetworkError) -> Error? {
        guard case .requestFailed(_, let data) = error,
              let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        let code = json["code"] as? String
        let message = (json["message"] as? String) ?? (json["result"] as? String)

        switch code {
        case "AUTHENTICATION-0026":
            return AuthError.emailAlreadyExists
        case "AUTHENTICATION-0027":
            return AuthError.emailVerificationThrottled
        case "AUTHENTICATION-0025":
            return AuthError.invalidEmailFormat
        default:
            guard code != nil || message != nil else { return nil }
            return RepositoryError.serverError(code: code, message: message)
        }
    }

    static func parseServerError(from error: NetworkError) -> Error? {
        guard case .requestFailed(_, let data) = error,
              let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        let code = json["code"] as? String
        let message = (json["message"] as? String) ?? (json["result"] as? String)

        guard code != nil || message != nil else {
            return nil
        }

        return RepositoryError.serverError(code: code, message: message)
    }

    func describeDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            let location = path.isEmpty ? key.stringValue : "\(path).\(key.stringValue)"
            return "Missing key: \(location)"
        case .typeMismatch(let type, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Type mismatch: expected \(type) at \(path)"
        case .valueNotFound(let type, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Value not found: \(type) at \(path)"
        case .dataCorrupted(let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Data corrupted at \(path): \(context.debugDescription)"
        @unknown default:
            return "Unknown decoding error"
        }
    }
}
