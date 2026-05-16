//
//  NoticeItemModel.swift
//  NoticeDomain
//
//  Created by 이예지 on 5/8/26.
//

import Foundation
import UMCFoundation

/// 공지사항 목록 아이템 모델
///
/// 공지 리스트 셀에 표시할 정보를 담으며, scope/category 조합으로 태그를 생성합니다.
public struct NoticeItemModel: Equatable, Identifiable {
    public let id = UUID()
    public let noticeId: String
    public let generation: String
    // 공지 출처 (중앙/지부/교내)
    public let scope: NoticeScope
    // 공지 카테고리 (일반/파트별)
    public let category: NoticeCategory
    public let mustRead: Bool
    public let isAlert: Bool
    public let date: Date
    public let title: String
    public let content: String
    public let writer: String
    public let authorNickname: String?
    public let authorName: String?
    public let links: [String]
    public let images: [String]
    public let vote: NoticeVote?
    public let viewCount: String
    public let scopeDisplayName: String?
    public let targetsAllGenerations: Bool
    public let parts: [UMCPartType]
    public let isRead: Bool

    public init(
        noticeId: String = UUID().uuidString,
        generation: String,
        scope: NoticeScope,
        category: NoticeCategory,
        mustRead: Bool,
        isAlert: Bool,
        date: Date,
        title: String,
        content: String,
        writer: String,
        authorNickname: String? = nil,
        authorName: String? = nil,
        links: [String],
        images: [String],
        vote: NoticeVote?,
        viewCount: String,
        scopeDisplayName: String? = nil,
        targetsAllGenerations: Bool = false,
        parts: [UMCPartType] = [],
        isRead: Bool = false
    ) {
        self.noticeId = noticeId
        self.generation = generation
        self.scope = scope
        self.category = category
        self.mustRead = mustRead
        self.isAlert = isAlert
        self.date = date
        self.title = title
        self.content = content
        self.writer = writer
        self.authorNickname = authorNickname
        self.authorName = authorName
        self.links = links
        self.images = images
        self.vote = vote
        self.viewCount = viewCount
        self.scopeDisplayName = scopeDisplayName
        self.targetsAllGenerations = targetsAllGenerations
        self.parts = parts
        self.isRead = isRead
    }
    
    public var hasLink: Bool { !links.isEmpty }
    public var hasVote: Bool { vote != nil }
    public var displayWriter: String {
        let trimmedName = (authorName ?? writer).trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNickname = authorNickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !trimmedName.isEmpty && !trimmedNickname.isEmpty {
            return "\(trimmedName)/\(trimmedNickname)"
        }
        if !trimmedName.isEmpty {
            return trimmedName
        }
        if !trimmedNickname.isEmpty {
            return trimmedNickname
        }
        return writer
    }
}

extension NoticeItemModel {
    /// 목록 아이템을 상세 화면용 NoticeDetail로 변환합니다.
    public func toNoticeDetail() -> NoticeDetail {
        NoticeDetail(
            id: noticeId,
            generation: generation,
            scope: scope,
            category: category,
            isMustRead: mustRead,
            title: title,
            content: content,
            authorID: "temp-\(id)",
            authorNickname: authorNickname,
            authorName: authorName ?? writer,
            authorImageURL: nil,
            createdAt: date,
            updatedAt: nil,
            targetAudience: TargetAudience(
                generation: generation,
                scope: scope,
                parts: parts,
                branches: [],
                schools: []
            ),
            hasPermission: false,
            images: images,
            links: links,
            vote: vote
        )
    }
}
