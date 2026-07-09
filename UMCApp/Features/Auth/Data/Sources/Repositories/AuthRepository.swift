import AuthDomain
import CoreNetwork
import Foundation
import UMCFoundation

/// 인증/세션 관련 Repository 구현체
///
/// 세션 존재 확인·강제 갱신은 `NetworkClient`(Core 인프라)를 그대로 재사용하고,
/// 프로필 조회만 `AuthRouter`를 통해 API를 직접 호출한다.
///
/// - Note: `AuthRegistrationRepositoryProtocol`이 요구하는 `Sendable`을 채택하기 위해
///   `@unchecked Sendable`을 사용한다. `MoyaNetworkAdapter`(`CoreNetwork`)가 아직
///   `Sendable`을 채택하지 않아 컴파일러가 이를 추론할 수 없기 때문이다(`MyPageRepository`와
///   동일 패턴, `Features/MyPage/Data/Sources/Repository/MyPageRepository.swift:18` 참고).
///   저장 프로퍼티가 모두 불변(`let`)이고 값 타입 구성이라 실질적인 데이터 경쟁 위험은 없다.
public struct AuthRepository: AuthRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let adapter: MoyaNetworkAdapter
    private let networkClient: NetworkClient
    private let tokenStore: TokenStore

    // MARK: - Init

    public init(
        adapter: MoyaNetworkAdapter,
        networkClient: NetworkClient,
        tokenStore: TokenStore
    ) {
        self.adapter = adapter
        self.networkClient = networkClient
        self.tokenStore = tokenStore
    }

    // MARK: - Function

    public func hasSession() async -> Bool {
        await networkClient.isLoggedIn()
    }

    public func refreshSession() async throws {
        _ = try await networkClient.forceRefreshToken()
    }

    public func fetchMyProfile() async throws -> Profile {
        let response = try await adapter.request(AuthRouter.getMe)

        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<MemberMeResponseDTO>.self,
                from: response.data
            )
            let dto = try apiResponse.unwrap()
            return dto.toDomain()
        } catch let decodingError as DecodingError {
            #if DEBUG
            let rawBody = String(data: response.data, encoding: .utf8) ?? "<invalid utf8>"
            print("[AuthRepository] fetchMyProfile decodingError=\(decodingError)")
            print("[AuthRepository] fetchMyProfile rawBody=\(rawBody)")
            #endif
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }
    }

    public func loginKakao(accessToken: String, email: String) async throws -> OAuthLoginResult {
        try await performOAuthLogin(
            AuthRouter.loginKakao(
                body: LoginKakaoRequestDTO(accessToken: accessToken, email: email)
            )
        )
    }

    public func loginApple(
        authorizationCode: String,
        email: String?,
        fullName: String?
    ) async throws -> OAuthLoginResult {
        try await performOAuthLogin(
            AuthRouter.loginApple(
                body: LoginAppleRequestDTO(
                    authorizationCode: authorizationCode,
                    email: email,
                    fullName: fullName
                )
            )
        )
    }

    public func loginGoogle(accessToken: String) async throws -> OAuthLoginResult {
        try await performOAuthLogin(
            AuthRouter.loginGoogle(
                body: LoginGoogleRequestDTO(accessToken: accessToken)
            )
        )
    }

    // MARK: - Private Function

    /// OAuth 로그인 응답을 디코딩하고, 기존 회원이면 토큰을 저장한 뒤 결과를 반환한다.
    private func performOAuthLogin(_ target: AuthRouter) async throws -> OAuthLoginResult {
        let response = try await adapter.requestWithoutAuth(target)

        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<OAuthLoginResponseDTO>.self,
                from: response.data
            )
            let dto = try apiResponse.unwrap()

            if let tokenPair = dto.tokenPair {
                try await tokenStore.save(
                    accessToken: tokenPair.accessToken,
                    refreshToken: tokenPair.refreshToken
                )
                return .existingMember
            }
            return .newMember(verificationToken: dto.oAuthVerificationToken ?? "")
        } catch let decodingError as DecodingError {
            #if DEBUG
            // 응답 body에는 accessToken/refreshToken이 포함될 수 있어 raw body는 출력하지
            // 않고, 디코딩 에러 메시지만 남긴다.
            print("[AuthRepository] performOAuthLogin decodingError=\(decodingError)")
            #endif
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }
    }
}

// MARK: - AuthRegistrationRepositoryProtocol

/// 회원가입(SignUp) 슬라이스 데이터 접근 구현.
///
/// 이메일 인증/학교·약관 조회/이메일 중복 확인/소셜·이메일 가입은 비로그인 상태에서 호출되므로
/// `adapter.requestWithoutAuth`를, OAuth 회원 비밀번호 추가 등록·기존 챌린저 등록은 로그인 상태가
/// 전제이므로 `adapter.request`를 사용한다.
extension AuthRepository: AuthRegistrationRepositoryProtocol {

