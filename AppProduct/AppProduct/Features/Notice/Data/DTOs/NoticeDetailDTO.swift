//
//  NoticeDetailDTO.swift
//  AppProduct
//
//  Created by 이예지 on 2/14/26.
//

import Foundation

// MARK: - NoticeDetailDTO

/// 공지 상세화면 DTO
struct NoticeDetailDTO: Codable {

    // MARK: - Property

    let id: String
    let title: String
    let content: String
    let shouldSendNotification: Bool?
    let viewCount: String
    let createdAt: String
    let updatedAt: String?
    let targetInfo: NoticeTargetInfoDTO
    let authorChallengerId: String?
    let authorMemberId: String?
    let authorNickname: String?
    let authorName: String?
    let authorProfileImageUrl: String?

    // 상세 추가 필드
    let vote: NoticeDetailVoteDTO?
    let images: [NoticeDetailImageDTO]
    let links: [NoticeDetailLinkDTO]
    let scope: String?
    let category: String?
    let hasPermission: Bool?

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
        case hasPermission
    }

    /// 커스텀 디코더: 필드 누락·타입 불일치를 방어적으로 처리합니다.
    ///
    /// 서버 응답이 불완전할 경우에도 앱 크래시를 방지하기 위해
    /// 각 필드에 대해 개별적으로 디코딩을 시도하고 기본값으로 폴백합니다.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeStringFlexible(forKey: .id)
        title = try container.decodeStringOrEmpty(forKey: .title)
        content = try container.decodeStringOrEmpty(forKey: .content)
        shouldSendNotification = try? container.decode(Bool.self, forKey: .shouldSendNotification)
        viewCount = try container.decodeStringFlexible(forKey: .viewCount)
        createdAt = try container.decodeStringOrEmpty(forKey: .createdAt)
        updatedAt = try? container.decodeIfPresent(String.self, forKey: .updatedAt)
        targetInfo = (try? container.decode(NoticeTargetInfoDTO.self, forKey: .targetInfo))
            ?? NoticeTargetInfoDTO(targetGisuId: "0", targetChapterId: nil, targetSchoolId: nil, targetParts: nil)
        authorChallengerId = try? container.decodeStringOrNil(forKey: .authorChallengerId)
        authorMemberId = try? container.decodeStringOrNil(forKey: .authorMemberId)
        authorNickname = try? container.decodeStringOrNil(forKey: .authorNickname)
        authorName = try? container.decodeStringOrNil(forKey: .authorName)
        authorProfileImageUrl = try? container.decodeStringOrNil(forKey: .authorProfileImageUrl)

        vote = try? container.decodeIfPresent(NoticeDetailVoteDTO.self, forKey: .vote)
        images = (try? container.decode([NoticeDetailImageDTO].self, forKey: .images)) ?? []
        links = (try? container.decode([NoticeDetailLinkDTO].self, forKey: .links)) ?? []

        scope = try? container.decodeStringOrNil(forKey: .scope)
        category = try? container.decodeStringOrNil(forKey: .category)
        hasPermission = try? container.decodeIfPresent(Bool.self, forKey: .hasPermission)
    }
}

// MARK: - toDomain 변환

extension NoticeDetailDTO {
    /// NoticeDetailDTO → NoticeDetail 도메인 모델 변환
    ///
    /// scope/category가 nil인 경우 targetInfo 기반으로 추론합니다.
    func toDomain() -> NoticeDetail {
        let generation = targetInfo.generationValue

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

// MARK: - Flexible Decoding Helpers

private extension KeyedDecodingContainer {
    /// String/Int/Double 타입을 모두 String으로 디코딩합니다.
    func decodeStringFlexible(forKey key: Key) throws -> String {
        if let value = try? decode(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Double.self, forKey: key) {
            return String(value)
        }
        throw DecodingError.valueNotFound(
            String.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Expected String value for key '\(key.stringValue)'"
            )
        )
    }

    /// 디코딩 실패 시 빈 문자열을 반환합니다.
    func decodeStringOrEmpty(forKey key: Key) throws -> String {
        return (try? decodeStringFlexible(forKey: key)) ?? ""
    }

    /// 명시적 null 또는 디코딩 실패 시 nil을 반환합니다.
    func decodeStringOrNil(forKey key: Key) throws -> String? {
        if try decodeNil(forKey: key) {
            return nil
        }
        return try? decodeStringFlexible(forKey: key)
    }
}
