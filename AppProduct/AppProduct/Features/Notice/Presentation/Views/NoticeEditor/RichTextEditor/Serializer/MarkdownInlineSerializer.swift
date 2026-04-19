//
//  MarkdownInlineSerializer.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation
import UIKit

// MARK: - MarkdownInlineSerializer

/// attributed string 의 한 구간을 **인라인 마크다운 문자열** 로 역변환하는 직렬화기.
///
/// `NSAttributedString.enumerateAttributes(in:)` 로 같은 속성을 공유하는 run 단위로
/// 순회하며 각 run 을 `serializeSegment` 로 변환하고 이어 붙입니다.
enum MarkdownInlineSerializer {

    // MARK: - Function

    /// 주어진 범위의 인라인 텍스트를 마크다운 문자열로 직렬화합니다.
    ///
    /// - Parameters:
    ///   - attributedString: 전체 에디터 문자열.
    ///   - range: 직렬화 대상 범위(블록 prefix 제거 후 남은 본문).
    ///   - blockImpliedBold: 블록 prefix(헤딩 등) 자체가 bold 를 암시하는 경우 `true`.
    ///     이 때 인라인 레벨에서는 `**` 래핑을 하지 않아 이중 표시를 방지합니다.
    /// - Returns: 인라인 마크다운 문자열.
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

    /// 단일 run(같은 속성 집합을 공유하는 연속 텍스트)을 마크다운 조각으로 변환합니다.
    ///
    /// ### 래핑 순서
    /// 1. `isMonospaced` → `` `...` `` 로 래핑 (다른 인라인 서식 무시).
    /// 2. Bold + Italic 동시 → `**_..._**`.
    /// 3. 그 외 Bold / Italic 은 각각 `**...**`, `*...*` 로 중첩 가능.
    /// 4. Underline → `<u>...</u>` (monospaced 가 아닐 때만).
    /// 5. Strikethrough → `~~...~~` (monospaced 가 아닐 때만).
    /// 6. Highlight → `<mark color="R,G,B,A">...</mark>` (sRGB 변환 실패 시 skip).
    /// 7. Link → `[...](url)` (`)`, `\` escape 적용).
    ///
    /// - Parameters:
    ///   - text: run 의 raw 텍스트.
    ///   - attributes: run 의 속성 dictionary.
    ///   - blockImpliedBold: 블록 레벨에서 이미 bold 가 함축되어 있는지 여부.
    /// - Returns: 해당 run 을 나타내는 마크다운 조각.
    static func serializeSegment(text: String, attributes: [NSAttributedString.Key: Any], blockImpliedBold: Bool = false) -> String {
        let font = attributes[.font] as? UIFont
        let traits = font?.fontDescriptor.symbolicTraits ?? []
        let isBold: Bool
        if let font, font.fontName.hasPrefix("Pretendard") {
            isBold = (font.fontName.contains("Bold") || font.fontName.contains("SemiBold")) && !blockImpliedBold
        } else {
            isBold = traits.contains(.traitBold) && !blockImpliedBold
        }
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

        let cleanedText = text.replacingOccurrences(of: "\u{200B}", with: "")
        guard !cleanedText.isEmpty else { return "" }

        var content = MarkdownEscaping.escapeMarkdownText(cleanedText)

        if isMonospaced {
            content = "`\(MarkdownEscaping.escapeMarkdownCodeText(text))`"
        } else if isBold && isItalic {
            content = "**_\(content)_**"
        } else {
            if isBold {
                content = "**\(content)**"
            }

            if isItalic {
                content = "*\(content)*"
            }
        }

        if isUnderlined && isMonospaced == false {
            content = "<u>\(content)</u>"
        }

        if isStruck && isMonospaced == false {
            content = "~~\(content)~~"
        }

        if let highlightColor, isMonospaced == false {
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

            let escapedURL = MarkdownEscaping.escapeMarkdownLinkDestination(rawURLString)
            content = "[\(content)](\(escapedURL))"
        }

        return content
    }
}
