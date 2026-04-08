//
//  EditorToolbarViewModel.swift
//  AppProduct
//
//  Created by Codex on 4/8/26.
//  Copyright © 2026 UMC Product Team. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

/// 공지 에디터 툴바의 표시 상태를 정의합니다.
enum EditorToolbarMode {
    case `default`
    case textSelected
    case tableCell
}

/// 공지 에디터 단락 스타일 프리셋을 정의합니다.
enum EditorParagraphStyle: String, CaseIterable {
    case title
    case heading
    case subheading
    case body
    case mono
}

/// 공지 에디터 목록 스타일을 정의합니다.
enum EditorListStyle {
    case bullet
    case dash
    case number
}

/// 공지 에디터 툴바의 서식 상태와 편집 액션을 관리합니다.
@Observable
final class EditorToolbarViewModel {

    // MARK: - Property

    /// 블록 인용문에 적용할 기본 들여쓰기 값입니다.
    private let blockquoteIndent: CGFloat = 24

    /// 일반 들여쓰기 증감 단위입니다.
    private let indentStep: CGFloat = 24

    /// 현재 툴바의 표시 모드입니다.
    var toolbarMode: EditorToolbarMode = .default

    /// 포맷 패널 노출 여부입니다.
    private(set) var isFormatPanelVisible: Bool = false

    /// 선택 영역이 굵게 표시되는지 여부입니다.
    private(set) var isBold: Bool = false

    /// 선택 영역이 기울임꼴인지 여부입니다.
    private(set) var isItalic: Bool = false

    /// 선택 영역에 밑줄이 적용되었는지 여부입니다.
    private(set) var isUnderline: Bool = false

    /// 선택 영역에 취소선이 적용되었는지 여부입니다.
    private(set) var isStrikethrough: Bool = false

    /// 현재 단락에 블록 인용문 스타일이 적용되었는지 여부입니다.
    private(set) var isBlockquote: Bool = false

    /// 현재 단락의 대표 단락 스타일입니다.
    private(set) var paragraphStyle: EditorParagraphStyle = .body

    /// 현재 단락에 적용된 목록 스타일입니다.
    private(set) var activeListStyle: EditorListStyle?

    /// 선택 영역에 적용된 배경 강조 색상입니다.
    private(set) var highlightColor: Color?

    /// UITextView 연결 후 주입받는 편집 대상 텍스트 스토리지입니다.
    weak var textStorage: NSTextStorage?

    /// 현재 UITextView의 선택 범위입니다.
    var selectedRange: NSRange = NSRange(location: 0, length: 0)

    // MARK: - Function

    /// 기본 상태로 초기화합니다.
    init() { }

    /// 선택 영역의 폰트에 굵게 서식을 토글합니다.
    @MainActor
    func toggleBold() {
        toggleFontTrait(.traitBold, shouldEnable: !isBold)
    }

    /// 선택 영역의 폰트에 기울임꼴 서식을 토글합니다.
    @MainActor
    func toggleItalic() {
        toggleFontTrait(.traitItalic, shouldEnable: !isItalic)
    }

    /// 선택 영역의 텍스트에 밑줄 서식을 토글합니다.
    @MainActor
    func toggleUnderline() {
        toggleTextDecoration(.underlineStyle, enabled: !isUnderline, style: NSUnderlineStyle.single.rawValue)
    }

    /// 선택 영역의 텍스트에 취소선 서식을 토글합니다.
    @MainActor
    func toggleStrikethrough() {
        toggleTextDecoration(.strikethroughStyle, enabled: !isStrikethrough, style: NSUnderlineStyle.single.rawValue)
    }

