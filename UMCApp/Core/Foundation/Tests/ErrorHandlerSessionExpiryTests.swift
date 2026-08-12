//
//  ErrorHandlerSessionExpiryTests.swift
//  UMCFoundationTests
//
//  Created by JEONG on 8/12/26.
//

import Foundation
import Testing
@testable import UMCFoundation

/// 알림 수신 여부를 스레드 안전하게 기록하는 박스
private final class NotificationFlag: @unchecked Sendable {
    private var value = false
    private let lock = NSLock()

    func mark() {
        lock.lock(); defer { lock.unlock() }
        value = true
    }

    var isMarked: Bool {
        lock.lock(); defer { lock.unlock() }
        return value
    }
}

@MainActor
private func postsSessionExpired(for error: Error) -> Bool {
    let handler = ErrorHandler()
    let flag = NotificationFlag()
    let observer = NotificationCenter.default.addObserver(
        forName: .authSessionExpired,
        object: nil,
        queue: nil
    ) { _ in flag.mark() }
    defer { NotificationCenter.default.removeObserver(observer) }

    handler.handle(error, context: ErrorContext(feature: "Auth", action: "refreshSession"))

    return flag.isMarked
}

@Suite("ErrorHandler — 세션 만료 판정", .serialized)
@MainActor
struct ErrorHandlerSessionExpiryTests {

    @Test("서버가 리프레시 토큰을 거부하면 세션 만료 알림을 발송한다")
    func postsOnTokenRejection() {
        #expect(postsSessionExpired(for: NetworkError.tokenRefreshFailed(reason: "invalid")))
        #expect(postsSessionExpired(for: NetworkError.noRefreshToken))
        #expect(postsSessionExpired(for: NetworkError.unauthorized))
        #expect(postsSessionExpired(for: AppError.auth(.sessionExpired)))
    }

    @Test("전송 계층 실패는 세션 만료로 다루지 않는다")
    func doesNotPostOnTransportFailure() {
        #expect(postsSessionExpired(for: NetworkError.noNetwork) == false)
        #expect(postsSessionExpired(for: NetworkError.timeout) == false)
        #expect(postsSessionExpired(for: URLError(.notConnectedToInternet)) == false)
        #expect(postsSessionExpired(for: URLError(.networkConnectionLost)) == false)
        #expect(postsSessionExpired(for: URLError(.cannotConnectToHost)) == false)
    }

    @Test("재시도 소진(maxRetryExceeded)도 세션을 파기하지 않는다")
    func doesNotPostOnMaxRetryExceeded() {
        #expect(postsSessionExpired(for: NetworkError.maxRetryExceeded) == false)
    }
}
