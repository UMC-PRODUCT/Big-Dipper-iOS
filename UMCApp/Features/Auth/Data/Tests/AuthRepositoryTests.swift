//
//  AuthRepositoryTests.swift
//  AuthDataTests
//
//  Created by euijjang97 on 7/11/26.
//

//  진짜 `AuthRepository`를 대상으로, 그 아래 네트워크 계층만 가짜(`StubAuthNetwork`)로 주입해
//  `registerByEmail`의 디코딩·도메인 매핑·토큰 저장·에러 매핑 계약을 검증한다.
//  (엔드포인트 path/method/task 계약은 `AuthRouterTests`에서 별도 검증)
//

import Foundation
import Testing
import Moya
import CoreNetwork
import UMCFoundation
import AuthDomain
@testable import AuthData

// MARK: - Test Doubles

/// ``AuthNetworkRequesting`` 가짜 구현.
///
/// 미리 설정한 결과(성공 본문 / 던질 에러)를 반환하고, 호출된 라우터의 경로·메서드·타깃을
/// 기록해 엔드포인트 계약과 전송 페이로드를 검증할 수 있게 한다.
/// `target.path`/`target.method`만 읽어 `NetworkConfig.baseURL`(테스트 번들 `fatalError`)을
/// 건드리지 않는다.
private final class StubAuthNetwork: AuthNetworkRequesting, @unchecked Sendable {

    enum Outcome {
        /// 200 응답으로 주어진 JSON 본문을 반환
        case success(Data)
        /// 요청 단계에서 에러를 던짐 (비-2xx 등)
        case failure(Error)
    }

    private let outcome: Outcome
    private(set) var requestCount = 0
    private(set) var requestWithoutAuthCount = 0
    private(set) var lastPath: String?
    private(set) var lastMethod: Moya.Method?
    private(set) var lastTarget: AuthRouter?

    init(_ outcome: Outcome) {
        self.outcome = outcome
    }

    func request<T: TargetType>(_ target: T) async throws -> Response {
        requestCount += 1
        capture(target)
        return try makeResponse()
    }

    func requestWithoutAuth<T: TargetType>(_ target: T) async throws -> Response {
        requestWithoutAuthCount += 1
        capture(target)
        return try makeResponse()
    }

    private func capture<T: TargetType>(_ target: T) {
        lastPath = target.path
        lastMethod = target.method
        lastTarget = target as? AuthRouter
    }

    private func makeResponse() throws -> Response {
        switch outcome {
        case .success(let data):
            return Response(statusCode: 200, data: data)
        case .failure(let error):
            throw error
        }
    }
}

/// ``TokenStore`` 가짜 구현. `save(accessToken:refreshToken:)` 호출 인자를 기록한다.
private actor FakeTokenStore: TokenStore {
    private(set) var savedAccessToken: String?
    private(set) var savedRefreshToken: String?
    private(set) var saveCallCount = 0

    func getAccessToken() async -> String? { savedAccessToken }
    func getRefreshToken() async -> String? { savedRefreshToken }

    func save(accessToken: String, refreshToken: String) async throws {
        saveCallCount += 1
        savedAccessToken = accessToken
        savedRefreshToken = refreshToken
    }

    func clear() async throws {
        savedAccessToken = nil
        savedRefreshToken = nil
    }
}

/// ``TokenRefreshService`` 가짜 구현. `registerByEmail`은 갱신 경로를 타지 않으므로 항상 실패한다.
private struct FakeTokenRefreshService: TokenRefreshService {
    func refresh(_ refreshToken: String) async throws -> TokenPair {
        throw NetworkError.timeout
    }
}

// MARK: - Fixtures

private enum Fixture {

    /// APIResponse 성공 봉투로 감싼 result 본문
    static func success(_ resultJSON: String) -> Data {
        Data("""
        { "success": true, "code": "200", "message": "성공", "result": \(resultJSON) }
        """.utf8)
    }

    /// isSuccess:false 실패 봉투
    static func failureBody(code: String?, message: String?) -> Data {
        var fields: [String] = ["\"success\": false"]
        if let code { fields.append("\"code\": \"\(code)\"") }
        if let message { fields.append("\"message\": \"\(message)\"") }
        fields.append("\"result\": null")
        return Data("{ \(fields.joined(separator: ", ")) }".utf8)
    }

    /// 이메일 회원가입 result 본문
    static func registerByEmailObject(
        memberId: String = "42",
        accessToken: String = "access-token-1",
        refreshToken: String = "refresh-token-1"
    ) -> String {
        """
        {
            "memberId": "\(memberId)",
            "accessToken": "\(accessToken)",
            "refreshToken": "\(refreshToken)"
        }
        """
    }
}

// MARK: - Helper

