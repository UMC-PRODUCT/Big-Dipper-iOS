//
//  MarkdownInlineParser.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation
import UIKit

// MARK: - MarkdownInlineParser

/// 한 줄 또는 한 토큰 내부의 **인라인** 마크다운 서식을 재귀적으로 해석하는 파서.
///
/// `MarkdownBlockParser` 가 블록 prefix 를 걷어낸 뒤 넘겨주는 본문에 대해,
/// "가장 먼저 등장하는 인라인 토큰" 을 찾아 순차적으로 소비하며 `NSAttributedString` 을 구성합니다.
/// 중첩 토큰(예: `**[링크](url)**`)은 자식 본문을 재귀 호출로 다시 파싱해 처리합니다.
enum MarkdownInlineParser {

    // MARK: - Function

    /// 인라인 마크다운 문자열을 `NSAttributedString` 으로 파싱합니다.
    ///
    /// ### 알고리즘
    /// 1. 남은 텍스트에서 가장 먼저 매칭되는 인라인 토큰을 탐색.
    /// 2. 토큰 앞부분(plain)은 `attributedPlainText` 로 추가.
    /// 3. 토큰 종류에 맞게 스타일을 복사/덧씌운 뒤 **재귀 호출**로 자식 본문 파싱.
    /// 4. 토큰 끝으로 커서 이동 후 반복.
    /// 5. 토큰이 더 이상 없으면 나머지 전부를 plain 으로 추가하고 종료.
    ///
    /// - Parameters:
    ///   - text: 인라인 본문(블록 prefix 제거 후).
    ///   - baseFont: 본문 기본 폰트.
    ///   - style: 상위 스타일(블록에서 전달된 bold/fontSize/blockquote 등).
    /// - Returns: 인라인 서식이 반영된 attributed string.
    static func parseInlineMarkdown(_ text: String, baseFont: UIFont, style: MarkdownInlineStyle) -> NSAttributedString {
        let mutableAttributedString = NSMutableAttributedString()
        let nsText = text as NSString
        var location = 0

        while location < nsText.length {
            let remainingRange = NSRange(location: location, length: nsText.length - location)
            let remainingText = nsText.substring(with: remainingRange)

            guard let token = earliestInlineToken(in: remainingText) else {
                let plainText = nsText.substring(from: location)
                mutableAttributedString.append(attributedPlainText(plainText, baseFont: baseFont, style: style))
                break
            }

            if token.match.range.location > 0 {
                let prefix = (remainingText as NSString).substring(to: token.match.range.location)
                mutableAttributedString.append(attributedPlainText(prefix, baseFont: baseFont, style: style))
            }

            switch token.kind {
            case .code:
                var codeStyle = style
                codeStyle.isMonospaced = true
                let rawCodeText = (remainingText as NSString).substring(with: token.match.range(at: 1))
                let codeText = MarkdownEscaping.unescapeCodeText(rawCodeText)
                mutableAttributedString.append(attributedPlainText(codeText, baseFont: baseFont, style: codeStyle))

            case .link:
                let label = (remainingText as NSString).substring(with: token.match.range(at: 1))
                let rawURL = (remainingText as NSString).substring(with: token.match.range(at: 2))
                var linkStyle = style
                if let url = URL(string: MarkdownEscaping.unescapeMarkdownText(rawURL)),
                   let scheme = url.scheme?.lowercased(),
                   ["https", "http", "mailto", "tel"].contains(scheme) {
                    linkStyle.linkURL = url
                }
                mutableAttributedString.append(parseInlineMarkdown(label, baseFont: baseFont, style: linkStyle))

            case .underline:
                var underlineStyle = style
                underlineStyle.isUnderlined = true
                let underlineText = (remainingText as NSString).substring(with: token.match.range(at: 1))
                mutableAttributedString.append(parseInlineMarkdown(underlineText, baseFont: baseFont, style: underlineStyle))

            case .highlight:
                var highlightStyle = style
                let colorRange = token.match.range(at: 1)
                let textRange = token.match.range(at: 2)
                if colorRange.location != NSNotFound,
                   let colorCode = Range(colorRange, in: remainingText).map({ String(remainingText[$0]) }),
                   let uiColor = MarkdownAttributeBuilder.uiColor(fromCode: colorCode) {
                    highlightStyle.highlightColor = uiColor
                } else {
                    highlightStyle.highlightColor = UIColor.yellow.withAlphaComponent(0.4)
                }
                let highlightText = (remainingText as NSString).substring(with: textRange)
                mutableAttributedString.append(parseInlineMarkdown(highlightText, baseFont: baseFont, style: highlightStyle))

            case .strikethrough:
                var strikeStyle = style
                strikeStyle.isStruck = true
                let strikeText = (remainingText as NSString).substring(with: token.match.range(at: 1))
                mutableAttributedString.append(parseInlineMarkdown(strikeText, baseFont: baseFont, style: strikeStyle))

            case .boldItalicMixed, .boldItalicStars:
                var boldItalicStyle = style
                boldItalicStyle.isBold = true
                boldItalicStyle.isItalic = true
                let boldItalicText = (remainingText as NSString).substring(with: token.match.range(at: 1))
                mutableAttributedString.append(parseInlineMarkdown(boldItalicText, baseFont: baseFont, style: boldItalicStyle))

            case .bold:
                var boldStyle = style
                boldStyle.isBold = true
                let boldText = (remainingText as NSString).substring(with: token.match.range(at: 1))
                mutableAttributedString.append(parseInlineMarkdown(boldText, baseFont: baseFont, style: boldStyle))

            case .italicAsterisk, .italicUnderscore:
                var italicStyle = style
                italicStyle.isItalic = true
                let italicText = (remainingText as NSString).substring(with: token.match.range(at: 1))
                mutableAttributedString.append(parseInlineMarkdown(italicText, baseFont: baseFont, style: italicStyle))
            }

            location += NSMaxRange(token.match.range)
        }

        return mutableAttributedString
    }

