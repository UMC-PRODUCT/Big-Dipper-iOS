//
//  EditorToolbarViewModel.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation
import SwiftUI
import UIKit

@Observable
final class EditorToolbarViewModel {

    // MARK: - Property

    private let blockquoteIndent: CGFloat = EditorConstants.blockquoteIndent
    private let indentStep: CGFloat = 24

    var toolbarMode: EditorToolbarMode = .default
    private(set) var isFormatPanelVisible: Bool = false
    private(set) var isEditorActive: Bool = false
    private(set) var isBold: Bool = false
    private(set) var isItalic: Bool = false
    /// italic 토글 직후 UIKit 리셋을 거슬러 상태를 일시 보존합니다.
    private var _pendingItalicEnabled: Bool?
    private(set) var isUnderline: Bool = false
    private(set) var isStrikethrough: Bool = false
    private(set) var isBlockquote: Bool = false
    private(set) var paragraphStyle: EditorParagraphStyle = .body
    private(set) var activeListStyle: EditorListStyle?
    private(set) var highlightColor: Color?

    weak var textStorage: NSTextStorage?
    weak var textView: UITextView?

    private(set) var activeHighlightColor: UIColor?
    var selectedRange: NSRange = NSRange(location: 0, length: 0)

    // MARK: - Function

    init() { }

    @MainActor
    func toggleBold() {
        toggleFontTrait(.traitBold, shouldEnable: !isBold)
    }

    @MainActor
    func toggleItalic() {
        toggleFontTrait(.traitItalic, shouldEnable: !isItalic)
    }

    func clearPendingItalic() {
        _pendingItalicEnabled = nil
    }

    @MainActor
    func toggleUnderline() {
        toggleTextDecoration(.underlineStyle, enabled: !isUnderline, style: NSUnderlineStyle.single.rawValue)
    }

    @MainActor
    func toggleStrikethrough() {
        toggleTextDecoration(.strikethroughStyle, enabled: !isStrikethrough, style: NSUnderlineStyle.single.rawValue)
    }

