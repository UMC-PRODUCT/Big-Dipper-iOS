/// 회원가입(이메일 인증/학교·약관 조회/가입) 관련 데이터 접근 계층 인터페이스.
///
/// 세션/소셜로그인을 담당하는 `AuthRepositoryProtocol`과는 별도로 분리한다(ISP).
/// 두 Protocol 모두 동일한 `AuthRepository` 구현체가 함께 준수할 수 있다.
///
/// - Note: `AuthRepositoryProtocol`과 달리 `Sendable`을 채택한다. `AuthRepository`가 이를
///   준수하면 `MoyaNetworkAdapter`(`CoreNetwork`)가 아직 `Sendable`을 채택하지 않아
///   "stored property ... has non-Sendable type" 경고가 발생한다(Swift 6 언어 모드에서는 에러).
///   이 프로토콜의 책임 범위를 벗어나므로 이번 변경에서 `MoyaNetworkAdapter`는 건드리지 않았고,
///   Swift 6 전환 전 `CoreNetwork` 쪽에서 별도로 해소가 필요하다.
public protocol AuthRegistrationRepositoryProtocol: Sendable {

    /// 이메일로 인증 코드를 발송한다.
    /// - Parameters:
    ///   - email: 인증할 이메일 주소
    ///   - purpose: 인증 목적 (회원가입/비밀번호 재설정)
    /// - Returns: 이메일 인증 요청 식별자(emailVerificationId)
    func sendEmailVerification(
        email: String,
        purpose: EmailVerificationPurpose
    ) async throws -> String

    /// 이메일 인증 코드를 재전송한다.
    /// - Parameter emailVerificationId: 발송 시 발급받은 이메일 인증 요청 식별자
    func resendEmailVerification(emailVerificationId: String) async throws

    /// 이메일 인증 코드를 검증한다.
    /// - Parameters:
    ///   - emailVerificationId: 발송 시 발급받은 이메일 인증 요청 식별자
    ///   - verificationCode: 사용자가 입력한 인증 코드
    /// - Returns: 회원가입에 사용할 이메일 인증 토큰(emailVerificationToken)
    func verifyEmailCode(
        emailVerificationId: String,
        verificationCode: String
    ) async throws -> String

    /// 이메일 중복 가입 여부를 확인한다.
    /// - Parameter email: 확인할 이메일 주소
    /// - Returns: 사용 가능하면 true
    func checkEmailAvailability(email: String) async throws -> Bool

    /// 학교 목록을 조회한다.
    func fetchSchools() async throws -> [School]

    /// 특정 종류의 약관을 조회한다.
    /// - Parameter type: 약관 종류
    func fetchTerms(type: TermsType) async throws -> Terms

    /// 소셜 신규 회원가입을 완료한다.
    /// - Parameters:
    ///   - oAuthVerificationToken: 소셜 로그인 신규 회원 판정 시 발급받은 검증 토큰
    ///   - name: 이름
    ///   - nickname: 닉네임
    ///   - emailVerificationToken: 이메일 인증 완료 토큰
    ///   - schoolId: 선택한 학교 식별자
    ///   - profileImageId: 프로필 이미지 식별자(선택)
    ///   - termsAgreements: 약관 동의 목록
    /// - Returns: 가입 결과(세션 확립 여부 포함)
    func register(
        oAuthVerificationToken: String,
        name: String,
        nickname: String,
        emailVerificationToken: String,
        schoolId: String,
        profileImageId: String?,
        termsAgreements: [TermsAgreement]
    ) async throws -> RegisterResult

    /// 이메일(ID/PW) 회원가입을 완료한다.
    /// - Parameters:
    ///   - rawPassword: 원문 비밀번호
    ///   - name: 이름
    ///   - nickname: 닉네임
    ///   - emailVerificationToken: 이메일 인증 완료 토큰
    ///   - schoolId: 선택한 학교 식별자
    ///   - termsAgreements: 약관 동의 목록
    /// - Returns: 가입 결과
    func registerByEmail(
        rawPassword: String,
        name: String,
        nickname: String,
        emailVerificationToken: String,
        schoolId: String,
        termsAgreements: [TermsAgreement]
    ) async throws -> RegisterByIdPwResult

    /// OAuth 회원에게 이메일/비밀번호 로그인 수단을 추가 등록한다.
    /// - Parameter rawPassword: 원문 비밀번호
    func registerCredential(rawPassword: String) async throws

    /// 운영진이 발급한 6자리 코드로 기존 챌린저 기록을 등록한다.
    /// - Parameter code: 운영진 발급 코드
    func registerExistingChallenger(code: String) async throws
}
