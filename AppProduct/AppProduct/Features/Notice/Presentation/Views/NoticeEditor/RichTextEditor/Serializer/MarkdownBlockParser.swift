//
//  MarkdownBlockParser.swift
//  AppProduct
//
//  Created by euijjang97 on 4/8/26.
//

import Foundation
import UIKit

// MARK: - MarkdownBlockParser

enum MarkdownBlockParser {

    // MARK: - Function

    static func deserialize(_ markdown: String, baseFont: UIFont) -> NSAttributedString {
        let normalizedMarkdown = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalizedMarkdown.components(separatedBy: "\n")
        let attributedString = NSMutableAttributedString()

        for index in lines.indices {
            let block = deserializeBlock(from: lines[index], baseFont: baseFont)
            attributedString.append(block.content)

            if index < lines.count - 1 {
                attributedString.append(NSAttributedString(string: "\n", attributes: block.newlineAttributes))
            }
        }

        return attributedString
    }

    static func deserializeBlock(from line: String, baseFont: UIFont) -> MarkdownDeserializedBlock {
        var style = MarkdownInlineStyle()
        var markdownBody = line
        var literalPrefix = ""

        let lineNSString = line as NSString
        let lineRange = NSRange(location: 0, length: lineNSString.length)

        if let match = MarkdownRegex.h3.firstMatch(in: line, range: lineRange) {
            // ### 텍스트 → 단락 스타일 subheading (17pt)
            markdownBody = lineNSString.substring(from: match.range.length)
            style.fontSize = 17
            style.isBold = true
        } else if let match = MarkdownRegex.h2.firstMatch(in: line, range: lineRange) {
            // ## 텍스트 → 단락 스타일 heading (22pt)
            markdownBody = lineNSString.substring(from: match.range.length)
            style.fontSize = 22
            style.isBold = true
        } else if let match = MarkdownRegex.h1.firstMatch(in: line, range: lineRange) {
            // # 텍스트 → 단락 스타일 title (28pt)
            markdownBody = lineNSString.substring(from: match.range.length)
            style.fontSize = 28
            style.isBold = true
        } else if let match = MarkdownRegex.blockquote.firstMatch(in: line, range: lineRange) {
            // > 텍스트 → 인용구 (headIndent > 0 + .editorBlockquote attribute)
            markdownBody = lineNSString.substring(from: match.range.length)
            style.paragraphStyle = MarkdownAttributeBuilder.quoteParagraphStyle()
            style.isBlockquote = true
        } else if let match = MarkdownRegex.bulletList.firstMatch(in: line, range: lineRange) {
            // - 텍스트 → bullet prefix •
            markdownBody = lineNSString.substring(from: match.range.length)
            literalPrefix = "• "
        } else if let match = MarkdownRegex.dashList.firstMatch(in: line, range: lineRange) {
            // – 텍스트 → dash prefix –
            markdownBody = lineNSString.substring(from: match.range.length)
            literalPrefix = "– "
        } else if let match = MarkdownRegex.numberList.firstMatch(in: line, range: lineRange) {
            // 1. 텍스트 → number prefix 숫자.
            let marker = lineNSString.substring(with: match.range(at: 1))
            markdownBody = lineNSString.substring(from: match.range.length)
            literalPrefix = "\(marker). "
        }

        let mutableAttributedString = NSMutableAttributedString()

        if literalPrefix.isEmpty == false {
            mutableAttributedString.append(NSAttributedString(
                string: literalPrefix,
                attributes: MarkdownAttributeBuilder.attributes(for: style, baseFont: baseFont)
            ))
        }

        mutableAttributedString.append(MarkdownInlineParser.parseInlineMarkdown(markdownBody, baseFont: baseFont, style: style))

        return MarkdownDeserializedBlock(
            content: mutableAttributedString,
            newlineAttributes: MarkdownAttributeBuilder.attributes(for: style, baseFont: baseFont)
        )
    }
}