    @MainActor
    func toggleBlockquote() {
        guard let storage = textStorage else { return }

        // 빈 텍스트: 인용구 속성이 적용된 zero-width space를 삽입하여
        // 경계선이 즉시 표시되고 placeholder가 숨겨지도록 합니다.
        if storage.length == 0 {
            guard let tv = textView else { return }
            let style = NSMutableParagraphStyle()
            style.headIndent = blockquoteIndent
            style.firstLineHeadIndent = blockquoteIndent

            let currentFont = tv.typingAttributes[.font] as? UIFont ?? font(for: .body)
            let attrs: [NSAttributedString.Key: Any] = [
                .paragraphStyle: (style.copy() as? NSParagraphStyle) ?? style,
                .font: currentFont,
                .editorBlockquote: true,
                .editorBlockquoteBorderColor: UIColor.systemGray3,
                .editorBlockquoteBaseHeadIndent: NSNumber(value: 0.0),
                .editorBlockquoteBaseFirstLineHeadIndent: NSNumber(value: 0.0),
            ]

            storage.beginEditing()
            storage.replaceCharacters(in: NSRange(location: 0, length: 0),
                                      with: NSAttributedString(string: "\u{200B}", attributes: attrs))
            storage.endEditing()

            tv.selectedRange = NSRange(location: 1, length: 0)
            tv.typingAttributes = attrs
            isBlockquote = true

            onFormattingApplied?()
            return
        }

        let paragraphRange = currentParagraphRange(in: storage)
        let baseLocation = safeAttributeLocation(for: paragraphRange, in: storage)
        let isCurrentlyBlockquote = isBlockquoteAttributeEnabled(at: baseLocation, in: storage)
        let currentStyle = nsParagraphStyle(at: baseLocation, in: storage)
        let updatedStyle = currentStyle.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()

        // 모든 attribute 변경을 단일 editing 트랜잭션으로 묶어
        // 레이아웃 패스와 delegate 알림이 1회만 발생하도록 합니다.
        storage.beginEditing()
        if isCurrentlyBlockquote {
            // zero-width space만 있는 빈 인용구 해제: 해당 단락의 ZWS를 제거하고 typingAttributes 정리
            let paragraphText = (storage.string as NSString).substring(with: paragraphRange)
            let isZWSOnly = paragraphText == "\u{200B}" || paragraphText == "\u{200B}\n"
            if isZWSOnly {
                let cursorAfterRemoval = paragraphRange.location
                storage.replaceCharacters(in: paragraphRange, with: "")
                storage.endEditing()

                if let tv = textView {
                    tv.typingAttributes.removeValue(forKey: .editorBlockquote)
                    tv.typingAttributes.removeValue(forKey: .editorBlockquoteBorderColor)
                    tv.typingAttributes.removeValue(forKey: .editorBlockquoteBaseHeadIndent)
                    tv.typingAttributes.removeValue(forKey: .editorBlockquoteBaseFirstLineHeadIndent)
                    tv.typingAttributes.removeValue(forKey: .paragraphStyle)
                    tv.selectedRange = NSRange(location: min(cursorAfterRemoval, storage.length), length: 0)
                }
                isBlockquote = false
                onFormattingApplied?()
                syncFormattingState()
                return
            }

            let baseHeadIndent = (storage.attribute(.editorBlockquoteBaseHeadIndent, at: baseLocation, effectiveRange: nil) as? NSNumber)?.doubleValue
            let baseFirstLineIndent = (storage.attribute(.editorBlockquoteBaseFirstLineHeadIndent, at: baseLocation, effectiveRange: nil) as? NSNumber)?.doubleValue
            updatedStyle.headIndent = CGFloat(baseHeadIndent ?? max(0, Double(updatedStyle.headIndent - blockquoteIndent)))
            updatedStyle.firstLineHeadIndent = CGFloat(baseFirstLineIndent ?? max(0, Double(updatedStyle.firstLineHeadIndent - blockquoteIndent)))
            storage.addAttribute(.paragraphStyle, value: (updatedStyle.copy() as? NSParagraphStyle) ?? updatedStyle, range: paragraphRange)
            storage.removeAttribute(.editorBlockquote, range: paragraphRange)
            storage.removeAttribute(.editorBlockquoteBorderColor, range: paragraphRange)
            storage.removeAttribute(.editorBlockquoteBaseHeadIndent, range: paragraphRange)
            storage.removeAttribute(.editorBlockquoteBaseFirstLineHeadIndent, range: paragraphRange)
        } else {
            let headIndent = updatedStyle.headIndent
            let firstLineHeadIndent = updatedStyle.firstLineHeadIndent
            updatedStyle.headIndent += blockquoteIndent
            updatedStyle.firstLineHeadIndent += blockquoteIndent
            storage.addAttribute(.paragraphStyle, value: (updatedStyle.copy() as? NSParagraphStyle) ?? updatedStyle, range: paragraphRange)
            storage.addAttribute(.editorBlockquoteBaseHeadIndent, value: NSNumber(value: Double(headIndent)), range: paragraphRange)
            storage.addAttribute(.editorBlockquoteBaseFirstLineHeadIndent, value: NSNumber(value: Double(firstLineHeadIndent)), range: paragraphRange)
            storage.addAttribute(.editorBlockquoteBorderColor, value: UIColor.systemGray3, range: paragraphRange)
            storage.addAttribute(.editorBlockquote, value: true, range: paragraphRange)
        }
        storage.endEditing()

        // 인용구 해제 시 typingAttributes에 남은 들여쓰기와 인용구 속성을 정리하여
        // 이후 입력되는 텍스트가 들여쓰기 없이 작성되도록 합니다.
        if isCurrentlyBlockquote, let tv = textView {
            tv.typingAttributes.removeValue(forKey: .editorBlockquote)
            tv.typingAttributes.removeValue(forKey: .editorBlockquoteBorderColor)
            tv.typingAttributes.removeValue(forKey: .editorBlockquoteBaseHeadIndent)
            tv.typingAttributes.removeValue(forKey: .editorBlockquoteBaseFirstLineHeadIndent)
            tv.typingAttributes[.paragraphStyle] = (updatedStyle.copy() as? NSParagraphStyle) ?? updatedStyle
        }

        onFormattingApplied?()
        syncFormattingState()
    }

