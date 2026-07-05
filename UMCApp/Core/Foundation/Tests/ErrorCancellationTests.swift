//
//  ErrorCancellationTests.swift
//  UMCFoundationTests
//
//  Created by euijjang97 on 7/5/26.
//

import Foundation
import Testing
@testable import UMCFoundation

@Suite("Error.isCancellation — 취소 판별")
struct ErrorCancellationTests {

    @Test("CancellationError 는 취소로 간주한다")
    func swiftCancellation() {
        let error: Error = CancellationError()
        #expect(error.isCancellation == true)
    }

    @Test("URLError(.cancelled) 는 취소로 간주한다")
    func urlCancelled() {
        let error: Error = URLError(.cancelled)
        #expect(error.isCancellation == true)
    }

    @Test("취소가 아닌 URLError 는 false")
    func urlOtherIsNotCancellation() {
        #expect((URLError(.timedOut) as Error).isCancellation == false)
        #expect((URLError(.notConnectedToInternet) as Error).isCancellation == false)
    }

    @Test("일반 에러는 취소가 아니다")
    func genericErrorIsNotCancellation() {
        struct SampleError: Error {}
        #expect((SampleError() as Error).isCancellation == false)

        let nsError = NSError(domain: "test", code: 1)
        #expect((nsError as Error).isCancellation == false)
    }
}
