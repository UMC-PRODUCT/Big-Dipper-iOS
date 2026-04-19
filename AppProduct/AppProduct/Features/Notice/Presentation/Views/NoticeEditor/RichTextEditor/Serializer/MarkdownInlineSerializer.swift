//
//  MarkdownInlineSerializer.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation
import UIKit

// MARK: - MarkdownInlineSerializer

enum MarkdownInlineSerializer {

    // MARK: - Function

    static func serializeInline(_ attributedString: NSAttributedString, range: NSRange, blockImpliedBold: Bool = false) -> String {
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

    static func serializeSegment(text: String, attributes: [NSAttributedString.Key: Any], blockImpliedBold: Bool = false) -> String {
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

        // 빈 인용구 삽입 시 사용하는 zero-width space를 직렬화 결과에서 제거합니다.
        let cleanedText = text.replacingOccurrences(of: "\u{200B}", with: "")
        guard !cleanedText.isEmpty else { return "" }

        var content = MarkdownEscaping.escapeMarkdownText(cleanedText)

        if isMonospaced {
            // mono font → `텍스트`
            content = "`\(MarkdownEscaping.escapeMarkdownCodeText(text))`"
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
            let escapedURL = MarkdownEscaping.escapeMarkdownLinkDestination(rawURLString)
            content = "[\(content)](\(escapedURL))"
        }

        return content
    }
}