    @MainActor
    func applyParagraphStyle(_ style: EditorParagraphStyle) {
        guard let storage = textStorage else { return }
        let paragraphRange = selectedParagraphRange(in: storage)
        let font = font(for: style)

        storage.beginEditing()
        storage.addAttribute(.font, value: font, range: paragraphRange)
        storage.endEditing()

        textView?.typingAttributes[.font] = font

        onFormattingApplied?()
        syncFormattingState()
    }

    @MainActor
    func applyList(_ style: EditorListStyle) {
        guard let storage = textStorage else { return }

        let originalCursor = selectedRange.location
        let paragraphRange = currentParagraphRange(in: storage)
        let paragraphNSString = storage.string as NSString
        let paragraphText = paragraphNSString.substring(with: paragraphRange)
        let prefix = listPrefix(for: style)
        let existingPrefixRange = existingListPrefixRange(in: paragraphText)

        // 이미 같은 리스트 스타일이 적용되어 있으면 접두사를 제거 (토글 해제)
        let currentListStyle = detectedListStyle(in: paragraphRange, storage: storage)
        if currentListStyle == style, let existingRange = existingPrefixRange {
            let removeRange = NSRange(
                location: paragraphRange.location,
                length: existingRange.length
            )
            storage.beginEditing()
            storage.replaceCharacters(in: removeRange, with: "")
            storage.removeAttribute(.editorListStyle, range: currentParagraphRange(in: storage))
            storage.endEditing()

            // 커서가 접두사 내부에 있었으면 단락 시작으로, 아니면 삭제된 길이만큼 뒤로 이동
            let prefixEnd = removeRange.location + removeRange.length
            let newCursor: Int
            if originalCursor <= prefixEnd {
                newCursor = removeRange.location
            } else {
                newCursor = originalCursor - removeRange.length
            }
            let cursorPosition = NSRange(location: newCursor, length: 0)
            selectedRange = cursorPosition
            textView?.selectedRange = cursorPosition
            onFormattingApplied?()
            syncFormattingState()
            return
        }

        let oldPrefixLength = existingPrefixRange?.length ?? 0
        let replacementRange = NSRange(
            location: paragraphRange.location,
            length: oldPrefixLength
        )

        let contentOffset = replacementRange.location + oldPrefixLength
        let prefixFont: UIFont
        if contentOffset < storage.length {
            prefixFont = storage.attribute(.font, at: contentOffset, effectiveRange: nil) as? UIFont
                ?? textView?.typingAttributes[.font] as? UIFont
                ?? font(for: .body)
        } else {
            prefixFont = textView?.typingAttributes[.font] as? UIFont ?? font(for: .body)
        }

        storage.beginEditing()
        storage.replaceCharacters(in: replacementRange, with: prefix)
        let insertedRange = NSRange(location: replacementRange.location, length: prefix.utf16.count)
        storage.addAttribute(.font, value: prefixFont, range: insertedRange)
        storage.addAttribute(.editorListStyle, value: listStyleIdentifier(for: style), range: currentParagraphRange(in: storage))
        storage.endEditing()

        let oldPrefixEnd = paragraphRange.location + oldPrefixLength
        let delta = prefix.utf16.count - oldPrefixLength
        let newCursor: Int
        if originalCursor <= oldPrefixEnd {
            newCursor = replacementRange.location + prefix.utf16.count
        } else {
            newCursor = originalCursor + delta
        }
        let cursorAfterPrefix = NSRange(location: newCursor, length: 0)
        selectedRange = cursorAfterPrefix
        textView?.selectedRange = cursorAfterPrefix
        onFormattingApplied?()
        syncFormattingState()
    }

