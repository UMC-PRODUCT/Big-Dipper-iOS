//
//  NoticeItemModel.swift
//  AppProduct
//
//  Created by 김미주 on 1/9/26.
//

import SwiftUI

/// 공지사항 목록 아이템 모델
///
/// 공지 리스트 셀에 표시할 정보를 담으며, scope/category 조합으로 태그를 생성합니다.
struct NoticeItemModel: Equatable, Identifiable {
    let id = UUID()
    let noticeId: String
    let generation: String
    // 공지 출처 (중앙/지부/교내)
    let scope: NoticeScope
    // 공지 카테고리 (일반/파트별)
    let category: NoticeCategory
    let isAlert: Bool
    let date: Date
    let title: String
    let content: String
    let writer: String
    let authorNickname: String?
    let authorName: String?
    let links: [String]
    let images: [String]
    let vote: NoticeVote?
    let viewCount: String
    let scopeDisplayName: String?
    let targetsAllGenerations: Bool
    let parts: [UMCPartType]
    let isRead: Bool

    init(
        noticeId: String = UUID().uuidString,
        generation: String,
        scope: NoticeScope,
        category: NoticeCategory,
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
    
    /// UI 표시용 태그 목록
    var tags: [NoticeItemTag] {
        var items: [NoticeItemTag] = [
            NoticeItemTag(
                text: targetsAllGenerations ? "모든 기수" : "\(generation)기",
                backColor: .blue
            )
        ]

        if let scopeTag {
            items.append(scopeTag)
        }

        items.append(contentsOf: partTags)

        return items
    }
    
    var hasLink: Bool { !links.isEmpty }
    var hasVote: Bool { vote != nil }
    var displayWriter: String {
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

private extension NoticeItemModel {
    var scopeTag: NoticeItemTag? {
        switch scope {
        case .central:
            return nil
        case .branch:
            let displayName = scopeDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return NoticeItemTag(
                text: displayName.isEmpty ? "지부" : displayName,
                backColor: .orange500
            )
        case .campus:
            return NoticeItemTag(text: "교내", backColor: .green500)
        }
    }

    var resolvedParts: [UMCPartType] {
        if !parts.isEmpty {
            return parts
        }

        if case .part(let part) = category {
            return [part]
        }

        return []
    }

    var partTags: [NoticeItemTag] {
        guard !resolvedParts.isEmpty else { return [] }

        if resolvedParts.count >= 4 {
            return [
                NoticeItemTag(
                    text: "여러 파트",
                    backColor: .grey500
                )
            ]
        }

        return resolvedParts.prefix(3).map { part in
            NoticeItemTag(
                text: NoticePart(umcPartType: part)?.displayName ?? "파트",
                backColor: part.color
            )
        }
    }
}

extension NoticeItemModel {
    /// 목록 아이템을 상세 화면용 NoticeDetail로 변환합니다.
    func toNoticeDetail() -> NoticeDetail {
        NoticeDetail(
            id: noticeId,
            generation: generation,
            scope: scope,
            category: category,
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