    /// 등록된 모든 인라인 패턴을 시도해 가장 이른 위치에 매칭되는 토큰을 찾습니다.
    ///
    /// 같은 위치에 여러 패턴이 매칭되면 `MarkdownRegex.inlinePatterns` 의 선언 순서를 따르며,
    /// 이는 사실상 우선순위를 의미합니다(예: `boldItalic` > `bold` > `italic`).
    ///
    /// - Parameter text: 검색 대상 텍스트.
    /// - Returns: 가장 먼저 등장하는 토큰, 없으면 `nil`.
    static func earliestInlineToken(in text: String) -> MarkdownInlineToken? {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        var earliestToken: MarkdownInlineToken?

        for (kind, regex) in MarkdownRegex.inlinePatterns {
            guard let match = regex.firstMatch(in: text, range: fullRange) else {
                continue
            }

            let candidate = MarkdownInlineToken(kind: kind, match: match)

            if let currentToken = earliestToken {
                if match.range.location < currentToken.match.range.location {
                    earliestToken = candidate
                }
            } else {
                earliestToken = candidate
            }
        }

        return earliestToken
    }

    /// plain text 구간을 속성과 함께 `NSAttributedString` 으로 감쌉니다.
    ///
    /// 이 단계에서 `unescapeMarkdownText` 를 호출해 사용자가 문자 그대로 보기 원했던
    /// `\*`, `\_` 등의 백슬래시를 걷어냅니다.
    ///
    /// - Parameters:
    ///   - text: raw plain text (escape 포함).
    ///   - baseFont: 본문 기본 폰트.
    ///   - style: 현재 인라인 스타일.
    /// - Returns: 서식이 적용된 attributed string.
    static func attributedPlainText(_ text: String, baseFont: UIFont, style: MarkdownInlineStyle) -> NSAttributedString {
        NSAttributedString(
            string: MarkdownEscaping.unescapeMarkdownText(text),
            attributes: MarkdownAttributeBuilder.attributes(for: style, baseFont: baseFont)
        )
    }
}
