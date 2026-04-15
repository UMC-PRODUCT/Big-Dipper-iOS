//
//  MarkdownSerializer.swift
//  AppProduct
//
//  Created by euijjang97 on 4/8/26.
//

import Foundation
import UIKit

enum MarkdownSerializer {

    // MARK: - Cached Regex

    // blockContext 정규식
    private static let bulletPrefixRegex = try! NSRegularExpression(pattern: "^•\\s+")
    private static let dashPrefixRegex = try! NSRegularExpression(pattern: "^–\\s+")
    private static let numberPrefixRegex = try! NSRegularExpression(pattern: "^(\\d+)\\.\\s+")

    // deserializeBlock 정규식
    private static let h3Regex = try! NSRegularExpression(pattern: "^###\\s+")
    private static let h2Regex = try! NSRegularExpression(pattern: "^##\\s+")
    private static let h1Regex = try! NSRegularExpression(pattern: "^#\\s+")
    private static let blockquoteRegex = try! NSRegularExpression(pattern: "^>\\s+")
    private static let bulletListRegex = try! NSRegularExpression(pattern: "^-\\s+")
    private static let dashListRegex = try! NSRegularExpression(pattern: "^–\\s+")
    private static let numberListRegex = try! NSRegularExpression(pattern: "^(\\d+)\\.\\s+")

    // escapeLeadingBlockSyntax 정규식
    private static let leadingNumberRegex = try! NSRegularExpression(pattern: "^(\\d+)\\.\\s+")