    @MainActor
    func applyIndent() {
        adjustParagraphIndent(by: indentStep)
    }

    @MainActor
    func applyOutdent() {
        adjustParagraphIndent(by: -indentStep)
    }

    @MainActor
    func applyHighlight(color: Color) {
        let uiColor = UIColor(color)
        activeHighlightColor = uiColor

        if let storage = textStorage {
            let clampedRange = clampedSelectedRange(in: storage)
            if clampedRange.length > 0 {
                storage.beginEditing()
                storage.addAttribute(.backgroundColor, value: uiColor, range: clampedRange)
                storage.endEditing()
            }
        }

        textView?.typingAttributes[.backgroundColor] = uiColor

        onFormattingApplied?()
        syncFormattingState()
    }

    @MainActor
    func clearHighlight() {
        activeHighlightColor = nil

        if let storage = textStorage {
            let clampedRange = clampedSelectedRange(in: storage)
            if clampedRange.length > 0 {
                storage.beginEditing()
                storage.removeAttribute(.backgroundColor, range: clampedRange)
                storage.endEditing()
            }
        }

        textView?.typingAttributes.removeValue(forKey: .backgroundColor)

        onFormattingApplied?()
        syncFormattingState()
    }

    /// 하이라이트 영역을 벗어나면 다음 입력에 색이 번지지 않도록 typingAttributes를 정리합니다.
    @MainActor
    func reapplyActiveHighlightIfNeeded() {
        guard let uiColor = activeHighlightColor,
              let storage = textStorage,
              storage.length > 0
        else { return }
        let location = min(max(selectedRange.location - 1, 0), storage.length - 1)
        let existingColor = storage.attribute(.backgroundColor, at: location, effectiveRange: nil) as? UIColor
        if existingColor == uiColor {
            textView?.typingAttributes[.backgroundColor] = uiColor
        } else {
            textView?.typingAttributes.removeValue(forKey: .backgroundColor)
        }
    }

    func toggleFormatPanel() {
        isFormatPanelVisible.toggle()
    }

    func dismissFormatPanel() {
        isFormatPanelVisible = false
    }

    /// 에디터 포커스 상태를 설정합니다.
    func setEditorActive(_ active: Bool) {
        isEditorActive = active
    }

    var onFormattingApplied: (() -> Void)?

    /// typingAttributes 변경 시 attributedText 재할당을 건너뛰고 placeholder만 갱신합니다.
    var onPlaceholderNeedsUpdate: (() -> Void)?

    private func notifyPlaceholderUpdate() {
        onPlaceholderNeedsUpdate?()
    }

