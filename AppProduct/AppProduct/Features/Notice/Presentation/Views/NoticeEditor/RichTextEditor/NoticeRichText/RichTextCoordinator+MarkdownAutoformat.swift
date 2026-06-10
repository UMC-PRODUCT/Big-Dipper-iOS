//
//  RichTextCoordinator+MarkdownAutoformat.swift
//  AppProduct
//
//  Created by euijjang97 on 6/10/26.
//

import UIKit

// MARK: - Markdown Autoformat

/// 타이핑/붙여넣기로 입력된 마크다운 문법을 실제 리치 텍스트 서식으로 변환합니다.
///
/// 감지 로직은 `MarkdownAutoformat`(순수 로직)에 있고, 이 확장은 NSTextStorage 치환과
/// 커서/typingAttributes 복원 등 UIKit 레이어만 담당합니다.
extension RichTextCoordinator {

    // MARK: - Typing

    /// 마지막 키 입력으로 완성된 마크다운 토큰을 서식으로 변환합니다.
    ///
    /// `textViewDidChange` 에서 IME 조합이 없을 때만 호출됩니다. 변환 후 이어지는 타이핑이
    /// 서식을 상속하지 않도록 typingAttributes 를 본문 상태로 되돌립니다.
    func applyTypedMarkdownAutoformatIfNeeded(in textView: UITextView) {
        guard textView.markedTextRange == nil,
              textView.selectedRange.length == 0 else { return }

        let storage = textView.textStorage
        let nsText = storage.string as NSString
        let cursorLocation = textView.selectedRange.location
        guard cursorLocation > 0, cursorLocation <= nsText.length else { return }

        let paragraphRange = nsText.paragraphRange(for: NSRange(location: cursorLocation, length: 0))
        let segmentRange = NSRange(
            location: paragraphRange.location,
            length: cursorLocation - paragraphRange.location
        )
        guard segmentRange.length > 0 else { return }
        let segment = nsText.substring(with: segmentRange)

        if convertTypedListPrefixIfNeeded(segment: segment, segmentRange: segmentRange, in: textView) {
            return
        }

        convertCompletedInlineTokenIfNeeded(segment: segment, segmentRange: segmentRange, in: textView)
    }

    // MARK: - Paste

    /// 붙여넣은 마크다운 텍스트를 파싱해 서식 있는 텍스트로 삽입합니다.
    ///
    /// `shouldChangeTextIn` 에서 마크다운 감지 후 호출되며, 호출부는 `false` 를 반환해
    /// UIKit 기본 삽입을 막아야 합니다. 기본 삽입이 일어나지 않으므로 `textViewDidChange`
    /// 가 수행하던 바인딩/placeholder 동기화를 여기서 직접 수행합니다.
    func insertParsedMarkdown(_ markdown: String, in textView: UITextView, range: NSRange) {
        let baseFont = textView.font
            ?? UIFont(name: "Pretendard-Regular", size: 16)
            ?? UIFont.preferredFont(forTextStyle: .body)
        let parsed = MarkdownSerializer.deserialize(markdown, baseFont: baseFont)

        let storage = textView.textStorage
        storage.beginEditing()
        storage.replaceCharacters(in: range, with: parsed)
        storage.endEditing()

        isSuppressingSelectionSync = true
        textView.selectedRange = NSRange(location: range.location + parsed.length, length: 0)
        isSuppressingSelectionSync = false

        // 붙여넣은 끝부분이 헤딩 등일 때 서식이 이어지지 않도록 본문 폰트로 복원합니다.
        var typingAttributes = textView.typingAttributes
        typingAttributes[.font] = baseFont
        typingAttributes.removeValue(forKey: .strikethroughStyle)
        typingAttributes.removeValue(forKey: .underlineStyle)
        typingAttributes.removeValue(forKey: .editorItalic)
        typingAttributes.removeValue(forKey: .link)
        textView.typingAttributes = typingAttributes

        if textView.markedTextRange == nil {
            parent.attributedText = textView.attributedText
        }
        if parent.toolbarViewModel.textStorage !== textView.textStorage {
            parent.toolbarViewModel.textStorage = textView.textStorage
        }
        updatePlaceholder(in: textView)
        (textView as? BlockquoteTextView)?.setNeedsBlockquoteRefresh()
        scheduleScrollCursorToVisible(in: textView)
    }

