//
//  NoticeDetailContentDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 2/16/26.
//

import Foundation

struct NoticeDetailVoteDTO: Codable {
    let voteId: String
    let title: String
    let isAnonymous: Bool
    let allowMultipleChoice: Bool
    let startsAt: String
    let endsAtExclusive: String
    let options: [NoticeDetailVoteOptionDTO]
    let mySelectedOptionIds: [String]
    let status: String?
    let totalParticipants: Int?

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

    init(from decoder: Decoder) throws {
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

    func toDomain() -> NoticeVote {
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
            totalParticipants: totalParticipants
        )
    }
}

struct NoticeDetailVoteOptionDTO: Codable {
    let optionId: String
    let content: String
    let voteCount: String
    let selectedMemberIds: [String]
    let voteRate: Double?

    private enum CodingKeys: String, CodingKey {
        case optionId
        case content
        case voteCount
        case selectedMemberIds
        case voteRate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.optionId = try container.decodeStringFlexible(forKey: .optionId)
        self.content = try container.decode(String.self, forKey: .content)
        self.voteCount = try container.decodeStringFlexible(forKey: .voteCount)
        self.selectedMemberIds = (try? container.decodeStringArrayFlexible(forKey: .selectedMemberIds)) ?? []
        self.voteRate = try container.decodeDoubleFlexibleIfPresent(forKey: .voteRate)
    }

    func toDomain() -> VoteOption {
        VoteOption(
            id: optionId,
            title: content,
            voteCount: Int(voteCount) ?? 0,
            selectedMemberIds: selectedMemberIds,
            voteRate: voteRate
        )
    }
}

struct NoticeDetailImageDTO: Codable {
    let id: String
    let url: String
    let displayOrder: String

    private enum CodingKeys: String, CodingKey {
        case id
        case url
        case displayOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeStringFlexible(forKey: .id)
        self.url = try container.decode(String.self, forKey: .url)
        self.displayOrder = try container.decodeStringFlexible(forKey: .displayOrder)
    }
}

struct NoticeDetailLinkDTO: Codable {
    let id: String
    let url: String
    let displayOrder: String

    private enum CodingKeys: String, CodingKey {
        case id
        case url
        case displayOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeStringFlexible(forKey: .id)
        self.url = try container.decode(String.self, forKey: .url)
        self.displayOrder = try container.decodeStringFlexible(forKey: .displayOrder)
    }
}

private extension KeyedDecodingContainer {
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

    func decodeStringArrayFlexible(forKey key: Key) throws -> [String] {
        if let values = try? decode([String].self, forKey: key) {
            return values
        }
        if let values = try? decode([Int].self, forKey: key) {
            return values.map(String.init)
        }
        return []
    }

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

    func decodeDoubleFlexibleIfPresent(forKey key: Key) throws -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Double(value)
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
