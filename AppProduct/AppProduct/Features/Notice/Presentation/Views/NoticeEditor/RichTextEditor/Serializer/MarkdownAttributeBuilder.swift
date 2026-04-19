//
//  MarkdownAttributeBuilder.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation
import UIKit

// MARK: - MarkdownAttributeBuilder

enum MarkdownAttributeBuilder {

    // MARK: - Function

    static func attributes(for style: MarkdownInlineStyle, baseFont: UIFont) -> [NSAttributedString.Key: Any] {
        var result: [NSAttributedString.Key: Any] = [
            .font: font(for: style, baseFont: baseFont),
        ]

        if style.isUnderlined {
            result[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        if style.isStruck {
            result[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        if let highlightColor = style.highlightColor {
            result[.backgroundColor] = highlightColor
        }

        if let paragraphStyle = style.paragraphStyle {
            result[.paragraphStyle] = paragraphStyle
        }

        if style.isBlockquote {
            result[.editorBlockquote] = true
            result[.editorBlockquoteBorderColor] = UIColor.systemGray3
            result[.editorBlockquoteBaseHeadIndent] = NSNumber(value: 0.0)
            result[.editorBlockquoteBaseFirstLineHeadIndent] = NSNumber(value: 0.0)
        }

        if let linkURL = style.linkURL {
            result[.link] = linkURL
        }

        return result
    }

    static func font(for style: MarkdownInlineStyle, baseFont: UIFont) -> UIFont {
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

    static func fontWeight(from font: UIFont) -> UIFont.Weight {
        let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
        let rawWeight = traits?[.weight] as? CGFloat ?? UIFont.Weight.regular.rawValue
        return UIFont.Weight(rawValue: rawWeight)
    }

    static func quoteParagraphStyle() -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = EditorConstants.blockquoteIndent
        paragraphStyle.headIndent = EditorConstants.blockquoteIndent
        return paragraphStyle
    }

    static func uiColor(fromCode code: String) -> UIColor? {
        let parts = code.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 4, parts.allSatisfy(\.isFinite) else { return nil }
        let clamped = parts.map { max(0.0, min(1.0, $0)) }
        return UIColor(red: CGFloat(clamped[0]), green: CGFloat(clamped[1]), blue: CGFloat(clamped[2]), alpha: CGFloat(clamped[3]))
    }
}