    // MARK: - Email Verification

    public func sendEmailVerification(
        email: String,
        purpose: EmailVerificationPurpose
    ) async throws -> String {
        do {
            let response = try await adapter.requestWithoutAuth(
                AuthRouter.sendEmailVerification(
                    body: SendEmailVerificationRequestDTO(email: email, purpose: purpose.rawValue)
                )
            )
            let apiResponse = try JSONDecoder().decode(
                APIResponse<EmailVerificationResponseDTO>.self,
                from: response.data
            )
            let dto = try apiResponse.unwrap()
            return dto.emailVerificationId
        } catch let decodingError as DecodingError {
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        } catch let repositoryError as RepositoryError {
            throw Self.mapEmailVerificationError(from: repositoryError) ?? repositoryError
        } catch let networkError as NetworkError {
            throw Self.mapEmailVerificationError(from: networkError) ?? networkError
        }
    }

    public func resendEmailVerification(emailVerificationId: String) async throws {
        do {
            let response = try await adapter.requestWithoutAuth(
                AuthRouter.resendEmailVerification(
                    body: ResendEmailVerificationRequestDTO(
                        emailVerificationId: emailVerificationId
                    )
                )
            )
            let apiResponse = try JSONDecoder().decode(
                APIResponse<EmptyResult>.self,
                from: response.data
            )
            try apiResponse.validateSuccess()
        } catch let decodingError as DecodingError {
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        } catch let repositoryError as RepositoryError {
            throw Self.mapEmailVerificationError(from: repositoryError) ?? repositoryError
        } catch let networkError as NetworkError {
            throw Self.mapEmailVerificationError(from: networkError) ?? networkError
        }
    }

    public func verifyEmailCode(
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

        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<VerifyEmailCodeResponseDTO>.self,
                from: response.data
            )
            let dto = try apiResponse.unwrap()
            return dto.emailVerificationToken
        } catch let decodingError as DecodingError {
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }
    }

    // MARK: - Email Availability

    public func checkEmailAvailability(email: String) async throws -> Bool {
        let response = try await adapter.requestWithoutAuth(
            AuthRouter.checkEmailAvailability(query: CheckEmailAvailabilityQuery(email: email))
        )

        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<CheckEmailAvailabilityResponseDTO>.self,
                from: response.data
            )
            let dto = try apiResponse.unwrap()
            return dto.available
        } catch let decodingError as DecodingError {
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }
    }

    // MARK: - School / Terms

    public func fetchSchools() async throws -> [School] {
        let response = try await adapter.requestWithoutAuth(AuthRouter.fetchSchools)

        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<SchoolListResponseDTO>.self,
                from: response.data
            )
            let dto = try apiResponse.unwrap()
            return dto.schools.map { $0.toDomain() }
        } catch let decodingError as DecodingError {
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }
    }

    public func fetchTerms(type: TermsType) async throws -> Terms {
        let response = try await adapter.requestWithoutAuth(
            AuthRouter.fetchTerms(termsType: type.rawValue)
        )

        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<TermsDTO>.self,
                from: response.data
            )
            let dto = try apiResponse.unwrap()
            return dto.toDomain(type: type)
        } catch let decodingError as DecodingError {
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }
    }

    // MARK: - Register

    public func register(
        oAuthVerificationToken: String,
        name: String,
        nickname: String,
        emailVerificationToken: String,
        schoolId: String,
        profileImageId: String?,
        termsAgreements: [TermsAgreement]
    ) async throws -> RegisterResult {
        let response = try await adapter.requestWithoutAuth(
            AuthRouter.register(
                body: RegisterRequestDTO(
                    oAuthVerificationToken: oAuthVerificationToken,
                    name: name,
                    nickname: nickname,
                    emailVerificationToken: emailVerificationToken,
                    schoolId: schoolId,
                    profileImageId: profileImageId,
                    termsAgreements: termsAgreements.map {
                        TermsAgreementDTO(termsId: $0.termsId, isAgreed: $0.isAgreed)
                    }
                )
            )
        )

        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<RegisterResponseDTO>.self,
                from: response.data
            )
            let dto = try apiResponse.unwrap()

            guard
                let accessToken = dto.accessToken, !accessToken.isEmpty,
                let refreshToken = dto.refreshToken, !refreshToken.isEmpty
            else {
                return RegisterResult(memberId: dto.memberId, sessionEstablished: false)
            }

            try await tokenStore.save(accessToken: accessToken, refreshToken: refreshToken)
            return RegisterResult(memberId: dto.memberId, sessionEstablished: true)
        } catch let decodingError as DecodingError {
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }
    }

    public func registerByEmail(
        rawPassword: String,
        name: String,
        nickname: String,
        emailVerificationToken: String,
        schoolId: String,
        termsAgreements: [TermsAgreement]
    ) async throws -> RegisterByIdPwResult {
        let response = try await adapter.requestWithoutAuth(
            AuthRouter.registerByEmail(
                body: EmailRegisterRequestDTO(
                    rawPassword: rawPassword,
                    name: name,
                    nickname: nickname,
                    emailVerificationToken: emailVerificationToken,
                    schoolId: schoolId,
                    termsAgreements: termsAgreements.map {
                        TermsAgreementDTO(termsId: $0.termsId, isAgreed: $0.isAgreed)
                    }
                )
            )
        )

        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<RegisterByIdPwResponseDTO>.self,
                from: response.data
            )
            let dto = try apiResponse.unwrap()

            // 이메일 가입은 서버가 항상 토큰을 발급한다(`RegisterByIdPwResponseDTO` 문서 참고).
            // DTO가 누락된 토큰을 빈 문자열로 흡수하므로, 빈 토큰을 유효 세션으로 저장하지
            // 않도록 `register()`와 동일하게 비어있지 않음을 가드한다.
            guard !dto.accessToken.isEmpty, !dto.refreshToken.isEmpty else {
                throw RepositoryError.decodingError(
                    detail: "registerByEmail: 서버 응답에 accessToken/refreshToken이 없습니다"
                )
            }

            try await tokenStore.save(accessToken: dto.accessToken, refreshToken: dto.refreshToken)
            return RegisterByIdPwResult(memberId: dto.memberId)
        } catch let decodingError as DecodingError {
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }
    }

    public func registerCredential(rawPassword: String) async throws {
        let response = try await adapter.request(
            AuthRouter.registerCredential(
                body: RegisterCredentialRequestDTO(rawPassword: rawPassword)
            )
        )

        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<EmptyResult>.self,
                from: response.data
            )
            try apiResponse.validateSuccess()
        } catch let decodingError as DecodingError {
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }
    }

    public func registerExistingChallenger(code: String) async throws {
        let response = try await adapter.request(
            AuthRouter.registerExistingChallenger(
                body: RegisterExistingChallengerRequestDTO(code: code)
            )
        )

        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<EmptyResult>.self,
                from: response.data
            )
            try apiResponse.validateSuccess()
        } catch let decodingError as DecodingError {
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }
    }
}

