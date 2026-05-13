//
//  WorkbookSubmissionDetailDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 2/18/26.
//

import Foundation

/// 챌린저 워크북 제출 URL 조회 응답 DTO
///
/// `GET /api/v2/curriculums/challenger-workbooks/{challengerWorkbookId}`
struct WorkbookSubmissionDetailDTO: Codable, Sendable, Equatable {
    let challengerWorkbookId: Int
    let submission: String?

    private enum CodingKeys: String, CodingKey {
        case challengerWorkbookId
        case submission
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        challengerWorkbookId = try container.decodeIntFlexibleIfPresent(forKey: .challengerWorkbookId) ?? 0
        submission = try container.decodeIfPresent(String.self, forKey: .submission)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(challengerWorkbookId, forKey: .challengerWorkbookId)
        try container.encodeIfPresent(submission, forKey: .submission)
    }
}

private extension KeyedDecodingContainer {
    func decodeIntFlexible(forKey key: Key) throws -> Int {
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }
        if let value = try? decode(String.self, forKey: key),
           let intValue = Int(value) {
            return intValue
        }
        if let value = try? decode(Double.self, forKey: key) {
            return Int(value)
        }
        throw DecodingError.typeMismatch(
            Int.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Expected Int/String-number/Double for key '\(key.stringValue)'"
            )
        )
    }

    func decodeIntFlexibleIfPresent(forKey key: Key) throws -> Int? {
        if (try? decodeNil(forKey: key)) == true {
            return nil
        }
        return try? decodeIntFlexible(forKey: key)
    }
}
