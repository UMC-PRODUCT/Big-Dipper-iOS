//
//  NoticeReadStatusDTO.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation
import NoticeDomain
import UMCFoundation

// MARK: - 공지 열람 통계 DTO

/// 공지 열람 통계 응답 DTO
public struct NoticeReadStaticsDTO: Codable {
    public let totalCount: String
    public let readCount: String
    public let unreadCount: String
    public let readRate: String

    /// 테스트/프리뷰 및 낙관적 UI 갱신용 멤버와이즈 이니셜라이저
    public init(totalCount: String, readCount: String, unreadCount: String, readRate: String) {
        self.totalCount = totalCount
        self.readCount = readCount
        self.unreadCount = unreadCount
        self.readRate = readRate
    }

    private enum CodingKeys: String, CodingKey {
        case totalCount
        case readCount
        case unreadCount
        case readRate
    }

    /// 커스텀 디코더: 서버 응답의 숫자/문자열 타입 불일치를 유연하게 처리합니다.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.totalCount = container.decodeFlexibleString(forKey: .totalCount)
        self.readCount = container.decodeFlexibleString(forKey: .readCount)
        self.unreadCount = container.decodeFlexibleString(forKey: .unreadCount)
        self.readRate = container.decodeFlexibleString(forKey: .readRate)
    }
}

// MARK: - 공지 열람 현황 상세 DTO

/// 공지 열람 현황 사용자 정보 DTO
public struct NoticeReadStatusUserDTO: Codable {
    public let challengerId: String
    public let name: String
    public let nickname: String?
    public let profileImageUrl: String?
    public let part: String
    public let schoolId: String
    public let schoolName: String
    public let chapterId: String
    public let chapterName: String

    private enum CodingKeys: String, CodingKey {
        case challengerId
        case name
        case nickname
        case profileImageUrl
        case part
        case schoolId
        case schoolName
        case chapterId
        case chapterName
    }

    private enum AlternateNicknameCodingKeys: String, CodingKey {
        case nickName
        case authorNickname
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.challengerId = container.decodeFlexibleString(forKey: .challengerId)
        self.name = try container.decode(String.self, forKey: .name)
        self.nickname = try Self.decodeNickname(
            from: decoder,
            primaryContainer: container
        )
        self.profileImageUrl = try? container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        self.part = try container.decode(String.self, forKey: .part)
        self.schoolId = container.decodeFlexibleString(forKey: .schoolId)
        self.schoolName = try container.decode(String.self, forKey: .schoolName)
        self.chapterId = container.decodeFlexibleString(forKey: .chapterId)
        self.chapterName = try container.decode(String.self, forKey: .chapterName)
    }

    private static func decodeNickname(
        from decoder: Decoder,
        primaryContainer: KeyedDecodingContainer<CodingKeys>
    ) throws -> String? {
        if let nickname = primaryContainer.decodeFirstNonEmptyString(forKeys: [.nickname]) {
            return nickname
        }

        let alternateContainer = try decoder.container(keyedBy: AlternateNicknameCodingKeys.self)
        return alternateContainer.decodeFirstNonEmptyString(forKeys: [.nickName, .authorNickname])
    }
}

/// 공지 열람 현황 응답 DTO (Cursor 기반 페이징)
public struct NoticeReadStatusResponseDTO: Codable {
    public let content: [NoticeReadStatusUserDTO]
    public let nextCursor: String
    public let hasNext: Bool

    private enum CodingKeys: String, CodingKey {
        case content
        case nextCursor
        case hasNext
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.content = try container.decode([NoticeReadStatusUserDTO].self, forKey: .content)
        self.nextCursor = container.decodeFlexibleOptionalString(forKey: .nextCursor) ?? ""
        self.hasNext = try container.decode(Bool.self, forKey: .hasNext)
    }
}

// MARK: - toDomain 변환

extension NoticeReadStatusUserDTO {
    /// DTO → ReadStatusUser 도메인 모델 변환
    /// - Parameter isRead: 읽음/미읽음 상태 (API 호출 시 status 파라미터로 결정됨)
    func toDomain(isRead: Bool) -> ReadStatusUser {
        // part String → UMCPartType enum 변환
        let userPart = UMCPartType(apiValue: part)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedNickname = trimmedNickname.isEmpty ? trimmedName : trimmedNickname
        
        return ReadStatusUser(
            id: challengerId,
            name: trimmedName,
            nickName: resolvedNickname,
            part: userPart?.name ?? "알 수 없음",
            branch: chapterName,
            campus: schoolName,
            profileImageURL: profileImageUrl,
            isRead: isRead
        )
    }
}

// MARK: - Flexible Decoding Helpers

private extension KeyedDecodingContainer {
    /// String, Int, Double 타입 중 하나로 디코딩하여 String으로 반환 (실패 시 빈 문자열)
    func decodeFlexibleString(forKey key: Key) -> String {
        if let value = try? decode(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Double.self, forKey: key) {
            return String(value)
        }
        return ""
    }

    /// String, Int, Double 타입 중 하나로 디코딩하여 Optional String으로 반환
    func decodeFlexibleOptionalString(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Double.self, forKey: key) {
            return String(value)
        }
        return nil
    }

    func decodeFirstNonEmptyString(forKeys keys: [Key]) -> String? {
        for key in keys {
            guard let rawValue = decodeFlexibleOptionalString(forKey: key) else { continue }
            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }
}
