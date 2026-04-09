//
//  MarkdownRenderedView.swift
//  AppProduct
//
//  Created by euijjang97 on 4/9/26.
//

import SwiftUI
import UIKit

/// 마크다운 문자열을 서식이 적용된 상태로 표시하는 read-only 뷰입니다.
struct MarkdownRenderedView: View {

    let markdown: String

    var body: some View {
        _MarkdownTextViewRepresentable(markdown: markdown)
    }
}

// MARK: - UIViewRepresentable

private struct _MarkdownTextViewRepresentable: UIViewRepresentable {

    let markdown: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.dataDetectorTypes = [.link]
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        let attributed = MarkdownSerializer.deserialize(markdown, baseFont: baseFont)
        let mutable = NSMutableAttributedString(attributedString: attributed)

        // 기본 폰트/색상 설정
        let fullRange = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            if value == nil {
                mutable.addAttribute(.font, value: baseFont, range: range)
            }
        }
        mutable.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
            if value == nil {
                mutable.addAttribute(.foregroundColor, value: UIColor.label, range: range)
            }
        }

        uiView.attributedText = mutable
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        let targetSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        return uiView.sizeThatFits(targetSize)
    }
}