// MARK: - Helpers (Email Verification Error Mapping)
//
// 이 extension은 `private`가 아니라 모듈 기본 접근 수준(`internal`)을 사용한다.
// `mapEmailVerificationError(from:)`(RepositoryError 오버로드)를
// `@testable import AuthData`로 직접 단위 테스트하기 위함이며(Task 2 리뷰 Important 3),
// `parseServerError`는 개별적으로 `private`를 재지정해 모듈 밖은 물론 테스트에서도
// 노출되지 않도록 최소화한다.
extension AuthRepository {

    /// `NetworkError.requestFailed`(비-2xx 응답) 본문을 파싱해 `RepositoryError.serverError`로
    /// 정규화한다. 코드/메시지 어느 쪽도 파싱할 수 없으면 `nil`을 반환해 원본 에러를 그대로
    /// 전파하도록 한다.
    private static func parseServerError(from error: NetworkError) -> RepositoryError? {
        guard case .requestFailed(_, let data) = error,
              let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        let code = json["code"] as? String
        let message = (json["message"] as? String) ?? (json["result"] as? String)

        guard code != nil || message != nil else { return nil }
        return RepositoryError.serverError(code: code, message: message)
    }

    /// 이메일 인증 발송/재전송 에러 코드 → `EmailVerificationError` 매핑 (레거시
    /// `mapEmailVerificationError` 대응, 코드-의미 대응은 레거시와 동일하게 유지).
    ///
    /// - `AUTHENTICATION-0025`: 이메일 형식 오류
    /// - `AUTHENTICATION-0026`: 이미 가입된 이메일
    /// - `AUTHENTICATION-0027`: 인증 요청 과다(throttle)
    ///
    /// - Note: 이 extension이 `internal`(모듈 기본)이므로 별도 modifier 없이도
    ///   `@testable import AuthData`로 직접 단위 테스트할 수 있다.
    static func mapEmailVerificationError(
        from error: RepositoryError
    ) -> EmailVerificationError? {
        guard case .serverError(let code, _) = error else { return nil }

        switch code {
        case "AUTHENTICATION-0025":
            return .invalidEmailFormat
        case "AUTHENTICATION-0026":
            return .emailAlreadyExists
        case "AUTHENTICATION-0027":
            return .throttled
        default:
            return nil
        }
    }

    /// 비-2xx `NetworkError`를 `RepositoryError.serverError`로 정규화한 뒤 동일하게 매핑한다.
    static func mapEmailVerificationError(from error: NetworkError) -> Error? {
        guard let repositoryError = parseServerError(from: error) else { return nil }
        return mapEmailVerificationError(from: repositoryError) ?? repositoryError
    }
}
