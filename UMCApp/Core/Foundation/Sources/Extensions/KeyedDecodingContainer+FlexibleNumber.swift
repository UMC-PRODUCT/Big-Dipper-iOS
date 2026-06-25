//
//  KeyedDecodingContainer+FlexibleNumber.swift
//  UMCFoundation
//
//  서버가 정수/실수를 String 또는 Number 어느 쪽으로든 직렬화할 수 있어
//  Response DTO 디코딩 시 양쪽을 모두 흡수하기 위한 공용 헬퍼.
//

import Foundation

public extension KeyedDecodingContainer {

    // MARK: - String

    /// JSON 숫자/문자열 숫자 모두 허용하여 `String`으로 디코딩합니다.
    func decodeFlexibleString(forKey key: Key) throws -> String {
        if let stringValue = try? decode(String.self, forKey: key) {
            return stringValue
        }

        if let intValue = try? decode(Int.self, forKey: key) {
            return String(intValue)
        }

        if let doubleValue = try? decode(Double.self, forKey: key) {
            return String(doubleValue)
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Expected String or numeric value for \(key.stringValue)"
        )
    }

    /// JSON 숫자/문자열 숫자 모두 허용하여 Optional `String`으로 디코딩합니다.
    func decodeFlexibleStringIfPresent(forKey key: Key) throws -> String? {
        guard contains(key) else { return nil }
        if try decodeNil(forKey: key) { return nil }
        return try decodeFlexibleString(forKey: key)
    }

    // MARK: - Int

    /// JSON 숫자/문자열 숫자 모두 허용하여 `Int`로 디코딩합니다.
    func decodeFlexibleInt(forKey key: Key) throws -> Int {
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

    /// JSON 숫자/문자열 숫자 모두 허용하여 Optional `Int`로 디코딩합니다.
    func decodeFlexibleIntIfPresent(forKey key: Key) throws -> Int? {
        guard contains(key) else { return nil }
        if try decodeNil(forKey: key) { return nil }

        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue
        }

        if let stringValue = try? decode(String.self, forKey: key) {
            return Int(stringValue)
        }

        if let doubleValue = try? decode(Double.self, forKey: key) {
            return Int(doubleValue)
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Expected Optional Int or String-convertible Int for \(key.stringValue)"
        )
    }

    // MARK: - Double

    /// JSON 숫자/문자열 숫자 모두 허용하여 `Double`로 디코딩합니다.
    func decodeFlexibleDouble(forKey key: Key) throws -> Double {
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
    func decodeFlexibleDoubleIfPresent(forKey key: Key) throws -> Double? {
        guard contains(key) else { return nil }
        if try decodeNil(forKey: key) { return nil }
        return try decodeFlexibleDouble(forKey: key)
    }
}
