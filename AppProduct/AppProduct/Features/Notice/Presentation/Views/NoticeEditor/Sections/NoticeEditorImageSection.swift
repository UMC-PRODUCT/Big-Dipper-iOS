//
//  NoticeEditorImageSection.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import SwiftUI

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
