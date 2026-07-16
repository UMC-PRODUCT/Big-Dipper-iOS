//
//  MarkdownInlineSerializer.swift
//  NoticePresentation
//
//  Created by 이예지 on 7/1/26.
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
    static func serializeInline(
        _ attributedString: NSAttributedString,
        range: NSRange,
        blockImpliedBold: Bool = false
    ) -> String {
        guard range.length > 0 else {
            return ""
        }

        var markdown = ""

        attributedString.enumerateAttributes(in: range) { attributes, effectiveRange, _ in
            let text = attributedString.attributedSubstring(from: effectiveRange).string

            guard text.isEmpty == false else {
                return
            }

            markdown.append(serializeSegment(
                text: text,
                attributes: attributes,
                blockImpliedBold: blockImpliedBold
            ))
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
    static func serializeSegment(
        text: String,
        attributes: [NSAttributedString.Key: Any],
        blockImpliedBold: Bool = false
    ) -> String {
        let font = attributes[.font] as? UIFont
        let traits = font?.fontDescriptor.symbolicTraits ?? []
        // 헤딩/부머리말 블록은 폰트 자체가 bold이므로, 블록 레벨에서 이미 implied된 bold는 인라인 ** 마커로 이중 래핑하지 않는다.
        // Pretendard는 커스텀 폰트라 symbolic trait보다 폰트명으로 bold를 판별하는 편이 더 신뢰할 수 있습니다.
        let isBold: Bool
        if let font, font.fontName.hasPrefix("Pretendard") {
            let hasBoldName = font.fontName.contains("Bold") || font.fontName.contains("SemiBold")
            isBold = hasBoldName && !blockImpliedBold
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
        let isMonospaced = traits.contains(.traitMonoSpace)
            || font?.familyName.lowercased().contains("mono") == true
        let isUnderlined = (attributes[.underlineStyle] as? NSNumber)?.intValue ?? 0 != 0
        let isStruck = (attributes[.strikethroughStyle] as? NSNumber)?.intValue ?? 0 != 0
        let highlightColor = attributes[.backgroundColor] as? UIColor
        let linkValue = attributes[.link]

        // 빈 인용구 삽입 시 사용하는 zero-width space를 직렬화 결과에서 제거합니다.
        let cleanedText = text.replacingOccurrences(of: "\u{200B}", with: "")
        guard !cleanedText.isEmpty else { return "" }

        // run 양끝 공백은 마커 밖으로 분리합니다. 파서의 인라인 정규식이 `(?=\S)...(?<=\S)` 가드로
        // `**일시: **` 같은 공백 인접 마커를 거부하므로, 공백을 안쪽에 두면 자기 자신이 생성한
        // 마크다운을 파싱하지 못해 리스트/상세에 마커가 그대로 노출됩니다.
        // 코드 스팬은 가드가 없고 내용 보존이 우선이라 분리하지 않습니다.
        var leadingWhitespace = ""
        var trailingWhitespace = ""
        var coreText = cleanedText

        if !isMonospaced {
            leadingWhitespace = String(cleanedText.prefix(while: \.isWhitespace))
            let withoutLeading = cleanedText.dropFirst(leadingWhitespace.count)
            trailingWhitespace = String(
                withoutLeading.reversed().prefix(while: \.isWhitespace).reversed()
            )
            coreText = String(withoutLeading.dropLast(trailingWhitespace.count))

            // 공백뿐인 run 은 서식 마커 없이 공백 그대로 직렬화합니다.
            guard !coreText.isEmpty else { return cleanedText }
        }

        var content = MarkdownEscaping.escapeMarkdownText(coreText)

        if isMonospaced {
            // mono font → `텍스트`
            content = "`\(MarkdownEscaping.escapeMarkdownCodeText(cleanedText))`"
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

        return leadingWhitespace + content + trailingWhitespace
    }
}
