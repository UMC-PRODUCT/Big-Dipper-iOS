//
//  NoticeDetailContentDTO.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation
import NoticeDomain

// MARK: - Vote DTO

/// 공지 상세의 투표 정보 DTO
///
/// 투표 상태(`status`)는 서버가 제공하지 않을 경우
/// `startsAt` / `endsAtExclusive`를 기준으로 클라이언트에서 추론합니다.
public struct NoticeDetailVoteDTO: Codable {
    public let voteId: String
    public let title: String
    public let isAnonymous: Bool
    public let allowMultipleChoice: Bool
    public let startsAt: String
    public let endsAtExclusive: String
    public let options: [NoticeDetailVoteOptionDTO]
    public let mySelectedOptionIds: [String]
    public let status: String?
    public let totalParticipants: Int?

    private enum CodingKeys: String, CodingKey {
        case voteId
        case title
        case isAnonymous
        case allowMultipleChoice
        case startsAt
        case endsAtExclusive
        case options
        case mySelectedOptionIds
        case status
        case totalParticipants
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.voteId = try container.decodeStringFlexible(forKey: .voteId)
        self.title = try container.decode(String.self, forKey: .title)
        self.isAnonymous = try container.decode(Bool.self, forKey: .isAnonymous)
        self.allowMultipleChoice = try container.decode(Bool.self, forKey: .allowMultipleChoice)
        self.startsAt = try container.decode(String.self, forKey: .startsAt)
        self.endsAtExclusive = try container.decode(String.self, forKey: .endsAtExclusive)
        self.options = try container.decode([NoticeDetailVoteOptionDTO].self, forKey: .options)
        self.mySelectedOptionIds = try container.decodeStringArrayFlexible(forKey: .mySelectedOptionIds)
        self.status = try container.decodeIfPresent(String.self, forKey: .status)
        self.totalParticipants = try container.decodeIntFlexibleIfPresent(forKey: .totalParticipants)
    }

    /// DTO → `NoticeVote` 도메인 모델 변환
    public func toDomain() -> NoticeVote {
        let startDate = parseISO8601(startsAt)
        let endDate = parseISO8601(endsAtExclusive)
        let resolvedStatus: VoteStatus = status
            .flatMap { VoteStatus(rawValue: $0) }
            ?? VoteStatus.fallback(now: .now, startsAt: startDate, endsAt: endDate)

        return NoticeVote(
            id: voteId,
            question: title,
            options: options.map { $0.toDomain() },
            startDate: startDate,
            endDate: endDate,
            allowMultipleChoices: allowMultipleChoice,
            isAnonymous: isAnonymous,
            userVotedOptionIds: mySelectedOptionIds,
            status: resolvedStatus,
            totalParticipants: totalParticipants.map(String.init)
        )
    }
}

// MARK: - Vote Option DTO

/// 투표 옵션 단건 DTO
public struct NoticeDetailVoteOptionDTO: Codable {
    public let optionId: String
    public let content: String
    public let voteCount: String
    public let selectedMemberIds: [String]
    public let voteRate: String?

    private enum CodingKeys: String, CodingKey {
        case optionId
        case content
        case voteCount
        case selectedMemberIds
        case voteRate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.optionId = try container.decodeStringFlexible(forKey: .optionId)
        self.content = try container.decode(String.self, forKey: .content)
        self.voteCount = try container.decodeStringFlexible(forKey: .voteCount)
        self.selectedMemberIds = (try? container.decodeStringArrayFlexible(forKey: .selectedMemberIds)) ?? []
        self.voteRate = try container.decodeStringFlexibleIfPresent(forKey: .voteRate)
    }
    
    /// DTO → `VoteOption` 도메인 모델 변환
    public func toDomain() -> VoteOption {
        VoteOption(
            id: optionId,
            title: content,
            voteCount: voteCount,
            selectedMemberIds: selectedMemberIds,
            voteRate: voteRate
        )
    }
}

// MARK: - Image DTO

/// 공지 첨부 이미지 단건 DTO
public struct NoticeDetailImageDTO: Codable {
    public let id: String
    public let url: String
    public let displayOrder: String

    private enum CodingKeys: String, CodingKey {
        case id
        case url
        case displayOrder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeStringFlexible(forKey: .id)
        self.url = try container.decode(String.self, forKey: .url)
        self.displayOrder = try container.decodeStringFlexible(forKey: .displayOrder)
    }
}

// MARK: - Link DTO

/// 공지 첨부 링크 단건 DTO
public struct NoticeDetailLinkDTO: Codable {
    public let id: String
    public let url: String
    public let displayOrder: String

    private enum CodingKeys: String, CodingKey {
        case id
        case url
        case displayOrder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeStringFlexible(forKey: .id)
        self.url = try container.decode(String.self, forKey: .url)
        self.displayOrder = try container.decodeStringFlexible(forKey: .displayOrder)
    }
}

// MARK: - Decoding Helpers

private extension KeyedDecodingContainer {
    /// String / Int / Double 타입을 모두 String으로 디코딩
    func decodeStringFlexible(forKey key: Key) throws -> String {
        if let value = try? decode(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Double.self, forKey: key) {
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

    /// String / Int 배열을 모두 [String]으로 디코딩
    func decodeStringArrayFlexible(forKey key: Key) throws -> [String] {
        if let values = try? decode([String].self, forKey: key) {
            return values
        }
        if let values = try? decode([Int].self, forKey: key) {
            return values.map(String.init)
        }
        return []
    }

    /// Int / Double / String 중 하나로 디코딩하여 Int?를 반환
    func decodeIntFlexibleIfPresent(forKey key: Key) throws -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value)
        }
        return nil
    }

    /// String / Int / Double 중 하나로 디코딩하여 String?을 반환
    func decodeStringFlexibleIfPresent(forKey key: Key) throws -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        return nil
    }
}

private func parseISO8601(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let parsed = formatter.date(from: value) {
        return parsed
    }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value) ?? Date()
}
