//
//  MarkdownRenderedView.swift
//  AppProduct
//
//  Created by euijjang97 on 4/9/26.
//

import SwiftUI
import UIKit

struct MarkdownRenderedView: View {

    let markdown: String

    var body: some View {
        _MarkdownTextViewRepresentable(markdown: markdown)
    }
}

// MARK: - UIViewRepresentable

private struct _MarkdownTextViewRepresentable: UIViewRepresentable {

    let markdown: String

    func makeUIView(context: Context) -> BlockquoteTextView {
        let textView = BlockquoteTextView()
        textView.isEditable = false
        textView.isSelectable = true   // 링크 탭 인터랙션을 위해 selectable 유지
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.dataDetectorTypes = [.link]
        return textView
    }

    func updateUIView(_ uiView: BlockquoteTextView, context: Context) {
        guard context.coordinator.lastMarkdown != markdown else { return }
        context.coordinator.lastMarkdown = markdown

        let baseFont = UIFont(name: "Pretendard-Regular", size: 16) ?? UIFont.preferredFont(forTextStyle: .body)

        let attributed: NSAttributedString
        if MarkdownSerializer.looksLikeHTML(markdown) {
            attributed = Self.attributedStringFromHTML(markdown, baseFont: baseFont)
        } else {
            let preprocessed = MarkdownSerializer.unescapeForDisplay(markdown)
            attributed = MarkdownSerializer.deserializeForDisplay(preprocessed, baseFont: baseFont)
        }

        let mutable = NSMutableAttributedString(attributedString: attributed)
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
        uiView.setNeedsBlockquoteRefresh()
    }

    private static func attributedStringFromHTML(
        _ html: String,
        baseFont: UIFont
    ) -> NSAttributedString {
        let css = """
            <style>
              body {
                font-family: '\(baseFont.familyName)', '-apple-system', sans-serif;
                font-size: \(Int(baseFont.pointSize))px;
              }
            </style>
            """
        let wrapped = "<html><head><meta charset='utf-8'>\(css)</head><body>\(html)</body></html>"
        guard let data = wrapped.data(using: .utf8),
              let result = try? NSAttributedString(
                  data: data,
                  options: [
                      .documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue
                  ],
                  documentAttributes: nil
              ) else {
            return NSAttributedString(string: html)
        }
        return result
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: BlockquoteTextView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        let inset = uiView.textContainerInset
        let padding = uiView.textContainer.lineFragmentPadding
        let containerWidth = max(0, width - inset.left - inset.right - padding * 2)
        if abs(uiView.textContainer.size.width - containerWidth) > 0.5 {
            uiView.textContainer.size = CGSize(width: containerWidth, height: .greatestFiniteMagnitude)
        }
        uiView.layoutManager.ensureLayout(for: uiView.textContainer)
        let usedRect = uiView.layoutManager.usedRect(for: uiView.textContainer)
        let height = ceil(usedRect.height + inset.top + inset.bottom)
        return CGSize(width: width, height: max(height, 1))
    }

    final class Coordinator {
        var lastMarkdown: String?
    }
}
