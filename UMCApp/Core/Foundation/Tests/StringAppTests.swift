//
//  StringAppTests.swift
//  UMCFoundationTests
//
//  Created by euijjang97 on 7/5/26.
//

import Foundation
import Testing
@testable import UMCFoundation

@Suite("String+App — 검증/포매팅 유틸리티")
struct StringAppTests {

    // MARK: - isValidHTTPURL

    @Test(
        "유효한 http/https 절대 URL 은 true",
        arguments: [
            "https://api.umc.example.com",
            "http://example.io/path?q=1",
            "https://sub.domain.co.kr/a/b",
        ]
    )
    func validURLs(value: String) {
        #expect(value.isValidHTTPURL == true)
    }

    @Test(
        "http/https 가 아니거나 host 가 없으면 false",
        arguments: [
            "ftp://example.com",
            "https://",
            "not a url",
            "",
            "example.com",
            "mailto:hi@umc.dev",
        ]
    )
    func invalidURLs(value: String) {
        #expect(value.isValidHTTPURL == false)
    }

    // MARK: - forceCharWrapping

    @Test("문자 사이에 zero-width space 를 삽입한다")
    func forceCharWrappingInsertsZWSP() {
        let result = "ab".forceCharWrapping
        #expect(result == "a\u{200B}b")
    }

    @Test("빈 문자열은 그대로 빈 문자열")
    func forceCharWrappingEmpty() {
        #expect("".forceCharWrapping == "")
    }

    @Test("단일 문자는 구분자가 삽입되지 않는다")
    func forceCharWrappingSingle() {
        #expect("x".forceCharWrapping == "x")
    }
}
