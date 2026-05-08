//
//  NoticeDetail+Tags.swift
//  NoticePresentation
//
//  Created by 이예지 on 5/8/26.
//

import SwiftUI
import UMCFoundation
import NoticeDomain
import CoreDesignSystem
import CoreUIComponents

extension NoticeItemModel {
    public var tags: [NoticeItemTag] {
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
