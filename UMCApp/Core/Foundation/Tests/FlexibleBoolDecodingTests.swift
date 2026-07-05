//
//  FlexibleBoolDecodingTests.swift
//  UMCFoundationTests
//
//  Created by euijjang97 on 7/5/26.
//

import Foundation
import Testing
@testable import UMCFoundation

@Suite("KeyedDecodingContainer.decodeBoolFlexibleIfPresent")
struct FlexibleBoolDecodingTests {

    private struct Probe: Decodable {
        let value: Bool?

        enum CodingKeys: String, CodingKey { case value }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try container.decodeBoolFlexibleIfPresent(forKey: .value)
        }
    }

    private func decode(_ json: String) throws -> Bool? {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(Probe.self, from: data).value
    }

    @Test("JSON Bool 값을 그대로 디코딩한다")
    func nativeBool() throws {
        #expect(try decode(#"{"value": true}"#) == true)
        #expect(try decode(#"{"value": false}"#) == false)
    }

    @Test("Int 0/1 을 Bool 로 변환한다")
    func intToBool() throws {
        #expect(try decode(#"{"value": 1}"#) == true)
        #expect(try decode(#"{"value": 0}"#) == false)
        #expect(try decode(#"{"value": 3}"#) == true)
    }

    @Test("String \"true\"/\"false\"/\"1\"/\"0\" 을 Bool 로 변환한다")
    func stringToBool() throws {
        #expect(try decode(#"{"value": "true"}"#) == true)
        #expect(try decode(#"{"value": "false"}"#) == false)
        #expect(try decode(#"{"value": "1"}"#) == true)
        #expect(try decode(#"{"value": "0"}"#) == false)
        #expect(try decode(#"{"value": "TRUE"}"#) == true)
    }

    @Test("키 누락 / 명시적 null / 해석 불가 값은 nil")
    func nilCases() throws {
        #expect(try decode(#"{}"#) == nil)
        #expect(try decode(#"{"value": null}"#) == nil)
        #expect(try decode(#"{"value": "maybe"}"#) == nil)
    }
}
