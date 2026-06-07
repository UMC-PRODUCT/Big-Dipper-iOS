//
//  VoteDTO.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation
import NoticeDomain

// MARK: - 투표 추가 Request DTO

/// 공지사항 투표 추가 요청 DTO
public struct AddVoteRequestDTO: Encodable {
    public let title: String
    public let isAnonymous: Bool
    public let allowMultipleChoice: Bool
    public let startsAt: String
    public let endsAtExclusive: String
    public let options: [String]
}

// MARK: - 투표 추가 Response DTO

/// 공지사항 투표 추가 응답 DTO
public struct AddVoteResponseDTO: Codable {
    public let noticeVoteId: String
    public let voteId: String

    private enum CodingKeys: String, CodingKey {
        case noticeVoteId
        case voteId
    }

    /// noticeVoteId, voteId가 String 또는 Int로 올 수 있어 유연하게 디코딩
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let value = try? container.decode(String.self, forKey: .noticeVoteId) {
            self.noticeVoteId = value
        } else if let value = try? container.decode(Int.self, forKey: .noticeVoteId) {
            self.noticeVoteId = String(value)
        } else {
            self.noticeVoteId = ""
        }

        if let value = try? container.decode(String.self, forKey: .voteId) {
            self.voteId = value
        } else if let value = try? container.decode(Int.self, forKey: .voteId) {
            self.voteId = String(value)
        } else {
            self.voteId = ""
        }
    }
}
