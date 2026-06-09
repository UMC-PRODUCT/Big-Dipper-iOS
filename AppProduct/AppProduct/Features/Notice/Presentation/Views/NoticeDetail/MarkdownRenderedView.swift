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
        applyMarkdownIfNeeded(to: uiView, coordinator: context.coordinator)
    }

    /// 현재 `markdown`을 텍스트뷰에 반영합니다. 동일한 markdown이면 재처리를 건너뜁니다.
    ///
    /// 빈 본문(상세 진입 직후) → 로드 완료로 콘텐츠가 바뀌는 경우,
    /// SwiftUI가 `sizeThatFits`를 `updateUIView`보다 먼저 호출하면 이전(빈) 텍스트
    /// 기준으로 높이가 측정되어 본문이 한 줄로 collapse됩니다.
    /// 따라서 `updateUIView`와 `sizeThatFits` 양쪽에서 이 메서드를 호출해
    /// 측정 시점에 항상 최신 본문이 반영되도록 보장합니다.
    private func applyMarkdownIfNeeded(to uiView: BlockquoteTextView, coordinator: Coordinator) {
        guard coordinator.lastMarkdown != markdown else { return }
        coordinator.lastMarkdown = markdown

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

    /// HTML 문자열을 서식이 적용된 NSAttributedString으로 변환합니다.
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
        // 높이 측정 전에 최신 본문을 반영해, 콘텐츠 갱신 직후 한 줄로 collapse되는 문제를 막습니다.
        applyMarkdownIfNeeded(to: uiView, coordinator: context.coordinator)

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