    /// 현재 단락의 블록 인용문 스타일을 토글합니다.
    @MainActor
    func toggleBlockquote() {
        guard let storage = textStorage, storage.length > 0 else { return }
        let paragraphRange = currentParagraphRange(in: storage)
        let baseLocation = safeAttributeLocation(for: paragraphRange, in: storage)
        let isCurrentlyBlockquote = isBlockquoteAttributeEnabled(at: baseLocation, in: storage)
        let currentStyle = paragraphStyle(at: baseLocation, in: storage)
        let updatedStyle = currentStyle.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()

        if isCurrentlyBlockquote {
            let baseHeadIndent = (storage.attribute(.editorBlockquoteBaseHeadIndent, at: baseLocation, effectiveRange: nil) as? NSNumber)?.doubleValue
            let baseFirstLineIndent = (storage.attribute(.editorBlockquoteBaseFirstLineHeadIndent, at: baseLocation, effectiveRange: nil) as? NSNumber)?.doubleValue
            updatedStyle.headIndent = CGFloat(baseHeadIndent ?? max(0, Double(updatedStyle.headIndent - blockquoteIndent)))
            updatedStyle.firstLineHeadIndent = CGFloat(baseFirstLineIndent ?? max(0, Double(updatedStyle.firstLineHeadIndent - blockquoteIndent)))
        } else {
            let headIndent = updatedStyle.headIndent
            let firstLineHeadIndent = updatedStyle.firstLineHeadIndent
            updatedStyle.headIndent += blockquoteIndent
            updatedStyle.firstLineHeadIndent += blockquoteIndent
            storage.addAttribute(.editorBlockquoteBaseHeadIndent, value: NSNumber(value: Double(headIndent)), range: paragraphRange)
            storage.addAttribute(.editorBlockquoteBaseFirstLineHeadIndent, value: NSNumber(value: Double(firstLineHeadIndent)), range: paragraphRange)
            storage.addAttribute(.editorBlockquoteBorderColor, value: UIColor.systemGray3, range: paragraphRange)
            storage.addAttribute(.editorBlockquote, value: true, range: paragraphRange)
        }

        storage.beginEditing()
        storage.addAttribute(.paragraphStyle, value: updatedStyle.copy() as? NSParagraphStyle ?? updatedStyle, range: paragraphRange)
        if isCurrentlyBlockquote {
            storage.removeAttribute(.editorBlockquote, range: paragraphRange)
            storage.removeAttribute(.editorBlockquoteBorderColor, range: paragraphRange)
            storage.removeAttribute(.editorBlockquoteBaseHeadIndent, range: paragraphRange)
            storage.removeAttribute(.editorBlockquoteBaseFirstLineHeadIndent, range: paragraphRange)
        }
        storage.endEditing()

        syncFormattingState()
    }

    /// 선택된 단락 범위에 지정한 단락 스타일 폰트를 적용합니다.
    @MainActor
    func applyParagraphStyle(_ style: EditorParagraphStyle) {
        guard let storage = textStorage else { return }
        let paragraphRange = selectedParagraphRange(in: storage)
        let font = font(for: style)

        storage.beginEditing()
        storage.addAttribute(.font, value: font, range: paragraphRange)
        storage.endEditing()

        syncFormattingState()
    }

    /// 현재 단락 시작 부분에 목록 접두사를 적용합니다.
    @MainActor
    func applyList(_ style: EditorListStyle) {
        guard let storage = textStorage else { return }

        let paragraphRange = currentParagraphRange(in: storage)
        let paragraphNSString = storage.string as NSString
        let paragraphText = paragraphNSString.substring(with: paragraphRange)
        let prefix = listPrefix(for: style)
        let existingPrefixRange = existingListPrefixRange(in: paragraphText)
        let replacementRange = NSRange(
            location: paragraphRange.location,
            length: existingPrefixRange?.length ?? 0
        )

        storage.beginEditing()
        storage.replaceCharacters(in: replacementRange, with: prefix)
        storage.addAttribute(.editorListStyle, value: listStyleIdentifier(for: style), range: currentParagraphRange(in: storage))
        storage.endEditing()

        adjustSelectedRange(forReplacing: replacementRange, with: prefix.utf16.count)
        syncFormattingState()
    }

