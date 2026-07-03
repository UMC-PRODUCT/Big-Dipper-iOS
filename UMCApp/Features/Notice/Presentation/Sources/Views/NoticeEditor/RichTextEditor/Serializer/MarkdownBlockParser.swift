//
//  MarkdownBlockParser.swift
//  NoticePresentation
//
//  Created by 이예지 on 6/30/26.
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
public enum MarkdownBlockParser {

    // MARK: - Function

    /// 마크다운 전체 문자열을 `NSAttributedString` 으로 역직렬화합니다.
    ///
    /// - Parameters:
    ///   - markdown: 마크다운 원본.
    ///   - baseFont: 본문 기본 폰트(헤딩이 아닌 줄에 적용).
    /// - Returns: 에디터/미리보기에 표시 가능한 attributed string.
    public static func deserialize(_ markdown: String, baseFont: UIFont) -> NSAttributedString {
        let normalizedMarkdown = normalizeSpacePaddedInlineTokens(
            markdown
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
        )
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

    /// 마커 안쪽에 공백이 붙어 파서가 거부하는 레거시 인라인 토큰을 정규화합니다.
    ///
    /// 과거 직렬화기는 run 양끝 공백을 마커 안쪽에 둔 채 래핑해(`**일시: **`) 인라인
    /// 정규식의 `(?=\S)...(?<=\S)` 가드에 걸리는 마크다운을 생성했습니다. 저장된 공지를
    /// 구제하기 위해 공백을 마커 밖으로 옮기고(`**일시:** `), 공백만 감싼 토큰은 마커를
    /// 제거합니다.
    ///
    /// - Note: 단일 `*`/`_` (이탤릭) 토큰은 정규화하지 않습니다. 일반 텍스트의 낱개 `*` 와
    ///   구문상 구분이 불가능해 본문을 훼손할 수 있기 때문입니다. 이탤릭은 쓰기 측
    ///   (`MarkdownInlineSerializer`) 수정으로 신규 콘텐츠부터 올바르게 직렬화됩니다.
    ///
    /// - Parameter markdown: 개행 정규화가 끝난 마크다운 원본.
    /// - Returns: 공백 인접 bold/strikethrough 토큰이 정규화된 마크다운.
    public static func normalizeSpacePaddedInlineTokens(_ markdown: String) -> String {
        var result = markdown

        let replacements: [(NSRegularExpression, String)] = [
            (MarkdownRegex.spaceOnlyBold, "$1"),
            (MarkdownRegex.spaceOnlyStrikethrough, "$1"),
            (MarkdownRegex.spacePaddedBold, "$1**$2**$3"),
            (MarkdownRegex.spacePaddedStrikethrough, "$1~~$2~~$3"),
        ]

        for (regex, template) in replacements {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(location: 0, length: (result as NSString).length),
                withTemplate: template
            )
        }

        return result
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
    public static func deserializeBlock(from line: String, baseFont: UIFont) -> MarkdownDeserializedBlock {
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
