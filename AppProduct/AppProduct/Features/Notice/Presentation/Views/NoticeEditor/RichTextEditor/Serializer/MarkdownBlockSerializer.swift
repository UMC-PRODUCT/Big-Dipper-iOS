//
//  MarkdownBlockSerializer.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation
import UIKit

// MARK: - MarkdownBlockSerializer

enum MarkdownBlockSerializer {

    // MARK: - Function

    static func serialize(_ attributedString: NSAttributedString) -> String {
        let nsString = attributedString.string as NSString

        guard nsString.length > 0 else {
            return ""
        }

        var markdown = ""
        var location = 0

        while location < nsString.length {
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: location, length: 0))
            let paragraphText = nsString.substring(with: paragraphRange) as NSString
            let contentLength = contentLengthExcludingTrailingNewlines(in: paragraphText)
            let contentRange = NSRange(location: paragraphRange.location, length: contentLength)
            let trailingRange = NSRange(
                location: paragraphRange.location + contentLength,
                length: paragraphRange.length - contentLength
            )

            if contentRange.length == 0 {
                markdown.append(nsString.substring(with: trailingRange))
                location = NSMaxRange(paragraphRange)
                continue
            }

            let blockContext = blockContext(for: attributedString, contentRange: contentRange)
            var line = blockContext.markdownPrefix
            line.append(MarkdownInlineSerializer.serializeInline(
                attributedString,
                range: blockContext.inlineRange,
                blockImpliedBold: blockContext.blockImpliedBold
            ))

            if blockContext.markdownPrefix.isEmpty {
                line = MarkdownEscaping.escapeLeadingBlockSyntax(in: line)
            }

            markdown.append(line)
            markdown.append(nsString.substring(with: trailingRange))
            location = NSMaxRange(paragraphRange)
        }

        return markdown
    }

    // MARK: - Private

    private static func blockContext(for attributedString: NSAttributedString, contentRange: NSRange) -> MarkdownBlockContext {
        let paragraphString = attributedString.attributedSubstring(from: contentRange).string as NSString
        let fullLength = paragraphString.length

        guard let firstContentOffset = firstNonWhitespaceOffset(in: paragraphString as String) else {
            return MarkdownBlockContext(markdownPrefix: "", inlineRange: contentRange, blockImpliedBold: false)
        }

        let firstContentLocation = contentRange.location + firstContentOffset
        let font = attributedString.attribute(.font, at: firstContentLocation, effectiveRange: nil) as? UIFont

        // 속성 기반 판별을 텍스트 prefix보다 먼저 수행 (제목/인용구가 목록처럼 보이는 텍스트로 시작해도 안전)
        let isBlockquote = (attributedString.attribute(.editorBlockquote, at: firstContentLocation, effectiveRange: nil) as? Bool) == true
        if isBlockquote {
            // 인용구 (.editorBlockquote attribute) → > 텍스트
            return MarkdownBlockContext(markdownPrefix: "> ", inlineRange: contentRange, blockImpliedBold: false)
        }

        if let font, abs(font.pointSize - 28) < 0.5 {
            // 단락 스타일 title (28pt) → # 텍스트
            return MarkdownBlockContext(markdownPrefix: "# ", inlineRange: contentRange, blockImpliedBold: true)
        }

        if let font, abs(font.pointSize - 22) < 0.5 {
            // 단락 스타일 heading (22pt) → ## 텍스트
            return MarkdownBlockContext(markdownPrefix: "## ", inlineRange: contentRange, blockImpliedBold: true)
        }

        if let font,
           abs(font.pointSize - 17) < 0.5,
           font.fontDescriptor.symbolicTraits.contains(.traitBold),
           isParagraphDominantlySubheading(in: attributedString, range: contentRange) {
            // 단락 스타일 subheading (17pt) → ### 텍스트
            return MarkdownBlockContext(markdownPrefix: "### ", inlineRange: contentRange, blockImpliedBold: true)
        }

        // 텍스트 prefix 기반 목록 판별 (속성 판별 이후)
        if let match = MarkdownRegex.bulletPrefix
            .firstMatch(in: paragraphString as String, range: NSRange(location: 0, length: fullLength)) {
            // Bullet prefix • → - 텍스트
            return MarkdownBlockContext(
                markdownPrefix: "- ",
                inlineRange: NSRange(location: contentRange.location + match.range.length, length: contentRange.length - match.range.length),
                blockImpliedBold: false
            )
        }

        if let match = MarkdownRegex.dashPrefix
            .firstMatch(in: paragraphString as String, range: NSRange(location: 0, length: fullLength)) {
            // Dash prefix – → – 텍스트
            return MarkdownBlockContext(
                markdownPrefix: "– ",
                inlineRange: NSRange(location: contentRange.location + match.range.length, length: contentRange.length - match.range.length),
                blockImpliedBold: false
            )
        }

        if let match = MarkdownRegex.numberPrefix
            .firstMatch(in: paragraphString as String, range: NSRange(location: 0, length: fullLength)) {
            let marker = paragraphString.substring(with: match.range(at: 1))

            // Number prefix 숫자. → 1. 텍스트
            return MarkdownBlockContext(
                markdownPrefix: "\(marker). ",
                inlineRange: NSRange(location: contentRange.location + match.range.length, length: contentRange.length - match.range.length),
                blockImpliedBold: false
            )
        }

        return MarkdownBlockContext(markdownPrefix: "", inlineRange: contentRange, blockImpliedBold: false)
    }

    private static func contentLengthExcludingTrailingNewlines(in paragraph: NSString) -> Int {
        var length = paragraph.length

        while length > 0 {
            let character = paragraph.substring(with: NSRange(location: length - 1, length: 1))

            if character == "\n" || character == "\r" {
                length -= 1
                continue
            }

            break
        }

        return length
    }

    private static func firstNonWhitespaceOffset(in text: String) -> Int? {
        let nsText = text as NSString
        let range = nsText.rangeOfCharacter(from: CharacterSet.whitespaces.inverted)

        guard range.location != NSNotFound else {
            return nil
        }

        return range.location
    }

    /// 단락 내 비공백 문자 전체가 17pt bold 폰트인지 확인합니다.
    ///
    /// 링크, 밑줄, bold-italic 복합 등 인라인 서식이 포함되어도 폰트 크기와 굵기가
    /// subheading 조건을 만족하면 `###` 접두사를 붙일 수 있도록 합니다.
    private static func isParagraphDominantlySubheading(in attributedString: NSAttributedString, range: NSRange) -> Bool {
        var hasNonWhitespace = false
        var allSubheading = true

        attributedString.enumerateAttribute(.font, in: range) { value, effectiveRange, stop in
            let content = attributedString.attributedSubstring(from: effectiveRange).string
            guard content.contains(where: { !$0.isWhitespace }) else { return }
            hasNonWhitespace = true

            if let font = value as? UIFont,
               abs(font.pointSize - 17) < 0.5,
               font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                // This run qualifies as subheading
            } else {
                allSubheading = false
                stop.pointee = true
            }
        }

        return hasNonWhitespace && allSubheading
    }
}
