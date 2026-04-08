//
//  EditorToolbarViewModel+FormattingHelpers.swift
//  AppProduct
//
//  Created by euijjang97 on 4/8/26.
//

import Foundation
import SwiftUI
import UIKit

extension EditorToolbarViewModel {

    // MARK: - Font Helpers

    /// 저장된 폰트 속성 또는 기본 폰트를 반환합니다.
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

    /// 지정한 단락 스타일에 대응하는 폰트를 반환합니다.
    func font(for style: EditorParagraphStyle) -> UIFont {
        switch style {
        case .title:
            return .systemFont(ofSize: 28, weight: .bold)
        case .heading:
            return .systemFont(ofSize: 22, weight: .bold)
        case .subheading:
            return .systemFont(ofSize: 17, weight: .semibold)
        case .body:
            return .systemFont(ofSize: 16, weight: .regular)
        case .mono:
            return .monospacedSystemFont(ofSize: 14, weight: .regular)
        }
    }

    /// 폰트의 심볼릭 트레이트 토글 결과를 계산합니다.
    func updatedFont(from font: UIFont, toggling trait: UIFontDescriptor.SymbolicTraits, enabled: Bool) -> UIFont {
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

    /// 폰트의 굵기 값을 추정합니다.
    func weight(for font: UIFont) -> CGFloat {
        let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
        return traits?[.weight] as? CGFloat ?? UIFont.Weight.regular.rawValue
    }

    // MARK: - Uniform Attribute Checks

    /// 주어진 범위의 모든 폰트가 동일 트레이트를 가지는지 확인합니다.
    func rangeHasUniformFontTrait(_ range: NSRange, trait: UIFontDescriptor.SymbolicTraits, in storage: NSTextStorage) -> Bool {
        guard range.length > 0 else { return false }

        var hasContent = false
        var isUniform = true
        storage.enumerateAttribute(.font, in: range) { value, attributeRange, stop in
            guard attributeRange.length > 0 else { return }
            hasContent = true
            let font = resolvedFont(from: value, at: attributeRange.location, in: storage)
            if !font.fontDescriptor.symbolicTraits.contains(trait) {
                isUniform = false
                stop.pointee = true
            }
        }

        return hasContent && isUniform
    }

    /// 주어진 범위의 모든 텍스트가 동일 장식을 가지는지 확인합니다.
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

    /// 현재 범위에 동일한 강조 색이 적용되었는지 확인합니다.
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

    /// 지정 위치의 단락 스타일 속성을 반환합니다.
    func nsParagraphStyle(at location: Int, in storage: NSTextStorage) -> NSParagraphStyle {
        guard storage.length > 0, location < storage.length else {
            return NSParagraphStyle.default
        }
        return storage.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle ?? .default
    }

    /// 현재 위치의 폰트 속성으로 대표 단락 스타일을 판별합니다.
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
        if abs(detectedFont.pointSize - 28) < 0.5 && traits.contains(.traitBold) {
            return .title
        }
        if abs(detectedFont.pointSize - 22) < 0.5 && traits.contains(.traitBold) {
            return .heading
        }
        if abs(detectedFont.pointSize - 17) < 0.5 && fontWeight >= UIFont.Weight.semibold.rawValue {
            return .subheading
        }
        return .body
    }

    /// 현재 위치에 블록 인용문 속성이 적용되었는지 확인합니다.
    func isBlockquoteAttributeEnabled(at location: Int, in storage: NSTextStorage) -> Bool {
        guard storage.length > 0, location < storage.length else { return false }
        return (storage.attribute(.editorBlockquote, at: location, effectiveRange: nil) as? Bool) == true
    }

    // MARK: - List Helpers

    /// 목록 스타일에 대응하는 접두사 문자열을 반환합니다.
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

    /// 목록 스타일을 저장하기 위한 식별자를 반환합니다.
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

    /// 단락 문자열의 기존 목록 접두사 범위를 찾습니다.
    func existingListPrefixRange(in paragraphText: String) -> NSRange? {
        let nsString = paragraphText as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        guard let regularExpression = try? NSRegularExpression(pattern: "^(?:•|–|\\d+\\.)\\s+") else { return nil }
        let match = regularExpression.firstMatch(in: paragraphText, options: [], range: fullRange)
        return match?.range
    }

    /// 현재 단락에 적용된 목록 스타일을 판별합니다.
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

    /// 두 UIKit 색상이 동일한지 비교합니다.
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
