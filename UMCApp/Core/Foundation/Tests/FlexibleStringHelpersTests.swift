//
//  FlexibleStringHelpersTests.swift
//  UMCFoundationTests
//
//  Created by euijjang97 on 7/5/26.
//
//  swallow/유틸리티 계열 헬퍼(OrNil/OrEmpty/Array/FirstNonEmpty) 커버리지.
//

import Foundation
import Testing
@testable import UMCFoundation

@Suite("KeyedDecodingContainer — Flexible String swallow/유틸 헬퍼")
struct FlexibleStringHelpersTests {

    private struct Probe: Decodable {
        let orNil: String?
        let orEmpty: String
        let array: [String]
        let firstNonEmpty: String?

        enum CodingKeys: String, CodingKey {
            case value, values, a, b
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            orNil = container.decodeFlexibleStringOrNil(forKey: .value)
            orEmpty = container.decodeFlexibleStringOrEmpty(forKey: .value)
            array = container.decodeFlexibleStringArray(forKey: .values)
            firstNonEmpty = container.decodeFirstNonEmptyString(forKeys: [.a, .b])
        }
    }

    private func probe(_ json: String) throws -> Probe {
        try JSONDecoder().decode(Probe.self, from: Data(json.utf8))
    }

    // MARK: - OrNil / OrEmpty (숫자는 정수로 절삭, 실패는 swallow)

    @Test("숫자를 정수로 절삭해 문자열화한다")
    func truncatesNumber() throws {
        let p = try probe(#"{ "value": 1.9, "values": [], "a": "", "b": "" }"#)
        #expect(p.orNil == "1")
        #expect(p.orEmpty == "1")
    }

    @Test("키 누락/null 은 OrNil→nil, OrEmpty→\"\"")
    func missingSwallows() throws {
        let p = try probe(#"{ "values": [], "a": "", "b": "" }"#)
        #expect(p.orNil == nil)
        #expect(p.orEmpty == "")
    }

    @Test("해석 불가 타입은 조용히 swallow (throw 하지 않음)")
    func badTypeSwallows() throws {
        let p = try probe(#"{ "value": {"nested": 1}, "values": [], "a": "", "b": "" }"#)
        #expect(p.orNil == nil)
        #expect(p.orEmpty == "")
    }

    // MARK: - Array

    @Test("[String] / [Int] 을 모두 [String] 으로 흡수하고, 실패는 []")
    func arrayFlexible() throws {
        #expect(try probe(#"{ "values": ["a","b"], "a":"", "b":"" }"#).array == ["a", "b"])
        #expect(try probe(#"{ "values": [1,2,3], "a":"", "b":"" }"#).array == ["1", "2", "3"])
        #expect(try probe(#"{ "values": "oops", "a":"", "b":"" }"#).array == [])
        #expect(try probe(#"{ "a":"", "b":"" }"#).array == [])
    }

    // MARK: - FirstNonEmpty

    @Test("여러 키 중 공백 제거 후 처음으로 비어있지 않은 값을 반환한다")
    func firstNonEmpty() throws {
        #expect(try probe(#"{ "values": [], "a": "  ", "b": "found" }"#).firstNonEmpty == "found")
        #expect(try probe(#"{ "values": [], "a": "first", "b": "second" }"#).firstNonEmpty == "first")
        #expect(try probe(#"{ "values": [], "a": "", "b": "" }"#).firstNonEmpty == nil)
    }
}
