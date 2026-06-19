//
//  KeyedDecodingContainer+FlexibleDecoding.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/7/26.
//

import Foundation

/// 서버가 같은 필드를 Int / String / Double / Bool 등 혼합 타입으로 직렬화하는 상황을
/// 흡수하기 위한 유연 디코딩 헬퍼.
///
/// 절대 규칙 2(서버 응답 정수 → 전 레이어 `String`)와 규칙 3(Response DTO 의 정수 필드는
/// `decode(Int.self)` 직접 호출 금지)을 동시에 만족시키기 위해, 식별자/커서류는
/// `decodeFlexibleString*` 으로, 실제 수량(개수·점수)은 `decodeIntFlexible*` 로 디코딩한다.
///
/// ActivityData 모듈 내부 전용(`internal`)이며, DTO 파일들이 공유한다.
extension KeyedDecodingContainer {

    // MARK: - String

    /// 식별자/커서처럼 서버가 Int 또는 String 으로 보낼 수 있는 값을 `String` 으로 디코딩한다.
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

        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription:
                    "Expected String/Int/Double for key '\(key.stringValue)'"
            )
        )
    }

    /// 키가 nil 이거나 변환 불가하면 nil 을 반환하는 ``decodeFlexibleString(forKey:)`` 의 Optional 버전.
    ///
    /// - Important: 필드 누락과 타입 불일치를 모두 `nil` 로 동일하게 처리한다.
    ///   `decodeNil` 선검사 후 `try?` 로 변환을 시도하므로, 키가 존재해도 변환 불가능한
    ///   타입(`Bool`·배열 등)이 오면 오류를 던지지 않고 조용히 `nil` 로 폴백한다.
    func decodeFlexibleStringIfPresent(forKey key: Key) throws -> String? {
        if (try? decodeNil(forKey: key)) == true {
            return nil
        }
        return try? decodeFlexibleString(forKey: key)
    }

    // MARK: - Int

    /// 실제 수량(개수·점수 등)을 Int / String / Double 형태로부터 유연하게 디코딩한다.
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

        throw DecodingError.typeMismatch(
            Int.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription:
                    "Expected Int/String-number/Double for key '\(key.stringValue)'"
            )
        )
    }

    /// 키가 nil 이거나 변환 불가하면 nil 을 반환하는 ``decodeIntFlexible(forKey:)`` 의 Optional 버전.
    func decodeIntFlexibleIfPresent(forKey key: Key) throws -> Int? {
        if (try? decodeNil(forKey: key)) == true {
            return nil
        }
        return try? decodeIntFlexible(forKey: key)
    }

    // MARK: - Bool

    /// Bool / Int(0·1) / String("true"·"false"·"1"·"0") 형태로부터 Bool 을 유연하게 디코딩한다.
    func decodeBoolFlexibleIfPresent(forKey key: Key) throws -> Bool? {
        if (try? decodeNil(forKey: key)) == true {
            return nil
        }
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

    // MARK: - Double

    /// Double / Int / String 형태로부터 Double 을 유연하게 디코딩한다.
    func decodeDoubleFlexibleIfPresent(forKey key: Key) throws -> Double? {
        if (try? decodeNil(forKey: key)) == true {
            return nil
        }
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
        return nil
    }
}