    /// 선택된 단락 범위의 들여쓰기를 한 단계 증가시킵니다.
    @MainActor
    func applyIndent() {
        adjustParagraphIndent(by: indentStep)
    }

    /// 선택된 단락 범위의 들여쓰기를 한 단계 감소시킵니다.
    @MainActor
    func applyOutdent() {
        adjustParagraphIndent(by: -indentStep)
    }

    /// 선택 영역의 배경 강조 색상을 적용합니다.
    @MainActor
    func applyHighlight(color: Color) {
        guard let storage = textStorage else { return }
        let clampedRange = clampedSelectedRange(in: storage)
        guard clampedRange.length > 0 else { return }

        storage.beginEditing()
        storage.addAttribute(.backgroundColor, value: UIColor(color), range: clampedRange)
        storage.endEditing()

        syncFormattingState()
    }

    /// 포맷 패널 노출 상태를 토글합니다.
    func toggleFormatPanel() {
        isFormatPanelVisible.toggle()
    }

    /// 포맷 패널을 닫습니다.
    func dismissFormatPanel() {
        isFormatPanelVisible = false
    }

    /// 선택 영역의 실제 속성을 읽어 툴바 상태를 동기화합니다.
    @MainActor
    func syncFormattingState() {
        guard let storage = textStorage else {
            resetFormattingState()
            return
        }

        let clampedRange = clampedSelectedRange(in: storage)
        let syncRange = syncRange(in: storage)
        let paragraphRange = currentParagraphRange(in: storage)
        let paragraphLocation = safeAttributeLocation(for: paragraphRange, in: storage)

        if case .tableCell = toolbarMode {
        } else {
            toolbarMode = clampedRange.length > 0 ? .textSelected : .default
        }

        isBold = syncRange.map { rangeHasUniformFontTrait($0, trait: .traitBold, in: storage) } ?? false
        isItalic = syncRange.map { rangeHasUniformFontTrait($0, trait: .traitItalic, in: storage) } ?? false
        isUnderline = syncRange.map { rangeHasUniformTextDecoration($0, key: .underlineStyle, in: storage) } ?? false
        isStrikethrough = syncRange.map { rangeHasUniformTextDecoration($0, key: .strikethroughStyle, in: storage) } ?? false
        isBlockquote = isBlockquoteAttributeEnabled(at: paragraphLocation, in: storage)
        paragraphStyle = detectedParagraphStyle(at: paragraphLocation, in: storage)
        activeListStyle = detectedListStyle(in: paragraphRange, storage: storage)
        highlightColor = syncRange.flatMap { uniformHighlightColor(in: $0, storage: storage) }
    }

    /// 선택 영역의 폰트 심볼릭 트레이트를 토글합니다.
    @MainActor
    private func toggleFontTrait(_ trait: UIFontDescriptor.SymbolicTraits, shouldEnable: Bool) {
        guard let storage = textStorage else { return }
        let clampedRange = clampedSelectedRange(in: storage)
        guard clampedRange.length > 0 else { return }

        storage.beginEditing()
        storage.enumerateAttribute(.font, in: clampedRange) { value, range, _ in
            let currentFont = resolvedFont(from: value, at: range.location, in: storage)
            let updatedFont = updatedFont(from: currentFont, toggling: trait, enabled: shouldEnable)
            storage.addAttribute(.font, value: updatedFont, range: range)
        }
        storage.endEditing()

        syncFormattingState()
    }

    /// 선택 영역의 선형 텍스트 장식을 토글합니다.
    @MainActor
    private func toggleTextDecoration(_ key: NSAttributedString.Key, enabled: Bool, style: Int) {
        guard let storage = textStorage else { return }
        let clampedRange = clampedSelectedRange(in: storage)
        guard clampedRange.length > 0 else { return }

        storage.beginEditing()
        if enabled {
            storage.addAttribute(key, value: style, range: clampedRange)
        } else {
            storage.removeAttribute(key, range: clampedRange)
        }
        storage.endEditing()

        syncFormattingState()
    }