@MainActor
private func makeRepository(
    _ outcome: StubAuthNetwork.Outcome,
    tokenStore: FakeTokenStore = FakeTokenStore()
) -> (AuthRepository, StubAuthNetwork, FakeTokenStore) {
    let stub = StubAuthNetwork(outcome)
    let networkClient = AuthSystemFactory.makeTestNetworkClient(
        tokenStore: tokenStore,
        refreshService: FakeTokenRefreshService()
    )
    let repository = AuthRepository(
        networkRequesting: stub,
        networkClient: networkClient,
        tokenStore: tokenStore
    )
    return (repository, stub, tokenStore)
}

private func makeTermsAgreements() -> [TermsAgreement] {
    [TermsAgreement(termsId: "terms-1", isAgreed: true)]
}

// MARK: - Suite: 이메일(ID/PW) 회원가입

@MainActor
@Suite("AuthRepository — registerByEmail")
struct AuthRepositoryRegisterByEmailTests {

    @Test("성공 응답이면 토큰을 저장하고 RegisterByIdPwResult를 반환하며 /member/register/email(POST, 비인증)을 호출한다")
    func registerByEmailSucceeds() async throws {
        let (sut, stub, tokenStore) = makeRepository(
            .success(Fixture.success(Fixture.registerByEmailObject()))
        )

        let result = try await sut.registerByEmail(
            rawPassword: "password1234",
            name: "홍길동",
            nickname: "길동이",
            emailVerificationToken: "verify-token-1",
            schoolId: "1",
            termsAgreements: makeTermsAgreements()
        )

        #expect(result.memberId == "42")
        #expect(stub.requestWithoutAuthCount == 1)
        #expect(stub.requestCount == 0)
        #expect(stub.lastPath == "/api/v1/member/register/email")
        #expect(stub.lastMethod == .post)
        #expect(await tokenStore.saveCallCount == 1)
        #expect(await tokenStore.savedAccessToken == "access-token-1")
        #expect(await tokenStore.savedRefreshToken == "refresh-token-1")
    }

    @Test("응답에 토큰이 비어 있으면 RepositoryError.invalidResponse를 던지고 토큰을 저장하지 않는다")
    func registerByEmailThrowsInvalidResponseWhenTokensMissing() async throws {
        let (sut, _, tokenStore) = makeRepository(
            .success(Fixture.success(
                Fixture.registerByEmailObject(accessToken: "", refreshToken: "")
            ))
        )

        await #expect(throws: RepositoryError.invalidResponse(
            detail: "registerByEmail: 서버 응답에 accessToken/refreshToken이 없습니다"
        )) {
            _ = try await sut.registerByEmail(
                rawPassword: "password1234",
                name: "홍길동",
                nickname: "길동이",
                emailVerificationToken: "verify-token-1",
                schoolId: "1",
                termsAgreements: makeTermsAgreements()
            )
        }

        #expect(await tokenStore.saveCallCount == 0)
    }

    @Test("isSuccess:false면 RepositoryError.serverError를 던진다")
    func registerByEmailThrowsServerErrorWhenUnsuccessful() async {
        let (sut, _, _) = makeRepository(
            .success(Fixture.failureBody(code: "AUTH409", message: "이미 가입된 이메일입니다."))
        )

        await #expect(throws: RepositoryError.serverError(
            code: "AUTH409", message: "이미 가입된 이메일입니다."
        )) {
            _ = try await sut.registerByEmail(
                rawPassword: "password1234",
                name: "홍길동",
                nickname: "길동이",
                emailVerificationToken: "verify-token-1",
                schoolId: "1",
                termsAgreements: makeTermsAgreements()
            )
        }
    }

    @Test("응답 본문을 파싱할 수 없으면 RepositoryError.decodingError를 던진다")
    func registerByEmailThrowsDecodingErrorForMalformedBody() async {
        let (sut, _, _) = makeRepository(.success(Data("not-json".utf8)))

        await #expect(throws: RepositoryError.self) {
            _ = try await sut.registerByEmail(
                rawPassword: "password1234",
                name: "홍길동",
                nickname: "길동이",
                emailVerificationToken: "verify-token-1",
                schoolId: "1",
                termsAgreements: makeTermsAgreements()
            )
        }
    }

    @Test("파싱 불가한 NetworkError는 원본 그대로 전파한다")
    func registerByEmailPropagatesNonMappableError() async {
        let (sut, _, _) = makeRepository(.failure(NetworkError.timeout))

        await #expect(throws: NetworkError.timeout) {
            _ = try await sut.registerByEmail(
                rawPassword: "password1234",
                name: "홍길동",
                nickname: "길동이",
                emailVerificationToken: "verify-token-1",
                schoolId: "1",
                termsAgreements: makeTermsAgreements()
            )
        }
    }
}
