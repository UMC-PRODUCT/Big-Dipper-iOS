//
//  NoticeDetailDTO.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation
import UMCFoundation
import NoticeDomain

// MARK: - NoticeDetailDTO

/// 공지 상세화면 DTO
public struct NoticeDetailDTO: Codable {

    // MARK: - Property

    public let id: String
    public let title: String
    public let content: String
    public let shouldSendNotification: Bool?
    public let viewCount: String
    public let createdAt: String
    public let updatedAt: String?
    public let targetInfo: NoticeTargetInfoDTO
    public let authorChallengerId: String?
    public let authorMemberId: String?
    public let authorNickname: String?
    public let authorName: String?
    public let authorProfileImageUrl: String?

    // 상세 추가 필드
    public let vote: NoticeDetailVoteDTO?
    public let images: [NoticeDetailImageDTO]
    public let links: [NoticeDetailLinkDTO]
    public let scope: String?
    public let category: String?
    public let isMustRead: Bool?
    public let hasPermission: Bool?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case shouldSendNotification
        case viewCount
        case createdAt
        case updatedAt
        case targetInfo
        case authorChallengerId
        case authorMemberId
        case authorNickname
        case authorName
        case authorProfileImageUrl
        case vote
        case images
        case links
        case scope
        case category
        case isMustRead
        case hasPermission
    }

    /// 커스텀 디코더: 필드 누락·타입 불일치를 방어적으로 처리합니다.
    ///
    /// 서버 응답이 불완전할 경우에도 앱 크래시를 방지하기 위해
    /// 각 필드에 대해 개별적으로 디코딩을 시도하고 기본값으로 폴백합니다.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFlexibleString(forKey: .id)
        title = container.decodeFlexibleStringOrEmpty(forKey: .title)
        content = container.decodeFlexibleStringOrEmpty(forKey: .content)
        shouldSendNotification = try? container.decode(Bool.self, forKey: .shouldSendNotification)
        viewCount = try container.decodeFlexibleString(forKey: .viewCount)
        createdAt = container.decodeFlexibleStringOrEmpty(forKey: .createdAt)
        updatedAt = try? container.decodeIfPresent(String.self, forKey: .updatedAt)
        targetInfo = (try? container.decode(NoticeTargetInfoDTO.self, forKey: .targetInfo))
            ?? NoticeTargetInfoDTO(targetGisuId: "0", targetChapterId: nil, targetSchoolId: nil, targetParts: nil)
        authorChallengerId = container.decodeFlexibleStringOrNil(forKey: .authorChallengerId)
        authorMemberId = container.decodeFlexibleStringOrNil(forKey: .authorMemberId)
        authorNickname = container.decodeFlexibleStringOrNil(forKey: .authorNickname)
        authorName = container.decodeFlexibleStringOrNil(forKey: .authorName)
        authorProfileImageUrl = container.decodeFlexibleStringOrNil(forKey: .authorProfileImageUrl)

        vote = try? container.decodeIfPresent(NoticeDetailVoteDTO.self, forKey: .vote)
        images = (try? container.decode([NoticeDetailImageDTO].self, forKey: .images)) ?? []
        links = (try? container.decode([NoticeDetailLinkDTO].self, forKey: .links)) ?? []

        scope = container.decodeFlexibleStringOrNil(forKey: .scope)
        category = container.decodeFlexibleStringOrNil(forKey: .category)
        isMustRead = try? container.decodeIfPresent(Bool.self, forKey: .isMustRead)
        hasPermission = try? container.decodeIfPresent(Bool.self, forKey: .hasPermission)
    }
}

// MARK: - toDomain 변환

extension NoticeDetailDTO {
    /// NoticeDetailDTO → NoticeDetail 도메인 모델 변환
    ///
    /// scope/category가 nil인 경우 targetInfo 기반으로 추론합니다.
    func toDomain() -> NoticeDetail {
        let generation = String(targetInfo.generationValue)

        // scope 문자열이 없으면 targetInfo 기반으로 추론
        let noticeScope: NoticeScope
        if let scope {
            switch scope.uppercased() {
            case "CENTRAL": noticeScope = .central
            case "BRANCH": noticeScope = .branch
            case "CAMPUS": noticeScope = .campus
            default: noticeScope = .central
            }
        } else {
            noticeScope = targetInfo.resolvedScope
        }

        // category 문자열이 없으면 targetInfo 기반으로 추론
        let noticeCategory: NoticeCategory = {
            if let category {
                switch category.uppercased() {
                case "PART":
                    return targetInfo.resolvedCategory
                case "GENERAL":
                    return .general
                default:
                    return .general
                }
            } else {
                return targetInfo.resolvedCategory
            }
        }()

        let targetAudience = targetInfo.toTargetAudience(scope: noticeScope)

        let mappedVote = vote?.toDomain()
        let mappedImages = images.map { NoticeAttachmentImage(id: $0.id, url: $0.url) }
        let imageURLs = mappedImages.map(\.url)
        let linkURLs = links.map(\.url)
        let resolvedAuthorName = resolvedAuthorName()

        return NoticeDetail(
            id: id,
            generation: generation,
            scope: noticeScope,
            category: noticeCategory,
            isMustRead: isMustRead ?? false,
            title: title,
            content: content,
            authorID: authorChallengerId ?? "0",
            authorMemberId: authorMemberId,
            authorNickname: authorNickname,
            authorName: resolvedAuthorName,
            authorImageURL: authorProfileImageUrl,
            createdAt: createdAt.toISO8601Date(),
            updatedAt: updatedAt?.toISO8601Date(),
            targetAudience: targetAudience,
            hasPermission: hasPermission ?? false,
            images: imageURLs,
            imageItems: mappedImages,
            links: linkURLs,
            vote: mappedVote
        )
    }

    private func resolvedAuthorName() -> String {
        let trimmedAuthorName = authorName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedAuthorName.isEmpty ? "알 수 없음" : trimmedAuthorName
    }
}

// MARK: - String ISO8601 변환

private extension String {
    /// ISO8601 문자열을 Date로 변환
    ///
    /// fractionalSeconds 포함 포맷을 우선 시도하고, 실패 시 기본 포맷으로 재시도합니다.
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
