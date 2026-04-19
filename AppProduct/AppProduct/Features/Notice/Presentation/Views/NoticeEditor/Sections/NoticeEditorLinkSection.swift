//
//  NoticeEditorLinkSection.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import SwiftUI

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
