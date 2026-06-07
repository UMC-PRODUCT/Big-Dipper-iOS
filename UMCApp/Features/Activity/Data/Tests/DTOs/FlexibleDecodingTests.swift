//
//  FlexibleDecodingTests.swift
//  ActivityDataTests
//
//  Created by jaewon Lee on 6/7/26.
//

import Foundation
import Testing
@testable import ActivityData

// MARK: - Test Probe DTOs
//
// KeyedDecodingContainer 의 flexible 헬퍼는 internal extension 이라 직접 호출이 불가능하다.
// 각 헬퍼를 정확히 한 번씩 호출하는 최소 프로브 DTO 를 통해 헬퍼의 분기를 검증한다.

private struct FlexibleStringProbe: Decodable {
    let value: String

    private enum CodingKeys: String, CodingKey { case value }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decodeFlexibleString(forKey: .value)
    }
}

private struct FlexibleStringIfPresentProbe: Decodable {
    let value: String?

    private enum CodingKeys: String, CodingKey { case value }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decodeFlexibleStringIfPresent(forKey: .value)
    }
}

private struct FlexibleIntProbe: Decodable {
    let value: Int

    private enum CodingKeys: String, CodingKey { case value }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decodeIntFlexible(forKey: .value)
    }
}

private struct FlexibleIntIfPresentProbe: Decodable {
    let value: Int?

    private enum CodingKeys: String, CodingKey { case value }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decodeIntFlexibleIfPresent(forKey: .value)
    }
}

private struct FlexibleBoolIfPresentProbe: Decodable {
    let value: Bool?

    private enum CodingKeys: String, CodingKey { case value }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decodeBoolFlexibleIfPresent(forKey: .value)
    }
}

private struct FlexibleDoubleIfPresentProbe: Decodable {
    let value: Double?

    private enum CodingKeys: String, CodingKey { case value }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decodeDoubleFlexibleIfPresent(forKey: .value)
    }
}

// MARK: - Helpers

private func decodeStringProbe(_ json: String) throws -> FlexibleStringProbe {
    try JSONDecoder().decode(FlexibleStringProbe.self, from: Data(json.utf8))
}

private func decodeStringIfPresentProbe(_ json: String) throws -> FlexibleStringIfPresentProbe {
    try JSONDecoder().decode(FlexibleStringIfPresentProbe.self, from: Data(json.utf8))
}

private func decodeIntProbe(_ json: String) throws -> FlexibleIntProbe {
    try JSONDecoder().decode(FlexibleIntProbe.self, from: Data(json.utf8))
}

private func decodeIntIfPresentProbe(_ json: String) throws -> FlexibleIntIfPresentProbe {
    try JSONDecoder().decode(FlexibleIntIfPresentProbe.self, from: Data(json.utf8))
}

private func decodeBoolIfPresentProbe(_ json: String) throws -> FlexibleBoolIfPresentProbe {
    try JSONDecoder().decode(FlexibleBoolIfPresentProbe.self, from: Data(json.utf8))
}

private func decodeDoubleIfPresentProbe(_ json: String) throws -> FlexibleDoubleIfPresentProbe {
    try JSONDecoder().decode(FlexibleDoubleIfPresentProbe.self, from: Data(json.utf8))
}

@Suite("KeyedDecodingContainer FlexibleDecoding — 유연 디코딩 헬퍼")
struct FlexibleDecodingTests {

    // MARK: - decodeFlexibleString

