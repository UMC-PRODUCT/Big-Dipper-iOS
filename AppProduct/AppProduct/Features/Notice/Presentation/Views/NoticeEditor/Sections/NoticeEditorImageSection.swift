//
//  NoticeEditorImageSection.swift
//  AppProduct
//
//  Created by 이예지 on 1/24/26.
//

import SwiftUI

/// 공지 에디터의 첨부 이미지 목록 섹션입니다.
struct NoticeEditorImageSection: View {

    // MARK: - Property

    let images: [NoticeImageItem]
    let onRemove: (NoticeImageItem) -> Void

    // MARK: - Body

    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(images, id: \.id) { item in
                    ImageAttachmentCard(
                        id: item.id,
                        imageData: item.imageData,
                        imageURL: item.imageURL,
                        isLoading: item.isLoading,
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                onRemove(item)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        }
        .scrollIndicators(.hidden)
    }
}