    // earliestInlineToken 정규식
    private static let inlinePatterns: [(InlineTokenKind, NSRegularExpression)] = {
        let patterns: [(InlineTokenKind, String)] = [
            (.code, "(?<!\\\\)`((?:\\\\.|[^`\\n])+?)`"),
            (.link, "(?<!\\\\)\\[((?:\\\\.|[^\\]\\n])+?)\\]\\(((?:\\\\.|[^)\\n])+?)\\)"),
            (.underline, "(?<!\\\\)<u>(.+?)</u>"),
            (.strikethrough, "(?<!\\\\)~~(?=\\S)(.+?)(?<=\\S)~~"),
            (.highlight, "(?<!\\\\)<mark(?:\\s+color=\"([^\"]*)\")?>(.+?)</mark>"),
            (.boldItalicMixed, "(?<!\\\\)\\*\\*_(.+?)_\\*\\*"),
            (.boldItalicStars, "(?<!\\\\)\\*\\*\\*(.+?)\\*\\*\\*"),
            (.bold, "(?<!\\\\)\\*\\*(?=\\S)(.+?)(?<=\\S)\\*\\*"),
            (.italicAsterisk, "(?<!\\\\)(?<!\\*)\\*(?=\\S)(.+?)(?<=\\S)\\*(?!\\*)"),
            (.italicUnderscore, "(?<!\\\\)(?<!_)_(?=\\S)(.+?)(?<=\\S)_(?!_)"),
        ]
        return patterns.compactMap { kind, pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
                return nil
            }
            return (kind, regex)
        }
    }()

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
            line.append(serializeInline(attributedString, range: blockContext.inlineRange, blockImpliedBold: blockContext.blockImpliedBold))

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

    // MARK: - Display Rendering

    /// 서버에서 받은 마크다운 문자열을 화면 표시용 NSAttributedString으로 변환합니다.
    ///
    /// `deserialize`와 동일하게 동작합니다. 백슬래시 이스케이프는 파서 내부의
    /// `unescapeMarkdownText`가 plain text 구간에서만 제거하므로
    /// `\*\*not bold\*\*`는 서식 없이 `**not bold**`로 표시되고,
    /// `**bold**`는 볼드로 올바르게 렌더링됩니다.
    static func deserializeForDisplay(_ markdown: String, baseFont: UIFont) -> NSAttributedString {
        return deserialize(markdown, baseFont: baseFont)
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
        let blockImpliedBold: Bool
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
        var isBlockquote = false
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

        guard let firstContentOffset = firstNonWhitespaceOffset(in: paragraphString as String) else {
            return BlockContext(markdownPrefix: "", inlineRange: contentRange, blockImpliedBold: false)
        }

        let firstContentLocation = contentRange.location + firstContentOffset
        let font = attributedString.attribute(.font, at: firstContentLocation, effectiveRange: nil) as? UIFont

        // 속성 기반 판별을 텍스트 prefix보다 먼저 수행 (제목/인용구가 목록처럼 보이는 텍스트로 시작해도 안전)
        let isBlockquote = (attributedString.attribute(.editorBlockquote, at: firstContentLocation, effectiveRange: nil) as? Bool) == true
        if isBlockquote {
            // 인용구 (.editorBlockquote attribute) → > 텍스트
            return BlockContext(markdownPrefix: "> ", inlineRange: contentRange, blockImpliedBold: false)
        }

        if let font, abs(font.pointSize - 28) < 0.5 {
            // 단락 스타일 title (28pt) → # 텍스트
            return BlockContext(markdownPrefix: "# ", inlineRange: contentRange, blockImpliedBold: true)
        }

        if let font, abs(font.pointSize - 22) < 0.5 {
            // 단락 스타일 heading (22pt) → ## 텍스트
            return BlockContext(markdownPrefix: "## ", inlineRange: contentRange, blockImpliedBold: true)
        }

        if let font,
           abs(font.pointSize - 17) < 0.5,
           font.fontDescriptor.symbolicTraits.contains(.traitBold),
           isParagraphDominantlySubheading(in: attributedString, range: contentRange) {
            // 단락 스타일 subheading (17pt) → ### 텍스트
            return BlockContext(markdownPrefix: "### ", inlineRange: contentRange, blockImpliedBold: true)
        }

        // 텍스트 prefix 기반 목록 판별 (속성 판별 이후)
        if let match = bulletPrefixRegex
            .firstMatch(in: paragraphString as String, range: NSRange(location: 0, length: fullLength)) {
            // Bullet prefix • → - 텍스트
            return BlockContext(
                markdownPrefix: "- ",
                inlineRange: NSRange(location: contentRange.location + match.range.length, length: contentRange.length - match.range.length),
                blockImpliedBold: false
            )
        }

        if let match = dashPrefixRegex
            .firstMatch(in: paragraphString as String, range: NSRange(location: 0, length: fullLength)) {
            // Dash prefix – → – 텍스트
            return BlockContext(
                markdownPrefix: "– ",
                inlineRange: NSRange(location: contentRange.location + match.range.length, length: contentRange.length - match.range.length),
                blockImpliedBold: false
            )
        }

        if let match = numberPrefixRegex
            .firstMatch(in: paragraphString as String, range: NSRange(location: 0, length: fullLength)) {
            let marker = paragraphString.substring(with: match.range(at: 1))

            // Number prefix 숫자. → 1. 텍스트
            return BlockContext(
                markdownPrefix: "\(marker). ",
                inlineRange: NSRange(location: contentRange.location + match.range.length, length: contentRange.length - match.range.length),
                blockImpliedBold: false
            )
        }

        return BlockContext(markdownPrefix: "", inlineRange: contentRange, blockImpliedBold: false)
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

    private static func serializeInline(_ attributedString: NSAttributedString, range: NSRange, blockImpliedBold: Bool = false) -> String {
        guard range.length > 0 else {
            return ""
        }

        var markdown = ""

        attributedString.enumerateAttributes(in: range) { attributes, effectiveRange, _ in
            let text = attributedString.attributedSubstring(from: effectiveRange).string

            guard text.isEmpty == false else {
                return
            }

            markdown.append(serializeSegment(text: text, attributes: attributes, blockImpliedBold: blockImpliedBold))
        }

        return markdown
    }

    private static func serializeSegment(text: String, attributes: [NSAttributedString.Key: Any], blockImpliedBold: Bool = false) -> String {
        let font = attributes[.font] as? UIFont
        let traits = font?.fontDescriptor.symbolicTraits ?? []
        // 헤딩/부머리말 블록은 폰트 자체가 bold이므로, 블록 레벨에서 이미 implied된 bold는 인라인 ** 마커로 이중 래핑하지 않는다.
        // Pretendard는 커스텀 폰트라 symbolic trait보다 폰트명으로 bold를 판별하는 편이 더 신뢰할 수 있습니다.
        let isBold: Bool
        if let font, font.fontName.hasPrefix("Pretendard") {
            isBold = (font.fontName.contains("Bold") || font.fontName.contains("SemiBold")) && !blockImpliedBold
        } else {
            isBold = traits.contains(.traitBold) && !blockImpliedBold
        }
        // Pretendard는 italic 변형이 없어 oblique matrix로 기울임을 표현하므로 matrix.c 값도 함께 확인합니다.
        let isItalic: Bool
        if let font, font.fontName.hasPrefix("Pretendard") {
            isItalic = font.fontDescriptor.matrix.c != 0.0
        } else {
            isItalic = traits.contains(.traitItalic)
        }
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
            // Dynamic/grayscale color는 sRGB 변환 실패 가능 → resolvedColor fallback 후 재시도, 둘 다 실패하면 skip
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            let didConvert: Bool
            if highlightColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
                didConvert = true
            } else {
                let resolved = highlightColor.resolvedColor(with: UITraitCollection.current)
                didConvert = resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
            }
            if didConvert {
                let colorCode = String(format: "%.3f,%.3f,%.3f,%.3f", r, g, b, a)
                content = "<mark color=\"\(colorCode)\">\(content)</mark>"
            }
        }

        if let linkValue {
            let rawURLString: String

            if let url = linkValue as? URL {
                rawURLString = url.absoluteString
            } else {
                rawURLString = String(describing: linkValue)
            }

            // NSLinkAttributeName → [텍스트](url) (`)`, `\` escape)
            let escapedURL = escapeMarkdownLinkDestination(rawURLString)
            content = "[\(content)](\(escapedURL))"
        }

        return content
    }

    private static func escapeMarkdownText(_ text: String) -> String {
        var escaped = ""

        for character in text {
            // '<', '>' 포함: 사용자가 입력한 </u>, </mark> 등이 deserialize 시 닫는 태그로 오파싱되는 것을 방지
            if "\\*_[]()~`<>".contains(character) {
                escaped.append("\\")
            }

            escaped.append(character)
        }

        return escaped
    }

    /// 링크 URL destination에서 `)`, `\`를 escape합니다.
    private static func escapeMarkdownLinkDestination(_ url: String) -> String {
        var escaped = ""
        for character in url {
            if character == ")" || character == "\\" {
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

        guard let match = leadingNumberRegex
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

        let lineNSString = line as NSString
        let lineRange = NSRange(location: 0, length: lineNSString.length)

        if let match = h3Regex.firstMatch(in: line, range: lineRange) {
            // ### 텍스트 → 단락 스타일 subheading (17pt)
            markdownBody = lineNSString.substring(from: match.range.length)
            style.fontSize = 17
            style.isBold = true
        } else if let match = h2Regex.firstMatch(in: line, range: lineRange) {
            // ## 텍스트 → 단락 스타일 heading (22pt)
            markdownBody = lineNSString.substring(from: match.range.length)
            style.fontSize = 22
            style.isBold = true
        } else if let match = h1Regex.firstMatch(in: line, range: lineRange) {
            // # 텍스트 → 단락 스타일 title (28pt)
            markdownBody = lineNSString.substring(from: match.range.length)
            style.fontSize = 28
            style.isBold = true
        } else if let match = blockquoteRegex.firstMatch(in: line, range: lineRange) {
            // > 텍스트 → 인용구 (headIndent > 0 + .editorBlockquote attribute)
            markdownBody = lineNSString.substring(from: match.range.length)
            style.paragraphStyle = quoteParagraphStyle()
            style.isBlockquote = true
        } else if let match = bulletListRegex.firstMatch(in: line, range: lineRange) {
            // - 텍스트 → bullet prefix •
            markdownBody = lineNSString.substring(from: match.range.length)
            literalPrefix = "• "
        } else if let match = dashListRegex.firstMatch(in: line, range: lineRange) {
            // – 텍스트 → dash prefix –
            markdownBody = lineNSString.substring(from: match.range.length)
            literalPrefix = "– "
        } else if let match = numberListRegex.firstMatch(in: line, range: lineRange) {
            // 1. 텍스트 → number prefix 숫자.
            let marker = lineNSString.substring(with: match.range(at: 1))
            markdownBody = lineNSString.substring(from: match.range.length)
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
                // `텍스트` → mono font (백슬래시 이스케이프 제거 후 적용)
                var codeStyle = style
                codeStyle.isMonospaced = true
                let rawCodeText = (remainingText as NSString).substring(with: token.match.range(at: 1))
                let codeText = unescapeCodeText(rawCodeText)
                mutableAttributedString.append(attributedPlainText(codeText, baseFont: baseFont, style: codeStyle))

            case .link:
                // [텍스트](url) → NSLinkAttributeName (허용 scheme: https, http, mailto, tel)
                let label = (remainingText as NSString).substring(with: token.match.range(at: 1))
                let rawURL = (remainingText as NSString).substring(with: token.match.range(at: 2))
                var linkStyle = style
                if let url = URL(string: unescapeMarkdownText(rawURL)),
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

        var earliestToken: InlineToken?

        for (kind, regex) in inlinePatterns {
            guard let match = regex.firstMatch(in: text, range: fullRange) else {
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

    /// 코드 스팬 내부의 백슬래시 이스케이프를 제거합니다. `\`` → `` ` ``, `\\` → `\`.
    private static func unescapeCodeText(_ text: String) -> String {
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

    /// 이 파서가 escape하는 문자 집합입니다. `unescapeMarkdownText`는 이 집합 앞에 붙은 `\`만 제거합니다.
    ///
    /// `.`: `escapeLeadingBlockSyntax`가 `1\. text` 형태로 escape하므로 역직렬화 시 `.`를 unescape해야 합니다.
    /// `–`: `escapeLeadingBlockSyntax`가 `\– text` 형태로 escape하므로 역직렬화 시 `–`를 unescape해야 합니다.
    private static let escapedMarkdownCharacters: Set<Character> = [
        "\\", "*", "_", "[", "]", "(", ")", "~", "`", "<", ">", "#", "-", ".", "–"
    ]

    private static func unescapeMarkdownText(_ text: String) -> String {
        var unescaped = ""
        var isEscaping = false

        for character in text {
            if isEscaping {
                // escape 대상 문자: backslash 제거 후 문자만 추가
                // 비대상 문자: backslash도 유지 (e.g. C:\Users → C:\Users)
                if !escapedMarkdownCharacters.contains(character) {
                    unescaped.append("\\")
                }
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

        if style.isBlockquote {
            attributes[.editorBlockquote] = true
            attributes[.editorBlockquoteBorderColor] = UIColor.systemGray3
            attributes[.editorBlockquoteBaseHeadIndent] = NSNumber(value: 0.0)
            attributes[.editorBlockquoteBaseFirstLineHeadIndent] = NSNumber(value: 0.0)
        }

        if let linkURL = style.linkURL {
            attributes[.link] = linkURL
        }

        return attributes
    }

    private static func uiColor(fromCode code: String) -> UIColor? {
        let parts = code.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 4, parts.allSatisfy(\.isFinite) else { return nil }
        let clamped = parts.map { max(0.0, min(1.0, $0)) }
        return UIColor(red: CGFloat(clamped[0]), green: CGFloat(clamped[1]), blue: CGFloat(clamped[2]), alpha: CGFloat(clamped[3]))
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

        // Pretendard 커스텀 폰트는 symbolic traits 방식이 아닌 폰트명 직접 지정으로 처리
        // Pretendard에 italic 변형이 없으므로 oblique matrix로 기울임 표현
        if baseFont.fontName.hasPrefix("Pretendard") {
            let fontName = style.isBold ? "Pretendard-SemiBold" : "Pretendard-Regular"
            var font = UIFont(name: fontName, size: pointSize) ?? baseFont.withSize(pointSize)

            if style.isItalic {
                let oblique = CGAffineTransform(a: 1, b: 0, c: CGFloat(tanf(12.0 * Float.pi / 180.0)), d: 1, tx: 0, ty: 0)
                let descriptor = font.fontDescriptor.withMatrix(oblique)
                font = UIFont(descriptor: descriptor, size: pointSize)
            }

            return font
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
        paragraphStyle.firstLineHeadIndent = EditorConstants.blockquoteIndent
        paragraphStyle.headIndent = EditorConstants.blockquoteIndent
        return paragraphStyle
    }
}