    @Test("decodeFlexibleString — JSON String 값을 그대로 String 으로 디코딩한다")
    func flexibleStringDecodesStringValue() throws {
        let probe = try decodeStringProbe(#"{ "value": "abc" }"#)
        #expect(probe.value == "abc")
    }

    @Test("decodeFlexibleString — JSON Int 값을 String 으로 변환한다")
    func flexibleStringDecodesIntValue() throws {
        let probe = try decodeStringProbe(#"{ "value": 42 }"#)
        #expect(probe.value == "42")
    }

    @Test("decodeFlexibleString — JSON Double 값을 절삭한 Int 의 String 으로 변환한다")
    func flexibleStringDecodesDoubleValue() throws {
        let probe = try decodeStringProbe(#"{ "value": 42.9 }"#)
        #expect(probe.value == "42")
    }

    @Test("decodeFlexibleString — Bool 등 변환 불가 타입이면 typeMismatch 를 throw 한다")
    func flexibleStringThrowsOnInvalidType() {
        #expect(throws: DecodingError.self) {
            _ = try decodeStringProbe(#"{ "value": true }"#)
        }
    }

    // MARK: - decodeFlexibleStringIfPresent

    @Test("decodeFlexibleStringIfPresent — String 값을 디코딩한다")
    func flexibleStringIfPresentDecodesString() throws {
        let probe = try decodeStringIfPresentProbe(#"{ "value": "cursor-1" }"#)
        #expect(probe.value == "cursor-1")
    }

    @Test("decodeFlexibleStringIfPresent — Int 값을 String 으로 변환한다")
    func flexibleStringIfPresentDecodesInt() throws {
        let probe = try decodeStringIfPresentProbe(#"{ "value": 7 }"#)
        #expect(probe.value == "7")
    }

    @Test("decodeFlexibleStringIfPresent — 키가 없으면 nil 을 반환한다")
    func flexibleStringIfPresentReturnsNilWhenMissing() throws {
        let probe = try decodeStringIfPresentProbe(#"{ }"#)
        #expect(probe.value == nil)
    }

    @Test("decodeFlexibleStringIfPresent — 명시적 null 이면 nil 을 반환한다")
    func flexibleStringIfPresentReturnsNilWhenNull() throws {
        let probe = try decodeStringIfPresentProbe(#"{ "value": null }"#)
        #expect(probe.value == nil)
    }

    @Test("decodeFlexibleStringIfPresent — 변환 불가 타입이면 nil 을 반환한다 (throw 하지 않음)")
    func flexibleStringIfPresentReturnsNilOnInvalidType() throws {
        let probe = try decodeStringIfPresentProbe(#"{ "value": true }"#)
        #expect(probe.value == nil)
    }

    // MARK: - decodeIntFlexible

    @Test("decodeIntFlexible — JSON Int 값을 그대로 디코딩한다")
    func intFlexibleDecodesInt() throws {
        let probe = try decodeIntProbe(#"{ "value": 5 }"#)
        #expect(probe.value == 5)
    }

    @Test("decodeIntFlexible — 숫자 String 을 Int 로 변환한다")
    func intFlexibleDecodesNumericString() throws {
        let probe = try decodeIntProbe(#"{ "value": "12" }"#)
        #expect(probe.value == 12)
    }

    @Test("decodeIntFlexible — JSON Double 을 절삭해 Int 로 변환한다")
    func intFlexibleDecodesDouble() throws {
        let probe = try decodeIntProbe(#"{ "value": 8.7 }"#)
        #expect(probe.value == 8)
    }

    @Test("decodeIntFlexible — 숫자가 아닌 String 이면 typeMismatch 를 throw 한다")
    func intFlexibleThrowsOnNonNumericString() {
        #expect(throws: DecodingError.self) {
            _ = try decodeIntProbe(#"{ "value": "not-a-number" }"#)
        }
    }

    @Test("decodeIntFlexible — Bool 등 변환 불가 타입이면 typeMismatch 를 throw 한다")
    func intFlexibleThrowsOnInvalidType() {
        #expect(throws: DecodingError.self) {
            _ = try decodeIntProbe(#"{ "value": true }"#)
        }
    }

    // MARK: - decodeIntFlexibleIfPresent

    @Test("decodeIntFlexibleIfPresent — Int 값을 디코딩한다")
    func intFlexibleIfPresentDecodesInt() throws {
        let probe = try decodeIntIfPresentProbe(#"{ "value": 3 }"#)
        #expect(probe.value == 3)
    }

    @Test("decodeIntFlexibleIfPresent — 숫자 String 을 Int 로 변환한다")
    func intFlexibleIfPresentDecodesNumericString() throws {
        let probe = try decodeIntIfPresentProbe(#"{ "value": "99" }"#)
        #expect(probe.value == 99)
    }

    @Test("decodeIntFlexibleIfPresent — 키가 없으면 nil 을 반환한다")
    func intFlexibleIfPresentReturnsNilWhenMissing() throws {
        let probe = try decodeIntIfPresentProbe(#"{ }"#)
        #expect(probe.value == nil)
    }

    @Test("decodeIntFlexibleIfPresent — 명시적 null 이면 nil 을 반환한다")
    func intFlexibleIfPresentReturnsNilWhenNull() throws {
        let probe = try decodeIntIfPresentProbe(#"{ "value": null }"#)
        #expect(probe.value == nil)
    }

    @Test("decodeIntFlexibleIfPresent — 숫자가 아닌 String 이면 nil 을 반환한다 (throw 하지 않음)")
    func intFlexibleIfPresentReturnsNilOnNonNumericString() throws {
        let probe = try decodeIntIfPresentProbe(#"{ "value": "abc" }"#)
        #expect(probe.value == nil)
    }

    // MARK: - decodeBoolFlexibleIfPresent

    @Test("decodeBoolFlexibleIfPresent — JSON Bool 값을 디코딩한다")
    func boolFlexibleIfPresentDecodesBool() throws {
        #expect(try decodeBoolIfPresentProbe(#"{ "value": true }"#).value == true)
        #expect(try decodeBoolIfPresentProbe(#"{ "value": false }"#).value == false)
    }

    @Test(
        "decodeBoolFlexibleIfPresent — Int 0 은 false, 그 외 Int 는 true 로 변환한다",
        arguments: [
            (#"{ "value": 0 }"#, false),
            (#"{ "value": 1 }"#, true),
            (#"{ "value": 5 }"#, true)
        ]
    )
    func boolFlexibleIfPresentDecodesInt(json: String, expected: Bool) throws {
        #expect(try decodeBoolIfPresentProbe(json).value == expected)
    }

    @Test(
        "decodeBoolFlexibleIfPresent — String true/false/1/0 을 Bool 로 변환한다",
        arguments: [
            (#"{ "value": "true" }"#, true),
            (#"{ "value": "TRUE" }"#, true),
            (#"{ "value": "1" }"#, true),
            (#"{ "value": "false" }"#, false),
            (#"{ "value": "0" }"#, false)
        ]
    )
    func boolFlexibleIfPresentDecodesString(json: String, expected: Bool) throws {
        #expect(try decodeBoolIfPresentProbe(json).value == expected)
    }

    @Test("decodeBoolFlexibleIfPresent — 인식 불가 String 이면 nil 을 반환한다")
    func boolFlexibleIfPresentReturnsNilOnUnknownString() throws {
        let probe = try decodeBoolIfPresentProbe(#"{ "value": "maybe" }"#)
        #expect(probe.value == nil)
    }

    @Test("decodeBoolFlexibleIfPresent — 키가 없으면 nil 을 반환한다")
    func boolFlexibleIfPresentReturnsNilWhenMissing() throws {
        let probe = try decodeBoolIfPresentProbe(#"{ }"#)
        #expect(probe.value == nil)
    }

    @Test("decodeBoolFlexibleIfPresent — 명시적 null 이면 nil 을 반환한다")
    func boolFlexibleIfPresentReturnsNilWhenNull() throws {
        let probe = try decodeBoolIfPresentProbe(#"{ "value": null }"#)
        #expect(probe.value == nil)
    }

    @Test("decodeBoolFlexibleIfPresent — Double 등 처리 불가 타입이면 nil 을 반환한다")
    func boolFlexibleIfPresentReturnsNilOnUnhandledType() throws {
        let probe = try decodeBoolIfPresentProbe(#"{ "value": 1.5 }"#)
        #expect(probe.value == nil)
    }

    // MARK: - decodeDoubleFlexibleIfPresent

    @Test("decodeDoubleFlexibleIfPresent — JSON Double 값을 디코딩한다")
    func doubleFlexibleIfPresentDecodesDouble() throws {
        let probe = try decodeDoubleIfPresentProbe(#"{ "value": 3.14 }"#)
        #expect(probe.value == 3.14)
    }

    @Test("decodeDoubleFlexibleIfPresent — JSON Int 를 Double 로 변환한다")
    func doubleFlexibleIfPresentDecodesInt() throws {
        let probe = try decodeDoubleIfPresentProbe(#"{ "value": 4 }"#)
        #expect(probe.value == 4.0)
    }

    @Test("decodeDoubleFlexibleIfPresent — 숫자 String 을 Double 로 변환한다")
    func doubleFlexibleIfPresentDecodesNumericString() throws {
        let probe = try decodeDoubleIfPresentProbe(#"{ "value": "2.5" }"#)
        #expect(probe.value == 2.5)
    }

    @Test("decodeDoubleFlexibleIfPresent — 숫자가 아닌 String 이면 nil 을 반환한다")
    func doubleFlexibleIfPresentReturnsNilOnNonNumericString() throws {
        let probe = try decodeDoubleIfPresentProbe(#"{ "value": "x" }"#)
        #expect(probe.value == nil)
    }

    @Test("decodeDoubleFlexibleIfPresent — 키가 없으면 nil 을 반환한다")
    func doubleFlexibleIfPresentReturnsNilWhenMissing() throws {
        let probe = try decodeDoubleIfPresentProbe(#"{ }"#)
        #expect(probe.value == nil)
    }

    @Test("decodeDoubleFlexibleIfPresent — 명시적 null 이면 nil 을 반환한다")
    func doubleFlexibleIfPresentReturnsNilWhenNull() throws {
        let probe = try decodeDoubleIfPresentProbe(#"{ "value": null }"#)
        #expect(probe.value == nil)
    }

    @Test("decodeDoubleFlexibleIfPresent — Bool 등 처리 불가 타입이면 nil 을 반환한다")
    func doubleFlexibleIfPresentReturnsNilOnUnhandledType() throws {
        let probe = try decodeDoubleIfPresentProbe(#"{ "value": true }"#)
        #expect(probe.value == nil)
    }
}