    /// 선택된 단락 범위의 들여쓰기 값을 안전하게 조정합니다.
    @MainActor
    private func adjustParagraphIndent(by delta: CGFloat) {
        guard let storage = textStorage else { return }
        let paragraphRange = selectedParagraphRange(in: storage)
        guard paragraphRange.length > 0 || storage.length == 0 else { return }

        let paragraphRanges = paragraphRanges(in: paragraphRange, storage: storage)
        storage.beginEditing()

        for range in paragraphRanges {
            let location = safeAttributeLocation(for: range, in: storage)
            let currentStyle = paragraphStyle(at: location, in: storage)
            let updatedStyle = currentStyle.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            updatedStyle.headIndent = max(0, updatedStyle.headIndent + delta)

            if isBlockquoteAttributeEnabled(at: location, in: storage) {
                updatedStyle.firstLineHeadIndent = max(0, updatedStyle.firstLineHeadIndent + delta)
                let baseHeadIndent = (storage.attribute(.editorBlockquoteBaseHeadIndent, at: location, effectiveRange: nil) as? NSNumber)?.doubleValue ?? Double(max(0, currentStyle.headIndent - blockquoteIndent))
                let baseFirstLineIndent = (storage.attribute(.editorBlockquoteBaseFirstLineHeadIndent, at: location, effectiveRange: nil) as? NSNumber)?.doubleValue ?? Double(max(0, currentStyle.firstLineHeadIndent - blockquoteIndent))
                storage.addAttribute(.editorBlockquoteBaseHeadIndent, value: NSNumber(value: baseHeadIndent + Double(delta)), range: range)
                storage.addAttribute(.editorBlockquoteBaseFirstLineHeadIndent, value: NSNumber(value: baseFirstLineIndent + Double(delta)), range: range)
            }

            storage.addAttribute(.paragraphStyle, value: updatedStyle.copy() as? NSParagraphStyle ?? updatedStyle, range: range)
        }

        storage.endEditing()
        syncFormattingState()
    }

    /// 유효한 선택 범위를 텍스트 스토리지 길이에 맞게 보정합니다.
    private func clampedSelectedRange(in storage: NSTextStorage) -> NSRange {
        let safeLocation = selectedRange.location == NSNotFound ? 0 : min(max(selectedRange.location, 0), storage.length)
        let requestedLength = selectedRange.length == NSNotFound ? 0 : max(selectedRange.length, 0)
        let safeLength = min(requestedLength, max(0, storage.length - safeLocation))
        return NSRange(location: safeLocation, length: safeLength)
    }

    /// 속성 조회에 사용할 안전한 위치를 계산합니다.
    private func safeAttributeLocation(for range: NSRange, in storage: NSTextStorage) -> Int {
        guard storage.length > 0 else { return 0 }
        if range.location < storage.length {
            return range.location
        }
        return max(0, storage.length - 1)
    }

    /// 현재 단락 범위를 계산합니다.
    private func currentParagraphRange(in storage: NSTextStorage) -> NSRange {
        guard storage.length > 0 else {
            return NSRange(location: 0, length: 0)
        }

        let clampedRange = clampedSelectedRange(in: storage)
        let anchorLocation = min(clampedRange.location, max(0, storage.length - 1))
        let nsString = storage.string as NSString
        return nsString.paragraphRange(for: NSRange(location: anchorLocation, length: 0))
    }

    /// 선택 범위가 걸친 전체 단락 범위를 계산합니다.
    private func selectedParagraphRange(in storage: NSTextStorage) -> NSRange {
        guard storage.length > 0 else {
            return NSRange(location: 0, length: 0)
        }

        let clampedRange = clampedSelectedRange(in: storage)
        let nsString = storage.string as NSString
        if clampedRange.length > 0 {
            return nsString.paragraphRange(for: clampedRange)
        }

        let anchorLocation = min(clampedRange.location, max(0, storage.length - 1))
        return nsString.paragraphRange(for: NSRange(location: anchorLocation, length: 0))
    }

