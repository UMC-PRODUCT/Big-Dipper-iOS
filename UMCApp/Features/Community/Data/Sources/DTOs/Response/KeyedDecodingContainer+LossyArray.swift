//
//  KeyedDecodingContainer+LossyArray.swift
//  CommunityData
//

import Foundation

extension KeyedDecodingContainer {

    /// 원소 하나가 깨져도 나머지를 살려서 배열을 디코딩합니다.
    ///
    /// `decodeIfPresent([Element].self, forKey:)` 는 원소 한 개만 throw 해도 상위 DTO 전체를
    /// 무너뜨린다. 메시지 50개 중 1개에 필수 필드가 빠지면 히스토리 페이지가 통째로 빈 화면이
    /// 되므로, 실패한 원소만 버리고 나머지를 반환한다.
    ///
    /// 키가 없거나 명시적 null 이면 빈 배열. 값이 배열이 **아니면** 기존대로 throw 한다.
    func decodeLossyArray<Element: Decodable>(
        _ type: Element.Type,
        forKey key: Key
    ) throws -> [Element] {
        guard contains(key), try !decodeNil(forKey: key) else { return [] }

        var unkeyedContainer = try nestedUnkeyedContainer(forKey: key)
        var elements: [Element] = []
        if let count = unkeyedContainer.count {
            elements.reserveCapacity(count)
        }

        while !unkeyedContainer.isAtEnd {
            // LossyElement 는 throw 하지 않으므로 실패한 원소에서도 인덱스가 전진한다.
            let element = try unkeyedContainer.decode(LossyElement<Element>.self)
            if let value = element.value {
                elements.append(value)
            }
        }

        return elements
    }
}

private struct LossyElement<Element: Decodable>: Decodable {

    // MARK: - Property

    let value: Element?

    // MARK: - Codable

    init(from decoder: Decoder) throws {
        do {
            self.value = try Element(from: decoder)
        } catch {
            #if DEBUG
            print("[CommunityData] dropped \(Element.self) at \(decoder.codingPath) error=\(error)")
            #endif
            self.value = nil
        }
    }
}