    // MARK: - Private

    /// 단락 시작에 타이핑된 `- ` / `* ` 를 에디터 네이티브 불릿(`• `)으로 치환합니다.
    ///
    /// `• ` 는 직렬화기가 `- ` 마크다운 목록으로 인식하는 네이티브 표현이며,
    /// Enter 시 목록 이어쓰기(`handleReturnInList`)도 그대로 동작합니다.
    ///
    /// - Returns: 치환이 일어났으면 `true`.
    private func convertTypedListPrefixIfNeeded(
        segment: String,
        segmentRange: NSRange,
        in textView: UITextView
    ) -> Bool {
        guard segment == "- " || segment == "* " else { return false }

        let storage = textView.textStorage
        let attributes = storage.attributes(at: segmentRange.location, effectiveRange: nil)

        storage.beginEditing()
        storage.replaceCharacters(
            in: segmentRange,
            with: NSAttributedString(string: "• ", attributes: attributes)
        )
        storage.endEditing()
        // "- " 와 "• " 는 모두 UTF-16 2 단위라 커서 위치 보정이 필요 없습니다.
        return true
    }

    /// 커서 직전에 완성된 인라인 토큰(`**굿**` 등)을 서식 텍스트로 치환합니다.
    private func convertCompletedInlineTokenIfNeeded(
        segment: String,
        segmentRange: NSRange,
        in textView: UITextView
    ) {
        guard let token = MarkdownAutoformat.completedInlineToken(in: segment) else { return }

        let absoluteRange = NSRange(
            location: segmentRange.location + token.range.location,
            length: token.range.length
        )
        let storage = textView.textStorage

        // 단락 스타일/인용구 키 등 기존 속성을 보존하고 폰트·장식만 덮어씁니다.
        var attributes = storage.attributes(at: absoluteRange.location, effectiveRange: nil)
        let baseFont = attributes[.font] as? UIFont
            ?? textView.font
            ?? UIFont.preferredFont(forTextStyle: .body)

        var style = MarkdownInlineStyle()
        switch token.kind {
        case .bold:
            style.isBold = true
        case .boldItalic:
            style.isBold = true
            style.isItalic = true
        case .italic:
            style.isItalic = true
        case .strikethrough:
            style.isStruck = true
        case .code:
            style.isMonospaced = true
        case .link:
            break
        }

        attributes[.font] = MarkdownAttributeBuilder.font(for: style, baseFont: baseFont)
        if style.isStruck {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if style.isItalic {
            // 툴바 이탤릭과 동일한 상태 추적 키 (Pretendard 는 oblique matrix 로 표현)
            attributes[.editorItalic] = true
        }
        if let linkURL = token.linkURL {
            attributes[.link] = linkURL
        }

        let replacement = NSAttributedString(string: token.body, attributes: attributes)

        storage.beginEditing()
        storage.replaceCharacters(in: absoluteRange, with: replacement)
        storage.endEditing()

        isSuppressingSelectionSync = true
        textView.selectedRange = NSRange(
            location: absoluteRange.location + replacement.length,
            length: 0
        )
        isSuppressingSelectionSync = false

        // 이어지는 타이핑은 서식 없는 본문 상태로 복원합니다.
        var typingAttributes = attributes
        typingAttributes[.font] = baseFont
        typingAttributes.removeValue(forKey: .strikethroughStyle)
        typingAttributes.removeValue(forKey: .editorItalic)
        typingAttributes.removeValue(forKey: .link)
        textView.typingAttributes = typingAttributes
    }
}
