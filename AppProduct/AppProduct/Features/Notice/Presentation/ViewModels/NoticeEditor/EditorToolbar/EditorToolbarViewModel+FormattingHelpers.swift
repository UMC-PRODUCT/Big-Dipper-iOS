//
//  EditorToolbarViewModel+FormattingHelpers.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation
import SwiftUI
import UIKit

extension EditorToolbarViewModel {

    // MARK: - Font Helpers

    func resolvedFont(from attribute: Any?, at location: Int, in storage: NSTextStorage) -> UIFont {
        if let font = attribute as? UIFont {
            return font
        }

        if storage.length > 0, location < storage.length,
           let font = storage.attribute(.font, at: location, effectiveRange: nil) as? UIFont {
            return font
        }

        return font(for: .body)
    }

    func font(for style: EditorParagraphStyle) -> UIFont {
        switch style {
        case .title:
            return UIFont(name: "Pretendard-Bold", size: 28) ?? .systemFont(ofSize: 28, weight: .bold)
        case .heading:
            return UIFont(name: "Pretendard-Bold", size: 22) ?? .systemFont(ofSize: 22, weight: .bold)
        case .subheading:
            return UIFont(name: "Pretendard-SemiBold", size: 17) ?? .systemFont(ofSize: 17, weight: .semibold)
        case .body:
            return UIFont(name: "Pretendard-Regular", size: 16) ?? .systemFont(ofSize: 16, weight: .regular)
        case .mono:
            return .monospacedSystemFont(ofSize: 14, weight: .regular)
        }
    }

