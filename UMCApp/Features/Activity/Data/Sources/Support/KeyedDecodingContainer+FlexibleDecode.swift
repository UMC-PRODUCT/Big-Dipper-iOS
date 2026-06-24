//
//  KeyedDecodingContainer+FlexibleDecode.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/10/26.
//

import Foundation

/// 서버 응답이 동일 필드를 숫자/문자열로 번갈아 직렬화하는 경우를 흡수하는 유연 디코딩 헬퍼.
///
/// 서버는 모든 정수를 문자열로 내려주는 것을 원칙으로 하지만, 필드에 따라 숫자 그대로
/// 내려오는 사례가 섞여 있습니다. Response DTO 가 단일 타입(`decode(String.self)` 등)으로
/// 강제 디코딩하면 그 순간 전체 응답 파싱이 깨지므로, 식별자(String) · 좌표(Double) 는
/// 아래 헬퍼로 가능한 표현을 모두 시도해 디코딩 실패를 방지합니다.
///
/// - Note: ActivityData 모듈 내부 Response DTO 전용입니다. 두 번째 Feature 가 동일 헬퍼를
///   필요로 하면 Core 로 승격합니다.
extension KeyedDecodingContainer {

    // TODO: 2번째 Feature 가 동일 헬퍼를 요구하면 Core 모듈로 승격 (그 전까진 모듈-internal 유지) - [26.06.19] 이재원

    // MARK: - String (서버 식별자)

    /// 식별자 필드를 `String` 으로 유연 디코딩합니다.
    ///
    /// 서버가 ID 를 문자열(`"42"`)로 주는 게 원칙이지만, 숫자(`42`)로 내려오는 경우도
    /// 문자열로 정규화합니다. 전 레이어 식별자 String 통일(절대규칙 #2)을 위해 Int 보관을
    /// 거치지 않고 곧바로 String 으로 받습니다.
    func decodeStringFlexible(forKey key: Key) throws -> String {
        if let value = try? decode(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Double.self, forKey: key) {
            // 정수 식별자가 Double 로 내려온 경우 소수점 손실 없이 정수 문자열로 환원
            return String(Int(value))
        }
        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Expected String/Int/Double for key '\(key.stringValue)'"
            )
        )
    }

    /// 키가 없거나 `null` 이면 `nil`, 존재하면 ``decodeStringFlexible(forKey:)`` 적용.
    func decodeStringFlexibleIfPresent(forKey key: Key) throws -> String? {
        if (try? decodeNil(forKey: key)) == true {
            return nil
        }
        return try? decodeStringFlexible(forKey: key)
    }

    // MARK: - Double (좌표)

    /// 좌표 필드를 `Double` 로 유연 디코딩합니다 (Double/문자열-숫자/Int 순서로 시도).
    func decodeDoubleFlexible(forKey key: Key) throws -> Double {
        if let value = try? decode(Double.self, forKey: key) {
            return value
        }
        if let value = try? decode(String.self, forKey: key),
           let doubleValue = Double(value) {
            return doubleValue
        }
        if let value = try? decode(Int.self, forKey: key) {
            return Double(value)
        }
        throw DecodingError.typeMismatch(
            Double.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Expected Double/String-number/Int for key '\(key.stringValue)'"
            )
        )
    }

    /// 키가 없거나 `null` 이면 `nil`, 존재하면 ``decodeDoubleFlexible(forKey:)`` 적용.
    func decodeDoubleFlexibleIfPresent(forKey key: Key) throws -> Double? {
        if (try? decodeNil(forKey: key)) == true {
            return nil
        }
        return try? decodeDoubleFlexible(forKey: key)
    }
}
