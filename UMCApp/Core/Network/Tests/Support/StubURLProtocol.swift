//
//  StubURLProtocol.swift
//  CoreNetworkTests
//
//  Created by euijjang97 on 4/25/26.
//

import Foundation

/// URLSession을 가로채 임의의 응답을 주입하기 위한 URLProtocol 구현체입니다.
///
/// - Note: `URLSessionConfiguration.ephemeral`에 등록한 후 사용합니다.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {

    /// (request) → (data, statusCode, headers) 응답을 결정하는 핸들러
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Data, Int, [String: String]?))?

    /// 가로챈 모든 요청 (검증용)
    nonisolated(unsafe) static var capturedRequests: [URLRequest] = []
    private static let lock = NSLock()

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        handler = nil
        capturedRequests = []
    }

    static func record(_ request: URLRequest) {
        lock.lock(); defer { lock.unlock() }
        capturedRequests.append(request)
    }

    // MARK: - URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.record(request)

        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (data, statusCode, headers) = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// 테스트 전용 URLSession을 만듭니다.
@MainActor
func makeStubSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: config)
}
