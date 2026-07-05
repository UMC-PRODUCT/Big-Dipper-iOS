//
//  KeyedDecodingContainer+FlexibleNumber.swift
//  UMCFoundation
//
//  서버가 정수/실수/불리언을 String 또는 Number 어느 쪽으로든 직렬화할 수 있어
//  Response DTO 디코딩 시 양쪽을 모두 흡수하기 위한 공용 헬퍼.
//
//  네이밍 규약(CLAUDE.md 절대 규칙 #3):
//  - 식별자/커서류(서버가 정수 또는 문자열) → `decodeFlexibleString*`
//  - 실제 수량(개수·점수) → `decodeIntFlexible*`
//  숫자를 String으로 흡수할 때는 **정수로 절삭**합니다(ID/카운트는 정수 의미이므로 "1.0"이 아닌 "1").
//

import Foundation

public extension KeyedDecodingContainer {

    // MARK: - String (throws)

    /// JSON 문자열/정수/실수를 모두 허용해 `String`으로 디코딩합니다. 숫자는 정수로 절삭됩니다.
    ///
    /// - Throws: 값이 없거나 String/Int/Double 어느 쪽으로도 해석할 수 없으면 `DecodingError`.
    func decodeFlexibleString(forKey key: Key) throws -> String {
        if let stringValue = try? decode(String.self, forKey: key) {
            return stringValue
        }
        if let intValue = try? decode(Int.self, forKey: key) {
            return String(intValue)
        }
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return String(Int(doubleValue))
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Expected String or numeric value for \(key.stringValue)"
        )
    }

    /// 키가 없거나 명시적 null이면 `nil`, 값이 있으면 ``decodeFlexibleString(forKey:)``.
    ///
    /// - Important: 키가 존재하지만 해석 불가한 타입이면 **throw**합니다.
    ///   실패를 조용히 흡수하려면 ``decodeFlexibleStringOrNil(forKey:)``를 사용하세요.
    func decodeFlexibleStringIfPresent(forKey key: Key) throws -> String? {
        guard contains(key) else { return nil }
        if try decodeNil(forKey: key) { return nil }
        return try decodeFlexibleString(forKey: key)
    }

    // MARK: - String (non-throwing / swallow)

    /// String/Int/Double 중 하나로 디코딩하고, 실패하면 조용히 `nil`을 반환합니다.
    ///
    /// 명시적 null·키 누락·해석 불가 타입을 모두 `nil`로 동일하게 처리합니다.
    func decodeFlexibleStringOrNil(forKey key: Key) -> String? {
        (try? decodeNil(forKey: key)) == true ? nil : try? decodeFlexibleString(forKey: key)
    }

    /// String/Int/Double 중 하나로 디코딩하고, 실패하면 빈 문자열을 반환합니다.
    func decodeFlexibleStringOrEmpty(forKey key: Key) -> String {
        decodeFlexibleStringOrNil(forKey: key) ?? ""
    }

    /// `[String]` 또는 `[Int]`를 모두 `[String]`으로 디코딩합니다. 실패하면 빈 배열.
    func decodeFlexibleStringArray(forKey key: Key) -> [String] {
        if let values = try? decode([String].self, forKey: key) {
            return values
        }
        if let values = try? decode([Int].self, forKey: key) {
            return values.map(String.init)
        }
        return []
    }

    /// 주어진 키들을 순서대로 조회해 처음으로 나오는, 공백 제거 후 비어 있지 않은 문자열을 반환합니다.
    func decodeFirstNonEmptyString(forKeys keys: [Key]) -> String? {
        for key in keys {
            guard let rawValue = decodeFlexibleStringOrNil(forKey: key) else { continue }
            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                return trimmed
            }
        }
        return nil
    }

    // MARK: - Int

    /// JSON 숫자/문자열 숫자 모두 허용하여 `Int`로 디코딩합니다.
    func decodeIntFlexible(forKey key: Key) throws -> Int {
        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? decode(String.self, forKey: key),
           let intValue = Int(stringValue) {
            return intValue
        }
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return Int(doubleValue)
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Expected Int or String-convertible Int for \(key.stringValue)"
        )
    }

    /// 키가 없거나 명시적 null이면 `nil`, 값이 있으면 ``decodeIntFlexible(forKey:)``.
    ///
    /// - Important: 키가 존재하지만 숫자로 해석 불가하면 **throw**합니다.
    ///   (오염된 count/id를 조용히 누락으로 처리하지 않도록 fail-loud — 다른 `*IfPresent`와 동일 규약)
    func decodeIntFlexibleIfPresent(forKey key: Key) throws -> Int? {
        guard contains(key) else { return nil }
        if try decodeNil(forKey: key) { return nil }
        return try decodeIntFlexible(forKey: key)
    }

    // MARK: - Double

    /// JSON 숫자/문자열 숫자 모두 허용하여 `Double`로 디코딩합니다.
    func decodeDoubleFlexible(forKey key: Key) throws -> Double {
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return doubleValue
        }
        if let intValue = try? decode(Int.self, forKey: key) {
            return Double(intValue)
        }
        if let stringValue = try? decode(String.self, forKey: key),
           let doubleValue = Double(stringValue) {
            return doubleValue
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Expected Double or String-convertible Double for \(key.stringValue)"
        )
    }

    /// JSON 숫자/문자열 숫자 모두 허용하여 Optional `Double`로 디코딩합니다.
    func decodeDoubleFlexibleIfPresent(forKey key: Key) throws -> Double? {
        guard contains(key) else { return nil }
        if try decodeNil(forKey: key) { return nil }
        return try decodeDoubleFlexible(forKey: key)
    }

    // MARK: - Bool

    /// JSON Bool / Int(0·1) / String("true"·"false"·"1"·"0") 모두 허용하여 Optional `Bool`로 디코딩합니다.
    ///
    /// 키가 없거나 명시적 null, 혹은 해석 불가한 값이면 `nil`을 반환합니다.
    func decodeBoolFlexibleIfPresent(forKey key: Key) throws -> Bool? {
        guard contains(key) else { return nil }
        if try decodeNil(forKey: key) { return nil }

        if let boolValue = try? decode(Bool.self, forKey: key) {
            return boolValue
        }
        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue != 0
        }
        if let stringValue = try? decode(String.self, forKey: key) {
            switch stringValue.lowercased() {
            case "true", "1":
                return true
            case "false", "0":
                return false
            default:
                return nil
            }
        }

        return nil
    }
}