    /// 단락 범위를 개별 단락 배열로 분해합니다.
    private func paragraphRanges(in range: NSRange, storage: NSTextStorage) -> [NSRange] {
        guard storage.length > 0, range.length > 0 else { return [] }

        var ranges: [NSRange] = []
        let nsString = storage.string as NSString
        var currentLocation = range.location
        let upperBound = NSMaxRange(range)

        while currentLocation < upperBound {
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: currentLocation, length: 0))
            ranges.append(paragraphRange)
            currentLocation = NSMaxRange(paragraphRange)
        }

        return ranges
    }

    /// 동기화 시 사용할 실제 속성 조회 범위를 계산합니다.
    private func syncRange(in storage: NSTextStorage) -> NSRange? {
        let clampedRange = clampedSelectedRange(in: storage)
        if clampedRange.length > 0 {
            return clampedRange
        }

        guard storage.length > 0 else { return nil }
        let location = min(clampedRange.location, max(0, storage.length - 1))
        return NSRange(location: location, length: 1)
    }

    /// 선택 치환 후 커서 위치와 길이를 보정합니다.
    private func adjustSelectedRange(forReplacing range: NSRange, with replacementLength: Int) {
        let delta = replacementLength - range.length
        let selectionEnd = NSMaxRange(selectedRange)
        let replacedEnd = NSMaxRange(range)

        if selectedRange.location >= replacedEnd {
            selectedRange.location += delta
        } else if selectedRange.location > range.location {
            selectedRange.location = range.location + replacementLength
        }

        if selectionEnd >= replacedEnd {
            selectedRange.length = max(0, selectedRange.length + delta)
        } else if selectionEnd > range.location {
            selectedRange.length = max(0, range.location + replacementLength - selectedRange.location)
        }

        selectedRange.location = max(0, selectedRange.location)
    }

    /// 저장된 폰트 속성 또는 기본 폰트를 반환합니다.
    private func resolvedFont(from attribute: Any?, at location: Int, in storage: NSTextStorage) -> UIFont {
        if let font = attribute as? UIFont {
            return font
        }

        if storage.length > 0, location < storage.length, let font = storage.attribute(.font, at: location, effectiveRange: nil) as? UIFont {
            return font
        }

        return font(for: .body)
    }

    /// 지정한 단락 스타일에 대응하는 폰트를 반환합니다.
    private func font(for style: EditorParagraphStyle) -> UIFont {
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
    private func updatedFont(from font: UIFont, toggling trait: UIFontDescriptor.SymbolicTraits, enabled: Bool) -> UIFont {
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
        let resolvedWeight: UIFont.Weight = enabled && trait == .traitBold ? .bold : (fontWeight >= UIFont.Weight.semibold.rawValue ? .semibold : .regular)
        if isMonospaced {
            return .monospacedSystemFont(ofSize: font.pointSize, weight: resolvedWeight)
        }
        return .systemFont(ofSize: font.pointSize, weight: resolvedWeight)
    }

    /// 폰트의 굵기 값을 추정합니다.
    private func weight(for font: UIFont) -> CGFloat {
        let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
        return traits?[.weight] as? CGFloat ?? UIFont.Weight.regular.rawValue
    }

    /// 주어진 범위의 모든 폰트가 동일 트레이트를 가지는지 확인합니다.
    private func rangeHasUniformFontTrait(_ range: NSRange, trait: UIFontDescriptor.SymbolicTraits, in storage: NSTextStorage) -> Bool {
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
    private func rangeHasUniformTextDecoration(_ range: NSRange, key: NSAttributedString.Key, in storage: NSTextStorage) -> Bool {
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
    private func uniformHighlightColor(in range: NSRange, storage: NSTextStorage) -> Color? {
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

    /// 지정 위치의 단락 스타일 속성을 반환합니다.
    private func paragraphStyle(at location: Int, in storage: NSTextStorage) -> NSParagraphStyle {
        guard storage.length > 0, location < storage.length else {
            return NSParagraphStyle.default
        }
        return storage.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle ?? .default
    }

    /// 현재 위치의 폰트 속성으로 대표 단락 스타일을 판별합니다.
    private func detectedParagraphStyle(at location: Int, in storage: NSTextStorage) -> EditorParagraphStyle {
        let font = resolvedFont(from: storage.length > 0 && location < storage.length ? storage.attribute(.font, at: location, effectiveRange: nil) : nil, at: location, in: storage)
        let traits = font.fontDescriptor.symbolicTraits
        let fontWeight = weight(for: font)

        if traits.contains(.traitMonoSpace) || font.fontName.localizedCaseInsensitiveContains("mono") {
            return .mono
        }
        if abs(font.pointSize - 28) < 0.5 && traits.contains(.traitBold) {
            return .title
        }
        if abs(font.pointSize - 22) < 0.5 && traits.contains(.traitBold) {
            return .heading
        }
        if abs(font.pointSize - 17) < 0.5 && fontWeight >= UIFont.Weight.semibold.rawValue {
            return .subheading
        }
        return .body
    }

    /// 현재 위치에 블록 인용문 속성이 적용되었는지 확인합니다.
    private func isBlockquoteAttributeEnabled(at location: Int, in storage: NSTextStorage) -> Bool {
        guard storage.length > 0, location < storage.length else { return false }
        return (storage.attribute(.editorBlockquote, at: location, effectiveRange: nil) as? Bool) == true
    }

    /// 목록 스타일에 대응하는 접두사 문자열을 반환합니다.
    private func listPrefix(for style: EditorListStyle) -> String {
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
    private func listStyleIdentifier(for style: EditorListStyle) -> String {
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
    private func existingListPrefixRange(in paragraphText: String) -> NSRange? {
        let nsString = paragraphText as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        guard let regularExpression = try? NSRegularExpression(pattern: "^(?:•|–|\\d+\\.)\\s+") else { return nil }
        let match = regularExpression.firstMatch(in: paragraphText, options: [], range: fullRange)
        return match?.range
    }

    /// 현재 단락에 적용된 목록 스타일을 판별합니다.
    private func detectedListStyle(in paragraphRange: NSRange, storage: NSTextStorage) -> EditorListStyle? {
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

    /// 두 UIKit 색상이 동일한지 비교합니다.
    private func colorsEqual(_ lhs: UIColor?, _ rhs: UIColor?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return lhs.isEqual(rhs)
        default:
            return false
        }
    }

    /// 포맷 상태를 기본값으로 되돌립니다.
    private func resetFormattingState() {
        if case .tableCell = toolbarMode {
        } else {
            toolbarMode = .default
        }
        isBold = false
        isItalic = false
        isUnderline = false
        isStrikethrough = false
        isBlockquote = false
        paragraphStyle = .body
        activeListStyle = nil
        highlightColor = nil
    }
}

private extension NSAttributedString.Key {

    /// 블록 인용문 적용 여부를 저장하는 키입니다.
    static let editorBlockquote = NSAttributedString.Key("EditorToolbarBlockquote")

    /// 블록 인용문 테두리 색상을 저장하는 키입니다.
    static let editorBlockquoteBorderColor = NSAttributedString.Key("EditorToolbarBlockquoteBorderColor")

    /// 블록 인용문 이전의 headIndent 값을 저장하는 키입니다.
    static let editorBlockquoteBaseHeadIndent = NSAttributedString.Key("EditorToolbarBlockquoteBaseHeadIndent")

    /// 블록 인용문 이전의 firstLineHeadIndent 값을 저장하는 키입니다.
    static let editorBlockquoteBaseFirstLineHeadIndent = NSAttributedString.Key("EditorToolbarBlockquoteBaseFirstLineHeadIndent")

    /// 현재 목록 스타일 식별자를 저장하는 키입니다.
    static let editorListStyle = NSAttributedString.Key("EditorToolbarListStyle")
}