    @MainActor
    func syncFormattingState() {
        guard let storage = textStorage else {
            resetFormattingState()
            return
        }

        if storage.length == 0 || isAtEOFEmptyParagraph(in: storage), let tv = textView {
            syncFormattingStateFromTypingAttributes(tv)
            return
        }

        let clampedRange = clampedSelectedRange(in: storage)
        let resolvedSyncRange = syncRange(in: storage)
        let paragraphRange = currentParagraphRange(in: storage)
        let paragraphLocation = safeAttributeLocation(for: paragraphRange, in: storage)

        if case .tableCell = toolbarMode {
        } else {
            toolbarMode = clampedRange.length > 0 ? .textSelected : .default
        }

        if clampedRange.length == 0, let tv = textView {
            let typingFont = tv.typingAttributes[.font] as? UIFont ?? font(for: .body)
            isBold = isFontBold(typingFont)
            // UIKit이 커서 이동 시 oblique matrix를 리셋하므로 .editorItalic 커스텀 키로 상태를 추적합니다.
            if let pending = _pendingItalicEnabled {
                isItalic = pending
            } else if let editorItalicFlag = tv.typingAttributes[.editorItalic] as? Bool {
                isItalic = editorItalicFlag
            } else if typingFont.fontName.hasPrefix("Pretendard") {
                isItalic = typingFont.fontDescriptor.matrix.c != 0.0
            } else {
                isItalic = typingFont.fontDescriptor.symbolicTraits.contains(.traitItalic)
            }
            isUnderline = (tv.typingAttributes[.underlineStyle] as? Int ?? 0) > 0
            isStrikethrough = (tv.typingAttributes[.strikethroughStyle] as? Int ?? 0) > 0
        } else {
            isBold = resolvedSyncRange.map {
                rangeHasUniformFontTrait($0, trait: .traitBold, in: storage)
            } ?? false
            isItalic = resolvedSyncRange.map { rangeHasUniformFontTrait($0, trait: .traitItalic, in: storage) } ?? false
            isUnderline = resolvedSyncRange.map { rangeHasUniformTextDecoration($0, key: .underlineStyle, in: storage) } ?? false
            isStrikethrough = resolvedSyncRange.map { rangeHasUniformTextDecoration($0, key: .strikethroughStyle, in: storage) } ?? false
        }
        isBlockquote = isBlockquoteAttributeEnabled(at: paragraphLocation, in: storage)
        paragraphStyle = detectedParagraphStyle(at: paragraphLocation, in: storage)
        activeListStyle = detectedListStyle(in: paragraphRange, storage: storage)

        // clearHighlight() 이후 커서가 하이라이트 텍스트 위에 있어도 툴바가 잘못 활성화되지 않도록
        // typingAttributes 기준으로 읽습니다.
        if clampedRange.length == 0, let tv = textView {
            if let uiColor = tv.typingAttributes[.backgroundColor] as? UIColor {
                highlightColor = Color(uiColor: uiColor)
            } else {
                highlightColor = nil
            }
        } else {
            highlightColor = resolvedSyncRange.flatMap { uniformHighlightColor(in: $0, storage: storage) }
        }
    }

    // MARK: - Private

    @MainActor
    private func toggleFontTrait(_ trait: UIFontDescriptor.SymbolicTraits, shouldEnable: Bool) {
        guard let storage = textStorage else { return }
        let clampedRange = clampedSelectedRange(in: storage)

        if clampedRange.length > 0 {
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: clampedRange) { value, range, _ in
                let currentFont = resolvedFont(from: value, at: range.location, in: storage)
                let updatedFont = updatedFont(from: currentFont, toggling: trait, enabled: shouldEnable)
                storage.addAttribute(.font, value: updatedFont, range: range)
            }
            if trait == .traitItalic {
                if shouldEnable {
                    storage.addAttribute(.editorItalic, value: true, range: clampedRange)
                } else {
                    storage.removeAttribute(.editorItalic, range: clampedRange)
                }
            }
            storage.endEditing()
            onFormattingApplied?()
        } else if let tv = textView {
            let currentFont = tv.typingAttributes[.font] as? UIFont ?? font(for: .body)
            tv.typingAttributes[.font] = updatedFont(from: currentFont, toggling: trait, enabled: shouldEnable)
            if trait == .traitItalic {
                _pendingItalicEnabled = shouldEnable
                if shouldEnable {
                    tv.typingAttributes[.editorItalic] = true
                } else {
                    tv.typingAttributes.removeValue(forKey: .editorItalic)
                }
            }
            notifyPlaceholderUpdate()
        }

