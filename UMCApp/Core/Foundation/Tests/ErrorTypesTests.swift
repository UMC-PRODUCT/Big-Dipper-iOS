//
//  ErrorTypesTests.swift
//  UMCFoundationTests
//
//  Created by euijjang97 on 7/5/26.
//

import Foundation
import Testing
@testable import UMCFoundation

@Suite("RepositoryError — 계산 프로퍼티")
struct RepositoryErrorTests {

    @Test("serverError 는 재시도 가능, decodingError 는 불가")
    func isRetryable() {
        #expect(RepositoryError.serverError(code: "USER404", message: "없음").isRetryable == true)
        #expect(RepositoryError.decodingError(detail: "x").isRetryable == false)
    }

    @Test("code 는 serverError 에서만 값을 가진다")
    func code() {
        #expect(RepositoryError.serverError(code: "AUTH001", message: nil).code == "AUTH001")
        #expect(RepositoryError.decodingError(detail: nil).code == nil)
    }

    @Test("errorDescription 은 message 우선, 없으면 기본 문구")
    func errorDescription() {
        #expect(RepositoryError.serverError(code: nil, message: "커스텀").errorDescription == "커스텀")
        #expect(
            RepositoryError.serverError(code: nil, message: nil).errorDescription
                == "서버 오류가 발생했습니다"
        )
    }
}

@Suite("NetworkError — severity / isRetryable")
struct NetworkErrorComputedTests {

    @Test("인증 계열은 critical + 재시도 불가")
    func authFamily() {
        let cases: [NetworkError] = [
            .unauthorized, .tokenRefreshFailed(reason: nil), .noRefreshToken, .maxRetryExceeded
        ]
        for error in cases {
            #expect(error.severity == .critical)
            #expect(error.isRetryable == false)
        }
    }

    @Test("5xx 는 critical + 재시도 가능, 4xx 는 warning + 재시도 불가")
    func requestFailed() {
        let serverSide = NetworkError.requestFailed(statusCode: 503, data: nil)
        let clientSide = NetworkError.requestFailed(statusCode: 404, data: nil)
        #expect(serverSide.isRetryable == true)
        #expect(serverSide.severity == .critical)
        #expect(clientSide.isRetryable == false)
        #expect(clientSide.severity == .warning)
    }

    @Test("네트워크 단절/타임아웃은 재시도 가능 + warning")
    func transient() {
        #expect(NetworkError.noNetwork.isRetryable == true)
        #expect(NetworkError.timeout.isRetryable == true)
        #expect(NetworkError.timeout.severity == .warning)
    }
}

@Suite("AppError — 하위 에러 위임 규칙")
struct AppErrorComputedTests {

    @Test("repository/network 재시도 여부는 하위 에러에 위임한다")
    func retryDelegation() {
        #expect(AppError.repository(.serverError(code: nil, message: nil)).isRetryable == true)
        #expect(AppError.network(.timeout).isRetryable == true)
        #expect(AppError.network(.unauthorized).isRetryable == false)
    }

    @Test("auth 는 critical + 재시도 불가")
    func auth() {
        let error = AppError.auth(.sessionExpired)
        #expect(error.isRetryable == false)
        #expect(error.severity == .critical)
    }

    @Test("unknown 은 재시도 가능 + 일반 사용자 메시지")
    func unknown() {
        let error = AppError.unknown(message: "boom")
        #expect(error.isRetryable == true)
        #expect(error.userMessage == "일시적인 오류가 발생했습니다. 다시 시도해주세요.")
        #expect(error.errorDescription == "boom")
    }
}
