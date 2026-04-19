//
//  MarkdownBlockParser.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation
import UIKit

// MARK: - MarkdownBlockParser

/// 마크다운 문자열을 **블록 단위**로 분해하여 `NSAttributedString` 을 생성하는 파서.
///
/// 한 줄(line) 단위로 블록 prefix(`#`, `>`, `-` 등)를 검사하고, 본문은
/// `MarkdownInlineParser` 에 위임하여 인라인 토큰까지 해석합니다.
///
/// ### 파이프라인
/// 1. `\r\n`, `\r` 을 `\n` 으로 정규화.
/// 2. 라인 별로 `deserializeBlock` 호출 → `MarkdownDeserializedBlock` 획득.
/// 3. 마지막 줄이 아니면 줄바꿈 문자를 블록 스타일과 함께 덧붙임.
enum MarkdownBlockParser {

    // MARK: - Function

    /// 마크다운 전체 문자열을 `NSAttributedString` 으로 역직렬화합니다.
    ///
    /// - Parameters:
    ///   - markdown: 마크다운 원본.
    ///   - baseFont: 본문 기본 폰트(헤딩이 아닌 줄에 적용).
    /// - Returns: 에디터/미리보기에 표시 가능한 attributed string.
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

    /// 한 줄의 마크다운을 블록 prefix 판별 + 인라인 파싱하여 렌더링 결과를 만듭니다.
    ///
    /// ### 판별 순서
    /// `h3 → h2 → h1 → blockquote → bullet(- ) → dash(– ) → number(1. )` 순서로 검사하여,
    /// 가장 먼저 매칭된 prefix 를 잘라내고 `markdownBody` 로 전달합니다. 목록의 경우
    /// `literalPrefix` 에 사용자에게 보여줄 기호(`•`, `–`, `1.`)를 담아 본문 앞에 덧붙입니다.
    ///
    /// - Parameters:
    ///   - line: 줄바꿈이 제거된 단일 라인.
    ///   - baseFont: 본문 기본 폰트.
    /// - Returns: 본문 + 줄바꿈 속성이 캡슐화된 `MarkdownDeserializedBlock`.
    static func deserializeBlock(from line: String, baseFont: UIFont) -> MarkdownDeserializedBlock {
        var style = MarkdownInlineStyle()
        var markdownBody = line
        var literalPrefix = ""

        let lineNSString = line as NSString
        let lineRange = NSRange(location: 0, length: lineNSString.length)

        if let match = MarkdownRegex.h3.firstMatch(in: line, range: lineRange) {
            markdownBody = lineNSString.substring(from: match.range.length)
            style.fontSize = 17
            style.isBold = true
        } else if let match = MarkdownRegex.h2.firstMatch(in: line, range: lineRange) {
            markdownBody = lineNSString.substring(from: match.range.length)
            style.fontSize = 22
            style.isBold = true
        } else if let match = MarkdownRegex.h1.firstMatch(in: line, range: lineRange) {
            markdownBody = lineNSString.substring(from: match.range.length)
            style.fontSize = 28
            style.isBold = true
        } else if let match = MarkdownRegex.blockquote.firstMatch(in: line, range: lineRange) {
            markdownBody = lineNSString.substring(from: match.range.length)
            style.paragraphStyle = MarkdownAttributeBuilder.quoteParagraphStyle()
            style.isBlockquote = true
        } else if let match = MarkdownRegex.bulletList.firstMatch(in: line, range: lineRange) {
            markdownBody = lineNSString.substring(from: match.range.length)
            literalPrefix = "• "
        } else if let match = MarkdownRegex.dashList.firstMatch(in: line, range: lineRange) {
            markdownBody = lineNSString.substring(from: match.range.length)
            literalPrefix = "– "
        } else if let match = MarkdownRegex.numberList.firstMatch(in: line, range: lineRange) {
            let marker = lineNSString.substring(with: match.range(at: 1))
            markdownBody = lineNSString.substring(from: match.range.length)
            literalPrefix = "\(marker). "
        }

        let mutableAttributedString = NSMutableAttributedString()

        if !literalPrefix.isEmpty {
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
