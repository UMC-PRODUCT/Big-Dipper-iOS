//
//  NoticeDetail+UI.swift
//  NoticePresentation
//
//  Created by 이예지 on 5/8/26.
//

import SwiftUI
import NoticeDomain
import CoreDesignSystem

/// 목록/상세에서 공통으로 사용할 태그 목록
extension NoticeDetail {
    public var tags: [NoticeItemTag] {
        NoticeItemModel(
            noticeId: id,
            generation: generation,
            scope: scope,
            category: category,
            mustRead: isMustRead,
            isAlert: false,
            date: createdAt,
            title: title,
            content: content,
            writer: authorName,
            links: links,
            images: images,
            vote: vote,
            viewCount: "0",
            scopeDisplayName: targetAudience.branches.first,
            targetsAllGenerations: (Int(targetAudience.generation) ?? 0) <= 0,
            parts: targetAudience.parts,
            isRead: false
        ).tags
    }
}

extension TargetAudience {
    /// 수신 대상 표시 텍스트
    ///
    /// 레거시 호환용 속성입니다. 신규 UI는 `NoticeDetail.tags`를 사용합니다.
    public var displayText: String {
        NoticeDetail(
            id: "",
            generation: generation,
            scope: scope,
            category: parts.first.map { .part($0) } ?? .general,
            isMustRead: false,
            title: "",
            content: "",
            authorID: "",
            authorNickname: nil,
            authorName: "",
            authorImageURL: nil,
            createdAt: .now,
            updatedAt: nil,
            targetAudience: self,
            hasPermission: false,
            images: [],
            links: [],
            vote: nil
        )
        .tags
        .map(\.text)
        .joined(separator: " / ")
    }
}
