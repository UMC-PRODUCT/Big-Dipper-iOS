//
//  NetworkErrorMappingTests.swift
//  UMCFoundationTests
//
//  HTTP 상태코드 → 시맨틱 케이스, URLError → 흡수 케이스, 헬퍼를 검증.
//

import Foundation
import Testing
@testable import UMCFoundation

@Suite("NetworkError 매핑 — 상태코드/URLError/헬퍼")
struct NetworkErrorMappingTests {

    // MARK: - 상태코드 매핑

    @Test("알려진 4xx/5xx 는 시맨틱 케이스로, 그 외는 requestFailed 폴백으로 매핑된다")
    func statusCodeMapping() {
        #expect(NetworkError.from(statusCode: 400, data: nil) == .badRequest(data: nil))
        #expect(NetworkError.from(statusCode: 403, data: nil) == .forbidden(data: nil))
        #expect(NetworkError.from(statusCode: 404, data: nil) == .notFound(data: nil))
        #expect(NetworkError.from(statusCode: 409, data: nil) == .conflict(data: nil))
        #expect(NetworkError.from(statusCode: 422, data: nil) == .unprocessable(data: nil))
        #expect(NetworkError.from(statusCode: 500, data: nil) == .serverError(statusCode: 500, data: nil))
        #expect(NetworkError.from(statusCode: 503, data: nil) == .serverError(statusCode: 503, data: nil))
        #expect(NetworkError.from(statusCode: 418, data: nil) == .requestFailed(statusCode: 418, data: nil))
    }

    // MARK: - URLError 흡수

    @Test("URLError 는 noNetwork/timeout/transport 로 흡수된다")
    func urlErrorMapping() {
        #expect(NetworkError.from(urlError: URLError(.notConnectedToInternet)) == .noNetwork)
        #expect(NetworkError.from(urlError: URLError(.networkConnectionLost)) == .noNetwork)
        #expect(NetworkError.from(urlError: URLError(.timedOut)) == .timeout)

        if case .transport = NetworkError.from(urlError: URLError(.cannotFindHost)) {
            // 통과
        } else {
            Issue.record("분류 불가 URLError 는 .transport 여야 한다")
        }
    }

    // MARK: - 헬퍼

    @Test("httpStatusCode/responseBody 헬퍼가 케이스 구조와 무관하게 값을 노출한다")
    func helpers() {
        let body = Data("payload".utf8)
        #expect(NetworkError.conflict(data: body).httpStatusCode == 409)
        #expect(NetworkError.conflict(data: body).responseBody == body)
        #expect(NetworkError.serverError(statusCode: 502, data: body).httpStatusCode == 502)
        #expect(NetworkError.requestFailed(statusCode: 410, data: body).httpStatusCode == 410)
        #expect(NetworkError.timeout.httpStatusCode == nil)
        #expect(NetworkError.noNetwork.responseBody == nil)
    }
}