    /// Pretendard italic은 변형 폰트가 없으므로 oblique matrix로 기울임을 표현합니다.
    func updatedFont(from font: UIFont, toggling trait: UIFontDescriptor.SymbolicTraits, enabled: Bool) -> UIFont {
        // Pretendard 폰트 전용 처리
        if font.fontName.hasPrefix("Pretendard") {
            let isBold = font.fontName.contains("Bold") || font.fontName.contains("SemiBold")
            let isItalic = font.fontDescriptor.matrix.c != 0.0

            let targetBold = (trait == .traitBold) ? enabled : isBold
            let targetItalic = (trait == .traitItalic) ? enabled : isItalic

            let baseFontName = targetBold ? "Pretendard-SemiBold" : "Pretendard-Regular"
            var result = UIFont(name: baseFontName, size: font.pointSize) ?? font

            if targetItalic {
                let oblique = CGAffineTransform(
                    a: 1, b: 0,
                    c: CGFloat(tanf(12.0 * Float.pi / 180.0)),
                    d: 1, tx: 0, ty: 0
                )
                let descriptor = result.fontDescriptor.withMatrix(oblique)
                result = UIFont(descriptor: descriptor, size: font.pointSize)
            }

            return result
        }

        var traits = font.fontDescriptor.symbolicTraits
        if enabled {
            traits.insert(trait)
        } else {
            traits.remove(trait)
        }

        if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: descriptor, size: font.pointSize)
        }

        let isMonospaced = font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace)
        let fontWeight = weight(for: font)
        let resolvedWeight: UIFont.Weight = enabled && trait == .traitBold
            ? .bold
            : (fontWeight >= UIFont.Weight.semibold.rawValue ? .semibold : .regular)
        if isMonospaced {
            return .monospacedSystemFont(ofSize: font.pointSize, weight: resolvedWeight)
        }
        return .systemFont(ofSize: font.pointSize, weight: resolvedWeight)
    }

    func weight(for font: UIFont) -> CGFloat {
        let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
        return traits?[.weight] as? CGFloat ?? UIFont.Weight.regular.rawValue
    }

    /// Pretendard-SemiBold는 symbolicTraits에 .traitBold가 없으므로 폰트 이름으로 판별합니다.
    func isFontBold(_ font: UIFont) -> Bool {
        if font.fontName.hasPrefix("Pretendard") {
            return font.fontName.contains("Bold") || font.fontName.contains("SemiBold")
        }
        return font.fontDescriptor.symbolicTraits.contains(.traitBold)
    }

    // MARK: - Uniform Attribute Checks

    func rangeHasUniformFontTrait(_ range: NSRange, trait: UIFontDescriptor.SymbolicTraits, in storage: NSTextStorage) -> Bool {
        guard range.length > 0 else { return false }

        var hasContent = false
        var isUniform = true
        storage.enumerateAttribute(.font, in: range) { value, attributeRange, stop in
            guard attributeRange.length > 0 else { return }
            hasContent = true
            let font = resolvedFont(from: value, at: attributeRange.location, in: storage)

            let hasTrait: Bool
            if trait == .traitBold {
                hasTrait = isFontBold(font)
            } else if font.fontName.hasPrefix("Pretendard") && trait == .traitItalic {
                hasTrait = font.fontDescriptor.matrix.c != 0.0
            } else {
                hasTrait = font.fontDescriptor.symbolicTraits.contains(trait)
            }

            if !hasTrait {
                isUniform = false
                stop.pointee = true
            }
        }

        return hasContent && isUniform
    }

    func rangeHasUniformTextDecoration(_ range: NSRange, key: NSAttributedString.Key, in storage: NSTextStorage) -> Bool {
        guard range.length > 0 else { return false }

        var hasContent = false
        var isUniform = true
        storage.enumerateAttribute(key, in: range) { value, attributeRange, stop in
            guard attributeRange.length > 0 else { return }
            hasContent = true
            let style = (value as? NSNumber)?.intValue ?? (value as? Int) ?? 0
            if style == 0 {
                isUniform = false
                stop.pointee = true
            }
        }

        return hasContent && isUniform
    }

    func uniformHighlightColor(in range: NSRange, storage: NSTextStorage) -> Color? {
        guard range.length > 0 else { return nil }

        var resolvedColor: UIColor?
        var hasMixedColor = false
        storage.enumerateAttribute(.backgroundColor, in: range) { value, attributeRange, stop in
            guard attributeRange.length > 0 else { return }
            let currentColor = value as? UIColor
            if let resolvedColor {
                if !colorsEqual(resolvedColor, currentColor) {
                    hasMixedColor = true
                    stop.pointee = true
                }
                return
            }
            resolvedColor = currentColor
        }

        guard !hasMixedColor, let resolvedColor else { return nil }
        return Color(uiColor: resolvedColor)
    }

    // MARK: - Style Detection

    func nsParagraphStyle(at location: Int, in storage: NSTextStorage) -> NSParagraphStyle {
        guard storage.length > 0, location < storage.length else {
            return NSParagraphStyle.default
        }
        return storage.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle ?? .default
    }

    func detectedParagraphStyle(at location: Int, in storage: NSTextStorage) -> EditorParagraphStyle {
        let fontAttribute = storage.length > 0 && location < storage.length
            ? storage.attribute(.font, at: location, effectiveRange: nil)
            : nil
        let detectedFont = resolvedFont(from: fontAttribute, at: location, in: storage)
        let traits = detectedFont.fontDescriptor.symbolicTraits
        let fontWeight = weight(for: detectedFont)

        if traits.contains(.traitMonoSpace) || detectedFont.fontName.localizedCaseInsensitiveContains("mono") {
            return .mono
        }
        if abs(detectedFont.pointSize - 28) < 0.5 && isFontBold(detectedFont) {
            return .title
        }
        if abs(detectedFont.pointSize - 22) < 0.5 && isFontBold(detectedFont) {
            return .heading
        }
        if abs(detectedFont.pointSize - 17) < 0.5 && fontWeight >= UIFont.Weight.semibold.rawValue {
            return .subheading
        }
        return .body
    }

    func isBlockquoteAttributeEnabled(at location: Int, in storage: NSTextStorage) -> Bool {
        guard storage.length > 0, location < storage.length else { return false }
        return (storage.attribute(.editorBlockquote, at: location, effectiveRange: nil) as? Bool) == true
    }

    // MARK: - List Helpers

    func listPrefix(for style: EditorListStyle) -> String {
        switch style {
        case .bullet:
            return "• "
        case .dash:
            return "– "
        case .number:
            return "1. "
        }
    }

    func listStyleIdentifier(for style: EditorListStyle) -> String {
        switch style {
        case .bullet:
            return "bullet"
        case .dash:
            return "dash"
        case .number:
            return "number"
        }
    }

    func existingListPrefixRange(in paragraphText: String) -> NSRange? {
        let nsString = paragraphText as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let match = Self.listPrefixRegex.firstMatch(in: paragraphText, options: [], range: fullRange)
        return match?.range
    }

    private static let listPrefixRegex = try! NSRegularExpression(pattern: "^(?:•|–|\\d+\\.)\\s+")

    func detectedListStyle(in paragraphRange: NSRange, storage: NSTextStorage) -> EditorListStyle? {
        let paragraphText = (storage.string as NSString).substring(with: paragraphRange)
        if paragraphText.hasPrefix("• ") {
            return .bullet
        }
        if paragraphText.hasPrefix("– ") {
            return .dash
        }
        guard let prefixRange = existingListPrefixRange(in: paragraphText), prefixRange.location == 0 else {
            return nil
        }
        return .number
    }

    // MARK: - Color Helpers

    func colorsEqual(_ lhs: UIColor?, _ rhs: UIColor?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return lhs.isEqual(rhs)
        default:
            return false
        }
    }
}
