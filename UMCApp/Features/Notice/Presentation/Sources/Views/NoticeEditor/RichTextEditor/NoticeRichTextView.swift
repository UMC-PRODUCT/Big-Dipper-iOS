//
//  NoticeRichTextView.swift
//  NoticePresentation
//
//  Created by 이예지 on 7/3/26.
//

import SwiftUI
import UIKit

struct NoticeRichTextView: View {

    // MARK: - Property

    @Bindable var toolbarViewModel: EditorToolbarViewModel
    @Binding var attributedText: NSAttributedString
    var placeholder: String

    // MARK: - Body

    var body: some View {
        RichTextViewRepresentable(
            toolbarViewModel: toolbarViewModel,
            attributedText: $attributedText,
            placeholder: placeholder
        )
    }
}
