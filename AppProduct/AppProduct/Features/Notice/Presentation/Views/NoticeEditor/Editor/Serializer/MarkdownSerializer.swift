//
//  MarkdownSerializer.swift
//  AppProduct
//
//  Created by euijjang97 on 4/8/26.
//

import Foundation
import UIKit

enum MarkdownSerializer {

    // MARK: - Serialize

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
            line.append(serializeInline(attributedString, range: blockContext.inlineRange))

            if blockContext.markdownPrefix.isEmpty {
                line = escapeLeadingBlockSyntax(in: line)
            }

            markdown.append(line)
            markdown.append(nsString.substring(with: trailingRange))
            location = NSMaxRange(paragraphRange)
        }

        return markdown
    }

    // MARK: - Plain Text

    /// 마크다운 문자열에서 모든 서식을 제거하고 plain text를 반환합니다.
    static func plainText(from markdown: String) -> String {
        deserialize(markdown, baseFont: UIFont.preferredFont(forTextStyle: .body)).string
    }

    // MARK: - Deserialize

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

    // MARK: - Helpers

    private struct BlockContext {
        let markdownPrefix: String
        let inlineRange: NSRange
    }

    private struct DeserializedBlock {
        let content: NSAttributedString
        let newlineAttributes: [NSAttributedString.Key: Any]
    }

    private struct InlineStyle {
        var isBold = false
        var isItalic = false
        var isUnderlined = false
        var isStruck = false
        var isMonospaced = false
        var highlightColor: UIColor?
        var linkURL: URL?
        var fontSize: CGFloat?
        var paragraphStyle: NSParagraphStyle?
    }

    private enum InlineTokenKind {
        case code
        case link
        case underline
        case strikethrough
        case highlight
        case boldItalicMixed
        case boldItalicStars
        case bold
        case italicAsterisk
        case italicUnderscore
    }

    private struct InlineToken {
        let kind: InlineTokenKind
        let match: NSTextCheckingResult
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

    private static func blockContext(for attributedString: NSAttributedString, contentRange: NSRange) -> BlockContext {
        let paragraphString = attributedString.attributedSubstring(from: contentRange).string as NSString
        let fullLength = paragraphString.length

        if let match = try? NSRegularExpression(pattern: "^•\\s+")
            .firstMatch(in: paragraphString as String, range: NSRange(location: 0, length: fullLength)) {
            // Bullet prefix • → - 텍스트
            return BlockContext(
                markdownPrefix: "- ",
                inlineRange: NSRange(location: contentRange.location + match.range.length, length: contentRange.length - match.range.length)
            )
        }

        if let match = try? NSRegularExpression(pattern: "^–\\s+")
            .firstMatch(in: paragraphString as String, range: NSRange(location: 0, length: fullLength)) {
            // Dash prefix – → – 텍스트
            return BlockContext(
                markdownPrefix: "– ",
                inlineRange: NSRange(location: contentRange.location + match.range.length, length: contentRange.length - match.range.length)
            )
        }

        if let match = try? NSRegularExpression(pattern: "^(\\d+)\\.\\s+")
            .firstMatch(in: paragraphString as String, range: NSRange(location: 0, length: fullLength)) {
            let marker = paragraphString.substring(with: match.range(at: 1))

            // Number prefix 숫자. → 1. 텍스트
            return BlockContext(
                markdownPrefix: "\(marker). ",
                inlineRange: NSRange(location: contentRange.location + match.range.length, length: contentRange.length - match.range.length)
            )
        }

        guard let firstContentOffset = firstNonWhitespaceOffset(in: paragraphString as String) else {
            return BlockContext(markdownPrefix: "", inlineRange: contentRange)
        }

        let firstContentLocation = contentRange.location + firstContentOffset
        let paragraphStyle = attributedString.attribute(.paragraphStyle, at: firstContentLocation, effectiveRange: nil) as? NSParagraphStyle
        let font = attributedString.attribute(.font, at: firstContentLocation, effectiveRange: nil) as? UIFont

        if let paragraphStyle, paragraphStyle.headIndent > 0 {
            // 인용구 (headIndent > 0) → > 텍스트
            return BlockContext(markdownPrefix: "> ", inlineRange: contentRange)
        }

        if let font, abs(font.pointSize - 28) < 0.5 {
            // 단락 스타일 title (28pt) → # 텍스트
            return BlockContext(markdownPrefix: "# ", inlineRange: contentRange)
        }

        if let font, abs(font.pointSize - 22) < 0.5 {
            // 단락 스타일 heading (22pt) → ## 텍스트
            return BlockContext(markdownPrefix: "## ", inlineRange: contentRange)
        }

        if let font,
           abs(font.pointSize - 17) < 0.5,
           font.fontDescriptor.symbolicTraits.contains(.traitBold),
           isEntireParagraphUniform(in: attributedString, range: contentRange) {
            // 단락 스타일 subheading (17pt) → ### 텍스트
            return BlockContext(markdownPrefix: "### ", inlineRange: contentRange)
        }

        return BlockContext(markdownPrefix: "", inlineRange: contentRange)
    }

    private static func firstNonWhitespaceOffset(in text: String) -> Int? {
        let nsText = text as NSString
        let range = nsText.rangeOfCharacter(from: CharacterSet.whitespaces.inverted)

        guard range.location != NSNotFound else {
            return nil
        }

        return range.location
    }

    private static func isEntireParagraphUniform(in attributedString: NSAttributedString, range: NSRange) -> Bool {
        var attributesCount = 0

        attributedString.enumerateAttributes(in: range) { attributes, effectiveRange, _ in
            let substring = attributedString.attributedSubstring(from: effectiveRange).string

            guard substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                return
            }

            attributesCount += 1

            if attributesCount > 1 {
                return
            }

            if attributes[.link] != nil || (attributes[.underlineStyle] as? NSNumber)?.intValue ?? 0 != 0 {
                attributesCount += 1
            }
        }

        return attributesCount <= 1
    }

    private static func serializeInline(_ attributedString: NSAttributedString, range: NSRange) -> String {
        guard range.length > 0 else {
            return ""
        }

        var markdown = ""

        attributedString.enumerateAttributes(in: range) { attributes, effectiveRange, _ in
            let text = attributedString.attributedSubstring(from: effectiveRange).string

            guard text.isEmpty == false else {
                return
            }

            markdown.append(serializeSegment(text: text, attributes: attributes))
        }

        return markdown
    }

    private static func serializeSegment(text: String, attributes: [NSAttributedString.Key: Any]) -> String {
        let font = attributes[.font] as? UIFont
        let traits = font?.fontDescriptor.symbolicTraits ?? []
        let isBold = traits.contains(.traitBold)
        let isItalic = traits.contains(.traitItalic)
        let isMonospaced = traits.contains(.traitMonoSpace) || font?.familyName.lowercased().contains("mono") == true
        let isUnderlined = (attributes[.underlineStyle] as? NSNumber)?.intValue ?? 0 != 0
        let isStruck = (attributes[.strikethroughStyle] as? NSNumber)?.intValue ?? 0 != 0
        let highlightColor = attributes[.backgroundColor] as? UIColor
        let linkValue = attributes[.link]

        var content = escapeMarkdownText(text)

        if isMonospaced {
            // mono font → `텍스트`
            content = "`\(escapeMarkdownCodeText(text))`"
        } else if isBold && isItalic {
            // Bold + Italic → **_텍스트_**
            content = "**_\(content)_**"
        } else {
            if isBold {
                // Bold (traits .bold) → **텍스트**
                content = "**\(content)**"
            }

            if isItalic {
                // Italic (traits .italic) → *텍스트*
                content = "*\(content)*"
            }
        }

        if isUnderlined && isMonospaced == false {
            // Underline → <u>텍스트</u>
            content = "<u>\(content)</u>"
        }

        if isStruck && isMonospaced == false {
            // Strikethrough → ~~텍스트~~
            content = "~~\(content)~~"
        }

        if let highlightColor, isMonospaced == false {
            // Highlight → <mark color="R,G,B,A">텍스트</mark>
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            highlightColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            let colorCode = String(format: "%.3f,%.3f,%.3f,%.3f", r, g, b, a)
            content = "<mark color=\"\(colorCode)\">\(content)</mark>"
        }

        if let linkValue {
            let urlString: String

            if let url = linkValue as? URL {
                urlString = url.absoluteString
            } else {
                urlString = String(describing: linkValue)
            }

            // NSLinkAttributeName → [텍스트](url)
            content = "[\(content)](\(urlString))"
        }

        return content
    }

    private static func escapeMarkdownText(_ text: String) -> String {
        var escaped = ""

        for character in text {
            if "\\*_[]()~`".contains(character) {
                escaped.append("\\")
            }

            escaped.append(character)
        }

        return escaped
    }

    private static func escapeMarkdownCodeText(_ text: String) -> String {
        var escaped = ""

        for character in text {
            if character == "\\" || character == "`" {
                escaped.append("\\")
            }

            escaped.append(character)
        }

        return escaped
    }

    private static func escapeLeadingBlockSyntax(in line: String) -> String {
        if line.hasPrefix("### ") || line.hasPrefix("## ") || line.hasPrefix("# ") {
            return "\\\(line)"
        }

        if line.hasPrefix("> ") || line.hasPrefix("- ") || line.hasPrefix("– ") {
            return "\\\(line)"
        }

        guard let match = try? NSRegularExpression(pattern: "^(\\d+)\\.\\s+")
            .firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) else {
            return line
        }

        let nsLine = line as NSString
        let marker = nsLine.substring(with: match.range(at: 1))
        let remainder = nsLine.substring(from: match.range.length)
        return "\(marker)\\. \(remainder)"
    }

    private static func deserializeBlock(from line: String, baseFont: UIFont) -> DeserializedBlock {
        var style = InlineStyle()
        var markdownBody = line
        var literalPrefix = ""

        if let match = try? NSRegularExpression(pattern: "^###\\s+")
            .firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) {
            // ### 텍스트 → 단락 스타일 subheading (17pt)
            markdownBody = (line as NSString).substring(from: match.range.length)
            style.fontSize = 17
            style.isBold = true
        } else if let match = try? NSRegularExpression(pattern: "^##\\s+")
            .firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) {
            // ## 텍스트 → 단락 스타일 heading (22pt)
            markdownBody = (line as NSString).substring(from: match.range.length)
            style.fontSize = 22
            style.isBold = true
        } else if let match = try? NSRegularExpression(pattern: "^#\\s+")
            .firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) {
            // # 텍스트 → 단락 스타일 title (28pt)
            markdownBody = (line as NSString).substring(from: match.range.length)
            style.fontSize = 28
            style.isBold = true
        } else if let match = try? NSRegularExpression(pattern: "^>\\s+")
            .firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) {
            // > 텍스트 → 인용구 (headIndent > 0)
            markdownBody = (line as NSString).substring(from: match.range.length)
            style.paragraphStyle = quoteParagraphStyle()
        } else if let match = try? NSRegularExpression(pattern: "^-\\s+")
            .firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) {
            // - 텍스트 → bullet prefix •
            markdownBody = (line as NSString).substring(from: match.range.length)
            literalPrefix = "• "
        } else if let match = try? NSRegularExpression(pattern: "^–\\s+")
            .firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) {
            // – 텍스트 → dash prefix –
            markdownBody = (line as NSString).substring(from: match.range.length)
            literalPrefix = "– "
        } else if let match = try? NSRegularExpression(pattern: "^(\\d+)\\.\\s+")
            .firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) {
            // 1. 텍스트 → number prefix 숫자.
            let marker = (line as NSString).substring(with: match.range(at: 1))
            markdownBody = (line as NSString).substring(from: match.range.length)
            literalPrefix = "\(marker). "
        }

        let mutableAttributedString = NSMutableAttributedString()

        if literalPrefix.isEmpty == false {
            mutableAttributedString.append(NSAttributedString(
                string: literalPrefix,
                attributes: attributes(for: style, baseFont: baseFont)
            ))
        }

        mutableAttributedString.append(parseInlineMarkdown(markdownBody, baseFont: baseFont, style: style))

        return DeserializedBlock(
            content: mutableAttributedString,
            newlineAttributes: attributes(for: style, baseFont: baseFont)
        )
    }

    private static func parseInlineMarkdown(_ text: String, baseFont: UIFont, style: InlineStyle) -> NSAttributedString {
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
                // `텍스트` → mono font
                var codeStyle = style
                codeStyle.isMonospaced = true
                let codeText = (remainingText as NSString).substring(with: token.match.range(at: 1))
                mutableAttributedString.append(attributedPlainText(codeText, baseFont: baseFont, style: codeStyle))

            case .link:
                // [텍스트](url) → NSLinkAttributeName
                let label = (remainingText as NSString).substring(with: token.match.range(at: 1))
                let rawURL = (remainingText as NSString).substring(with: token.match.range(at: 2))
                var linkStyle = style
                linkStyle.linkURL = URL(string: rawURL)
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
                   let uiColor = uiColor(fromCode: colorCode) {
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

    private static func earliestInlineToken(in text: String) -> InlineToken? {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let patterns: [(InlineTokenKind, String)] = [
            (.code, "(?<!\\\\)`([^`\\n]+)`"),
            (.link, "(?<!\\\\)\\[([^\\n\\]]+?)\\]\\(([^)\\n]+?)\\)"),
            (.underline, "(?<!\\\\)<u>(.+?)</u>"),
            (.strikethrough, "(?<!\\\\)~~(?=\\S)(.+?)(?<=\\S)~~"),
            (.highlight, "<mark(?:\\s+color=\"([^\"]*)\")?>(.+?)</mark>"),
            (.boldItalicMixed, "(?<!\\\\)\\*\\*_(.+?)_\\*\\*"),
            (.boldItalicStars, "(?<!\\\\)\\*\\*\\*(.+?)\\*\\*\\*"),
            (.bold, "(?<!\\\\)\\*\\*(?=\\S)(.+?)(?<=\\S)\\*\\*"),
            (.italicAsterisk, "(?<!\\\\)(?<!\\*)\\*(?=\\S)(.+?)(?<=\\S)\\*(?!\\*)"),
            (.italicUnderscore, "(?<!\\\\)(?<!_)_(?=\\S)(.+?)(?<=\\S)_(?!_)"),
        ]

        var earliestToken: InlineToken?

        for (kind, pattern) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
                  let match = regex.firstMatch(in: text, range: fullRange) else {
                continue
            }

            let candidate = InlineToken(kind: kind, match: match)

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

    private static func attributedPlainText(_ text: String, baseFont: UIFont, style: InlineStyle) -> NSAttributedString {
        NSAttributedString(string: unescapeMarkdownText(text), attributes: attributes(for: style, baseFont: baseFont))
    }

    private static func unescapeMarkdownText(_ text: String) -> String {
        var unescaped = ""
        var isEscaping = false

        for character in text {
            if isEscaping {
                unescaped.append(character)
                isEscaping = false
                continue
            }

            if character == "\\" {
                isEscaping = true
                continue
            }

            unescaped.append(character)
        }

        if isEscaping {
            unescaped.append("\\")
        }

        return unescaped
    }

    private static func attributes(for style: InlineStyle, baseFont: UIFont) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font(for: style, baseFont: baseFont),
        ]

        if style.isUnderlined {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        if style.isStruck {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        if let highlightColor = style.highlightColor {
            attributes[.backgroundColor] = highlightColor
        }

        if let paragraphStyle = style.paragraphStyle {
            attributes[.paragraphStyle] = paragraphStyle
        }

        if let linkURL = style.linkURL {
            attributes[.link] = linkURL
        }

        return attributes
    }

    private static func uiColor(fromCode code: String) -> UIColor? {
        let parts = code.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 4 else { return nil }
        return UIColor(red: CGFloat(parts[0]), green: CGFloat(parts[1]), blue: CGFloat(parts[2]), alpha: CGFloat(parts[3]))
    }

    private static func font(for style: InlineStyle, baseFont: UIFont) -> UIFont {
        let pointSize = style.fontSize ?? baseFont.pointSize

        if style.isMonospaced {
            var monospacedFont = UIFont.monospacedSystemFont(
                ofSize: pointSize,
                weight: style.isBold ? .bold : fontWeight(from: baseFont)
            )

            if style.isItalic {
                var traits = monospacedFont.fontDescriptor.symbolicTraits
                traits.insert(.traitItalic)

                if let descriptor = monospacedFont.fontDescriptor.withSymbolicTraits(traits) {
                    monospacedFont = UIFont(descriptor: descriptor, size: pointSize)
                }
            }

            return monospacedFont
        }

        var traits = UIFontDescriptor.SymbolicTraits()

        if style.isBold {
            traits.insert(.traitBold)
        }

        if style.isItalic {
            traits.insert(.traitItalic)
        }

        let descriptor = baseFont.fontDescriptor.withSize(pointSize)

        if let styledDescriptor = descriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: styledDescriptor, size: pointSize)
        }

        if style.isBold && style.isItalic {
            let fallbackDescriptor = UIFont.systemFont(ofSize: pointSize, weight: .bold).fontDescriptor
            let italicTraits = fallbackDescriptor.symbolicTraits.union(.traitItalic)

            if let italicDescriptor = fallbackDescriptor.withSymbolicTraits(italicTraits) {
                return UIFont(descriptor: italicDescriptor, size: pointSize)
            }
        }

        if style.isBold {
            return UIFont.systemFont(ofSize: pointSize, weight: .bold)
        }

        if style.isItalic {
            return UIFont.italicSystemFont(ofSize: pointSize)
        }

        return baseFont.withSize(pointSize)
    }

    private static func fontWeight(from font: UIFont) -> UIFont.Weight {
        let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
        let rawWeight = traits?[.weight] as? CGFloat ?? UIFont.Weight.regular.rawValue
        return UIFont.Weight(rawValue: rawWeight)
    }

    private static func quoteParagraphStyle() -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = 16
        paragraphStyle.headIndent = 16
        return paragraphStyle
    }
}
