import Foundation
@testable import AuthDomain

/// UseCase 위임 테스트에서 공용으로 던지는 센티넬 에러
///
/// repository가 던진 에러가 UseCase를 통해 그대로 전파되는지 확인할 때 사용합니다.
enum AuthTestError: Error, Equatable {
    case boom
}

/// `AuthRepositoryProtocol`의 테스트용 Mock 구현체
///
/// UseCase가 **어떤 메서드를 어떤 인자로 호출했는지**를 기록하고(`...CallCount`, `...Received...`),
/// 각 메서드가 반환/던질 값을 주입할 수 있습니다(`...Result` / `...Error`).
final class MockAuthRepository: AuthRepositoryProtocol, @unchecked Sendable {

    enum MockError: Error, Equatable {
        /// 테스트가 반환값을 주입하지 않은 메서드가 호출됨
        case notStubbed
    }

    // MARK: - hasSession

    var hasSessionResult: Bool = false
    private(set) var hasSessionCallCount = 0

    func hasSession() async -> Bool {
        hasSessionCallCount += 1
        return hasSessionResult
    }

    // MARK: - refreshSession

    var refreshSessionError: Error?
    private(set) var refreshSessionCallCount = 0

    func refreshSession() async throws {
        refreshSessionCallCount += 1
        if let refreshSessionError {
            throw refreshSessionError
        }
    }

    // MARK: - logout

    var logoutError: Error?
    private(set) var logoutCallCount = 0

    func logout() async throws {
        logoutCallCount += 1
        if let logoutError {
            throw logoutError
        }
    }

    // MARK: - loginKakao

    var loginKakaoResult: Result<OAuthLoginResult, Error> = .failure(MockError.notStubbed)
    private(set) var loginKakaoCallCount = 0
    private(set) var loginKakaoReceivedAccessToken: String?
    private(set) var loginKakaoReceivedEmail: String?

    func loginKakao(accessToken: String, email: String) async throws -> OAuthLoginResult {
        loginKakaoCallCount += 1
        loginKakaoReceivedAccessToken = accessToken
        loginKakaoReceivedEmail = email
        return try loginKakaoResult.get()
    }

    // MARK: - loginApple

    var loginAppleResult: Result<OAuthLoginResult, Error> = .failure(MockError.notStubbed)
    private(set) var loginAppleCallCount = 0
    private(set) var loginAppleReceivedAuthorizationCode: String?
    private(set) var loginAppleReceivedEmail: String?
    private(set) var loginAppleReceivedFullName: String?

    func loginApple(
        authorizationCode: String,
        email: String?,
        fullName: String?
    ) async throws -> OAuthLoginResult {
        loginAppleCallCount += 1
        loginAppleReceivedAuthorizationCode = authorizationCode
        loginAppleReceivedEmail = email
        loginAppleReceivedFullName = fullName
        return try loginAppleResult.get()
    }

    // MARK: - loginGoogle

    var loginGoogleResult: Result<OAuthLoginResult, Error> = .failure(MockError.notStubbed)
    private(set) var loginGoogleCallCount = 0
    private(set) var loginGoogleReceivedAccessToken: String?

    func loginGoogle(accessToken: String) async throws -> OAuthLoginResult {
        loginGoogleCallCount += 1
        loginGoogleReceivedAccessToken = accessToken
        return try loginGoogleResult.get()
    }
}
