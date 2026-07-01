//
//  ErrorHandlerURLErrorTests.swift
//  UMCFoundationTests
//
//  ErrorHandler 가 URLError 를 단일 팩토리 경유로 NetworkError 에 매핑하는지 검증.
//

import Foundation
import Testing
@testable import UMCFoundation

@MainActor
@Suite("ErrorHandler — URLError 변환")
struct ErrorHandlerURLErrorTests {

    @Test("notConnectedToInternet 는 .network(.noNetwork) 로 변환된다")
    func mapsNoNetwork() {
        let handler = ErrorHandler()
        handler.handle(URLError(.notConnectedToInternet),
                       context: .init(feature: "Test", action: "t"))
        #expect(handler.currentError?.error == .network(.noNetwork))
    }

    @Test("분류 불가 URLError 는 .network(.transport) 로 변환된다")
    func mapsTransport() {
        let handler = ErrorHandler()
        handler.handle(URLError(.cannotFindHost),
                       context: .init(feature: "Test", action: "t"))
        if case .network(.transport) = handler.currentError?.error {
            // 통과
        } else {
            Issue.record("cannotFindHost 는 .network(.transport) 여야 한다")
        }
    }
}
