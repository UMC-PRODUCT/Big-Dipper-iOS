//
//  MarkdownInlineParser.swift
//  AppProduct
//
//  Created by euijjang97 on 4/8/26.
//

import Foundation
import UIKit

// MARK: - MarkdownInlineParser

enum MarkdownInlineParser {

    // MARK: - Function

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
                // `텍스트` → mono font (백슬래시 이스케이프 제거 후 적용)
                var codeStyle = style
                codeStyle.isMonospaced = true
                let rawCodeText = (remainingText as NSString).substring(with: token.match.range(at: 1))
                let codeText = MarkdownEscaping.unescapeCodeText(rawCodeText)
                mutableAttributedString.append(attributedPlainText(codeText, baseFont: baseFont, style: codeStyle))

            case .link:
                // [텍스트](url) → NSLinkAttributeName (허용 scheme: https, http, mailto, tel)
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
                // <u>텍스트</u> → Underline
                var underlineStyle = style
                underlineStyle.isUnderlined = true
                let underlineText = (remainingText as NSString).substring(with: token.match.range(at: 1))
                mutableAttributedString.append(parseInlineMarkdown(underlineText, baseFont: baseFont, style: underlineStyle))

            case .highlight:
                // <mark color="R,G,B,A">텍스트</mark> → backgroundColor
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
                // ~~텍스트~~ → Strikethrough
                var strikeStyle = style
                strikeStyle.isStruck = true
                let strikeText = (remainingText as NSString).substring(with: token.match.range(at: 1))
                mutableAttributedString.append(parseInlineMarkdown(strikeText, baseFont: baseFont, style: strikeStyle))

            case .boldItalicMixed, .boldItalicStars:
                // **_텍스트_** / ***텍스트*** → Bold + Italic
                var boldItalicStyle = style
                boldItalicStyle.isBold = true
                boldItalicStyle.isItalic = true
                let boldItalicText = (remainingText as NSString).substring(with: token.match.range(at: 1))
                mutableAttributedString.append(parseInlineMarkdown(boldItalicText, baseFont: baseFont, style: boldItalicStyle))

            case .bold:
                // **텍스트** → Bold
                var boldStyle = style
                boldStyle.isBold = true
                let boldText = (remainingText as NSString).substring(with: token.match.range(at: 1))
                mutableAttributedString.append(parseInlineMarkdown(boldText, baseFont: baseFont, style: boldStyle))

            case .italicAsterisk, .italicUnderscore:
                // *텍스트* / _텍스트_ → Italic
                var italicStyle = style
                italicStyle.isItalic = true
                let italicText = (remainingText as NSString).substring(with: token.match.range(at: 1))
                mutableAttributedString.append(parseInlineMarkdown(italicText, baseFont: baseFont, style: italicStyle))
            }

            location += NSMaxRange(token.match.range)
        }

        return mutableAttributedString
    }

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

    static func attributedPlainText(_ text: String, baseFont: UIFont, style: MarkdownInlineStyle) -> NSAttributedString {
        NSAttributedString(
            string: MarkdownEscaping.unescapeMarkdownText(text),
            attributes: MarkdownAttributeBuilder.attributes(for: style, baseFont: baseFont)
        )
    }
}
