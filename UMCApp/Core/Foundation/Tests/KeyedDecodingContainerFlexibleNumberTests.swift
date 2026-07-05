//
//  KeyedDecodingContainerFlexibleNumberTests.swift
//  UMCFoundationTests
//
//  서버가 정수/실수를 String 또는 Number 어느 쪽으로 보내든 디코딩이 통과하는지 검증.
//

import Foundation
import Testing
@testable import UMCFoundation

@Suite("KeyedDecodingContainer+FlexibleNumber — 서버 응답 숫자 양방향 디코딩 (도메인 규칙)")
struct KeyedDecodingContainerFlexibleNumberTests {

    // MARK: - Test Wrappers

    private struct StringWrapper: Decodable {
        let value: String
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try container.decodeFlexibleString(forKey: .value)
        }
        enum CodingKeys: String, CodingKey { case value }
    }

    private struct OptionalStringWrapper: Decodable {
        let value: String?
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try container.decodeFlexibleStringIfPresent(forKey: .value)
        }
        enum CodingKeys: String, CodingKey { case value }
    }

    private struct IntWrapper: Decodable {
        let value: Int
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try container.decodeIntFlexible(forKey: .value)
        }
        enum CodingKeys: String, CodingKey { case value }
    }

    private struct OptionalIntWrapper: Decodable {
        let value: Int?
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try container.decodeIntFlexibleIfPresent(forKey: .value)
        }
        enum CodingKeys: String, CodingKey { case value }
    }

    private struct DoubleWrapper: Decodable {
        let value: Double
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try container.decodeDoubleFlexible(forKey: .value)
        }
        enum CodingKeys: String, CodingKey { case value }
    }

    // MARK: - decodeFlexibleString

    @Suite("decodeFlexibleString")
    struct StringDecodingTests {

        @Test(
            "JSON 표현 다양성을 모두 String으로 흡수한다 (숫자는 정수로 절삭)",
            arguments: [
                (#"{ "value": "abc" }"#,   "abc"),
                (#"{ "value": 42 }"#,      "42"),
                (#"{ "value": "42" }"#,    "42"),
                // ID/카운트 의미이므로 실수는 정수로 절삭한다: 3.14 → "3"
                (#"{ "value": 3.14 }"#,    "3")
            ]
        )
        func decodesVariousNumberShapes(json: String, expected: String) throws {
            let data = json.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(StringWrapper.self, from: data)
            #expect(decoded.value == expected)
        }

        @Test("키가 누락되면 throw한다")
        func throwsOnMissingKey() {
            let data = #"{}"#.data(using: .utf8)!
            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(StringWrapper.self, from: data)
            }
        }
    }

    // MARK: - decodeFlexibleStringIfPresent

    @Suite("decodeFlexibleStringIfPresent")
    struct OptionalStringDecodingTests {

        @Test("키 누락 → nil")
        func returnsNilWhenKeyMissing() throws {
            let data = #"{}"#.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(OptionalStringWrapper.self, from: data)
            #expect(decoded.value == nil)
        }

        @Test("명시적 null → nil")
        func returnsNilWhenExplicitNull() throws {
            let data = #"{ "value": null }"#.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(OptionalStringWrapper.self, from: data)
            #expect(decoded.value == nil)
        }

        @Test("정수 값 → \"123\"")
        func decodesIntAsString() throws {
            let data = #"{ "value": 123 }"#.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(OptionalStringWrapper.self, from: data)
            #expect(decoded.value == "123")
        }
    }

    // MARK: - decodeIntFlexible

    @Suite("decodeIntFlexible")
    struct IntDecodingTests {

        @Test(
            "Int / String-숫자 / Double 모두 Int로 흡수한다",
            arguments: [
                (#"{ "value": 42 }"#,      42),
                (#"{ "value": "42" }"#,    42),
                (#"{ "value": 3.7 }"#,     3)
            ]
        )
        func decodesVariousShapes(json: String, expected: Int) throws {
            let data = json.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(IntWrapper.self, from: data)
            #expect(decoded.value == expected)
        }

        @Test("Int로 변환 불가능한 String은 throw한다")
        func throwsOnNonNumericString() {
            let data = #"{ "value": "abc" }"#.data(using: .utf8)!
            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(IntWrapper.self, from: data)
            }
        }
    }

    // MARK: - decodeIntFlexibleIfPresent

    @Suite("decodeIntFlexibleIfPresent")
    struct OptionalIntDecodingTests {

        @Test("키 누락 → nil")
        func returnsNilWhenKeyMissing() throws {
            let data = #"{}"#.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(OptionalIntWrapper.self, from: data)
            #expect(decoded.value == nil)
        }

        @Test("null → nil")
        func returnsNilWhenExplicitNull() throws {
            let data = #"{ "value": null }"#.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(OptionalIntWrapper.self, from: data)
            #expect(decoded.value == nil)
        }

        @Test("String 정수 → Int")
        func decodesStringNumberAsInt() throws {
            let data = #"{ "value": "777" }"#.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(OptionalIntWrapper.self, from: data)
            #expect(decoded.value == 777)
        }

        @Test("숫자 형변환 불가한 String → nil")
        func returnsNilWhenStringNotNumeric() throws {
            let data = #"{ "value": "abc" }"#.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(OptionalIntWrapper.self, from: data)
            #expect(decoded.value == nil)
        }
    }

    // MARK: - decodeDoubleFlexible

    @Suite("decodeDoubleFlexible")
    struct DoubleDecodingTests {

        @Test(
            "Double / Int / String-숫자 모두 Double로 흡수한다",
            arguments: [
                (#"{ "value": 3.14 }"#,    3.14),
                (#"{ "value": 5 }"#,       5.0),
                (#"{ "value": "2.5" }"#,   2.5)
            ]
        )
        func decodesVariousShapes(json: String, expected: Double) throws {
            let data = json.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(DoubleWrapper.self, from: data)
            #expect(decoded.value == expected)
        }

        @Test("숫자 형변환 불가한 String은 throw한다")
        func throwsOnNonNumericString() {
            let data = #"{ "value": "abc" }"#.data(using: .utf8)!
            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(DoubleWrapper.self, from: data)
            }
        }
    }
}
