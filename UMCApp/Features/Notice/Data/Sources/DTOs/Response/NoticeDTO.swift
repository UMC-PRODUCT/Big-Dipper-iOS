//
//  NoticeDTO.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation
import NoticeDomain
import UMCFoundation

// MARK: - Notice DTO
/// 공지 리스트카드 DTO
public struct NoticeDTO: Codable {
    public let id: String
    public let title: String
    public let content: String
    public let shouldSendNotification: Bool
    public let viewCount: String
    public let createdAt: String
    public let targetInfo: NoticeTargetInfoDTO
    public let authorChallengerId: String?
    public let authorMemberId: String?
    public let authorNickname: String
    public let authorName: String

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case shouldSendNotification
        case viewCount
        case createdAt
        case targetInfo
        case authorChallengerId
        case authorMemberId
        case authorNickname
        case authorName
    }

    /// 커스텀 디코더: 서버 응답의 타입 불일치(Int/String)를 유연하게 처리합니다.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        shouldSendNotification = try container.decodeIfPresent(Bool.self, forKey: .shouldSendNotification) ?? false
        viewCount = try container.decodeFlexibleString(forKey: .viewCount)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        targetInfo = try container.decode(NoticeTargetInfoDTO.self, forKey: .targetInfo)
        authorChallengerId = try? container.decode(String.self, forKey: .authorChallengerId)
        authorMemberId = try? container.decode(String.self, forKey: .authorMemberId)
        authorNickname = try container.decodeIfPresent(String.self, forKey: .authorNickname) ?? ""
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName) ?? ""
    }
}

// MARK: - Mapping
extension NoticeDTO {
    /// NoticeDTO → NoticeItemModel 변환 (공지 목록용)
    func toItemModel(
        generationOverride: String? = nil,
        scopeDisplayNameOverride: String? = nil
    ) -> NoticeItemModel {
        let generation = generationOverride ?? String(targetInfo.generationValue)
        let scope = targetInfo.resolvedScope
        let category = targetInfo.resolvedCategory
        let scopeDisplayName = scopeDisplayNameOverride ?? targetInfo.resolvedScopeDisplayName
        let targetsAllGenerations = (Int(generation) ?? 0) <= 0 && targetInfo.targetsAllGenerations
        
        let resolvedAuthorName = resolvedAuthorName(authorName)

        return NoticeItemModel(
            noticeId: id,
            generation: generation,
            scope: scope,
            category: category,
            mustRead: false,
            isAlert: shouldSendNotification,
            date: createdAt.toISO8601Date(),
            title: title,
            content: content,
            writer: resolvedAuthorName,
            authorNickname: authorNickname.isEmpty ? nil : authorNickname,
            authorName: resolvedAuthorName == "알 수 없음" ? nil : resolvedAuthorName,
            links: [],  // 기본 조회에는 없음
            images: [],  // 기본 조회에는 없음
            vote: nil,
            viewCount: viewCount,
            scopeDisplayName: scopeDisplayName,
            targetsAllGenerations: targetsAllGenerations,
            parts: targetInfo.resolvedParts,
            isRead: false
        )
    }
}

private func resolvedAuthorName(_ authorName: String) -> String {
    let trimmedAuthorName = authorName.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedAuthorName.isEmpty ? "알 수 없음" : trimmedAuthorName
}

// MARK: - TargetInfo DTO
/// 공지 목록/검색 응답용 targetInfo DTO
///
/// 숫자 필드는 서버 스펙에 맞춰 String으로 처리합니다.
public struct NoticeTargetInfoDTO: Codable {
    public let targetGisu: String?
    public let targetGisuId: String
    public let targetChapterId: String?
    public let targetSchoolId: String?
    public let targetChapterName: String?
    public let targetSchoolName: String?
    public let chapterName: String?
    public let schoolName: String?
    public let targetParts: [UMCPartType]?

    private enum CodingKeys: String, CodingKey {
        case targetGisu
        case targetGisuId
        case targetChapterId
        case targetSchoolId
        case targetChapterName
        case targetSchoolName
        case chapterName
        case schoolName
        case targetParts
    }

    public init(
        targetGisu: String? = nil,
        targetGisuId: String,
        targetChapterId: String?,
        targetSchoolId: String?,
        targetChapterName: String? = nil,
        targetSchoolName: String? = nil,
        chapterName: String? = nil,
        schoolName: String? = nil,
        targetParts: [UMCPartType]?
    ) {
        self.targetGisu = targetGisu
        self.targetGisuId = targetGisuId
        self.targetChapterId = targetChapterId
        self.targetSchoolId = targetSchoolId
        self.targetChapterName = targetChapterName
        self.targetSchoolName = targetSchoolName
        self.chapterName = chapterName
        self.schoolName = schoolName
        self.targetParts = targetParts
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        targetGisu = container.decodeFlexibleStringOrNil(forKey: .targetGisu)
        targetGisuId = container.decodeFlexibleStringOrNil(forKey: .targetGisuId) ?? "0"
        targetChapterId = container.decodeFlexibleStringOrNil(forKey: .targetChapterId)
        targetSchoolId = container.decodeFlexibleStringOrNil(forKey: .targetSchoolId)
        targetChapterName = container.decodeFlexibleStringOrNil(forKey: .targetChapterName)
        targetSchoolName = container.decodeFlexibleStringOrNil(forKey: .targetSchoolName)
        chapterName = container.decodeFlexibleStringOrNil(forKey: .chapterName)
        schoolName = container.decodeFlexibleStringOrNil(forKey: .schoolName)
        targetParts = try container.decodeIfPresent([UMCPartType].self, forKey: .targetParts)
    }

    public var resolvedChapterName: String? {
        let candidates = [targetChapterName, chapterName]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    public var resolvedSchoolName: String? {
        let candidates = [targetSchoolName, schoolName]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    public var targetsAllGenerations: Bool {
        generationValue <= 0
    }
}

// MARK: - Helper
private extension String {
    /// ISO8601 문자열을 Date로 변환합니다.
    /// - Note: 소수점 초 포함/미포함 포맷을 모두 지원합니다.
    func toISO8601Date() -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = formatter.date(from: self) {
            return parsed
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: self) ?? Date()
    }
}