        syncFormattingState()
    }

    @MainActor
    private func toggleTextDecoration(_ key: NSAttributedString.Key, enabled: Bool, style: Int) {
        guard let storage = textStorage else { return }
        let clampedRange = clampedSelectedRange(in: storage)

        if clampedRange.length > 0 {
            storage.beginEditing()
            if enabled {
                storage.addAttribute(key, value: style, range: clampedRange)
            } else {
                storage.removeAttribute(key, range: clampedRange)
            }
            storage.endEditing()
            onFormattingApplied?()
        } else if let tv = textView {
            if enabled {
                tv.typingAttributes[key] = style
            } else {
                tv.typingAttributes.removeValue(forKey: key)
            }
            notifyPlaceholderUpdate()
        }

        syncFormattingState()
    }

    @MainActor
    private func adjustParagraphIndent(by delta: CGFloat) {
        guard let storage = textStorage else { return }
        let paragraphRange = selectedParagraphRange(in: storage)
        guard paragraphRange.length > 0 || storage.length == 0 else { return }

        let ranges = paragraphRanges(in: paragraphRange, storage: storage)
        storage.beginEditing()

        for range in ranges {
            let location = safeAttributeLocation(for: range, in: storage)
            let currentStyle = nsParagraphStyle(at: location, in: storage)
            let updatedStyle = currentStyle.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            updatedStyle.headIndent = max(0, updatedStyle.headIndent + delta)

            if isBlockquoteAttributeEnabled(at: location, in: storage) {
                updatedStyle.firstLineHeadIndent = max(0, updatedStyle.firstLineHeadIndent + delta)
                let baseHeadIndent = (storage.attribute(.editorBlockquoteBaseHeadIndent, at: location, effectiveRange: nil) as? NSNumber)?.doubleValue
                    ?? Double(max(0, currentStyle.headIndent - blockquoteIndent))
                let baseFirstLineIndent = (storage.attribute(.editorBlockquoteBaseFirstLineHeadIndent, at: location, effectiveRange: nil) as? NSNumber)?.doubleValue
                    ?? Double(max(0, currentStyle.firstLineHeadIndent - blockquoteIndent))
                storage.addAttribute(.editorBlockquoteBaseHeadIndent, value: NSNumber(value: baseHeadIndent + Double(delta)), range: range)
                storage.addAttribute(.editorBlockquoteBaseFirstLineHeadIndent, value: NSNumber(value: baseFirstLineIndent + Double(delta)), range: range)
            }

            storage.addAttribute(.paragraphStyle, value: updatedStyle.copy() as? NSParagraphStyle ?? updatedStyle, range: range)
        }

        storage.endEditing()
        onFormattingApplied?()
        syncFormattingState()
    }

    private func syncFormattingStateFromTypingAttributes(_ tv: UITextView) {
        let attrs = tv.typingAttributes
        let typingFont = attrs[.font] as? UIFont ?? font(for: .body)

        if case .tableCell = toolbarMode {
        } else {
            toolbarMode = .default
        }

        isBold = isFontBold(typingFont)
        if let pending = _pendingItalicEnabled {
            isItalic = pending
        } else if let editorItalicFlag = attrs[.editorItalic] as? Bool {
            isItalic = editorItalicFlag
        } else if typingFont.fontName.hasPrefix("Pretendard") {
            isItalic = typingFont.fontDescriptor.matrix.c != 0.0
        } else {
            isItalic = typingFont.fontDescriptor.symbolicTraits.contains(.traitItalic)
        }
        isUnderline = (attrs[.underlineStyle] as? Int ?? 0) > 0
        isStrikethrough = (attrs[.strikethroughStyle] as? Int ?? 0) > 0
        isBlockquote = (attrs[NSAttributedString.Key.editorBlockquote] as? Bool) == true
        paragraphStyle = detectedParagraphStyleFromFont(typingFont)
        activeListStyle = nil

        if let uiColor = attrs[.backgroundColor] as? UIColor {
            highlightColor = Color(uiColor: uiColor)
        } else {
            highlightColor = nil
        }
    }

    private func detectedParagraphStyleFromFont(_ font: UIFont) -> EditorParagraphStyle {
        let size = font.pointSize
        if abs(size - 28) < 0.5 { return .title }
        if abs(size - 22) < 0.5 { return .heading }
        if abs(size - 17) < 0.5 { return .subheading }
        return .body
    }

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
