//
//  NoticeEditorLinkSection.swift
//  NoticePresentation
//
//  Created by 이예지 on 7/3/26.
//

import SwiftUI
import CoreDesignSystem
import NoticeDomain

/// 공지 에디터의 첨부 링크 목록 섹션입니다.
struct NoticeEditorLinkSection: View {

    // MARK: - Property

    @Binding var links: [NoticeLinkItem]
    let newlyAddedLinkID: UUID?
    let onRemove: (NoticeLinkItem) -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            ForEach($links, id: \.id) { $item in
                LinkAttachmentCard(
                    link: $item.link,
                    shouldAutoFocus: $item.wrappedValue.id == newlyAddedLinkID,
                    onDismiss: {
                        onRemove($item.wrappedValue)
                    }
                )
                .id($item.wrappedValue.id)
            }
        }
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .padding(.bottom, DefaultSpacing.spacing8)
    }
}
