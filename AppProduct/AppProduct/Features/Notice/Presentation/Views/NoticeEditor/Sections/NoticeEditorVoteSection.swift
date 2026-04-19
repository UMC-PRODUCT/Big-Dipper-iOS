//
//  NoticeEditorVoteSection.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import SwiftUI

/// 공지 에디터의 투표 첨부 섹션입니다.
struct NoticeEditorVoteSection: View {

    // MARK: - Property

    @Binding var formData: VoteFormData
    let isEditMode: Bool
    let onDelete: () -> Void
    let onEdit: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing8) {
            voteAttachmentCard

            Label("글 게시 후 투표는 수정이 불가능해요.", systemImage: "exclamationmark.circle")
                .foregroundStyle(.grey500)
                .appFont(.footnote)
        }
    }

    // MARK: - Components

    private var voteAttachmentCard: some View {
        Group {
            if isEditMode {
                VoteAttachmentCard(
                    formData: $formData,
                    mode: .readonly,
                    onDelete: onDelete
                )
            } else {
                VoteAttachmentCard(
                    formData: $formData,
                    mode: .editable,
                    onDelete: onDelete,
                    onEdit: onEdit
                )
            }
        }
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }
}
