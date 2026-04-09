//
//  EditorToolbarViewModel.swift
//  AppProduct
//
//  Created by euijjang97 on 4/8/26.
//

import Foundation
import SwiftUI
import UIKit

/// 공지 에디터 툴바의 서식 상태와 편집 액션을 관리합니다.
@Observable
final class EditorToolbarViewModel {

    // MARK: - Property

    /// 블록 인용문에 적용할 기본 들여쓰기 값입니다.
    private let blockquoteIndent: CGFloat = 14

    /// 일반 들여쓰기 증감 단위입니다.
    private let indentStep: CGFloat = 24

    /// 현재 툴바의 표시 모드입니다.
    var toolbarMode: EditorToolbarMode = .default

    /// 포맷 패널 노출 여부입니다.
    private(set) var isFormatPanelVisible: Bool = false

    /// 에디터(리치 텍스트 뷰)가 포커스 상태인지 여부입니다.
    private(set) var isEditorActive: Bool = false

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

    /// 타이핑 속성 제어를 위한 UITextView 참조입니다.
    weak var textView: UITextView?

    /// 사용자가 명시적으로 활성화한 형광펜 색상입니다. nil이면 비활성 상태입니다.
    private(set) var activeHighlightColor: UIColor?

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
        guard let storage = textStorage else { return }

        // 빈 텍스트: typingAttributes 에만 인용구 스타일 적용 (토글)
        if storage.length == 0 {
            guard let tv = textView else { return }
            let alreadyBlockquote = (tv.typingAttributes[NSAttributedString.Key.editorBlockquote] as? Bool) == true
            if alreadyBlockquote {
                tv.typingAttributes.removeValue(forKey: NSAttributedString.Key.editorBlockquote)
                tv.typingAttributes.removeValue(forKey: NSAttributedString.Key.editorBlockquoteBorderColor)
                tv.typingAttributes.removeValue(forKey: NSAttributedString.Key.editorBlockquoteBaseHeadIndent)
                tv.typingAttributes.removeValue(forKey: NSAttributedString.Key.editorBlockquoteBaseFirstLineHeadIndent)
                tv.typingAttributes.removeValue(forKey: .paragraphStyle)
                isBlockquote = false
            } else {
                let style = NSMutableParagraphStyle()
                style.headIndent = blockquoteIndent
                style.firstLineHeadIndent = blockquoteIndent
                tv.typingAttributes[.paragraphStyle] = style.copy() as! NSParagraphStyle
                tv.typingAttributes[NSAttributedString.Key.editorBlockquote] = true
                tv.typingAttributes[NSAttributedString.Key.editorBlockquoteBorderColor] = UIColor.systemGray3
                tv.typingAttributes[NSAttributedString.Key.editorBlockquoteBaseHeadIndent] = NSNumber(value: 0.0)
                tv.typingAttributes[NSAttributedString.Key.editorBlockquoteBaseFirstLineHeadIndent] = NSNumber(value: 0.0)
                isBlockquote = true
            }
            return
        }

        let paragraphRange = currentParagraphRange(in: storage)
        let baseLocation = safeAttributeLocation(for: paragraphRange, in: storage)
        let isCurrentlyBlockquote = isBlockquoteAttributeEnabled(at: baseLocation, in: storage)
        let currentStyle = nsParagraphStyle(at: baseLocation, in: storage)
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

        onFormattingApplied?()
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

        onFormattingApplied?()
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

        // 삽입할 접두사에 적용할 폰트: 기존 단락 본문의 폰트 → typingAttributes 폰트 → body 기본폰트 순으로 사용
        let contentOffset = replacementRange.location + (existingPrefixRange?.length ?? 0)
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

        // 접두사 삽입 후 커서를 접두사 바로 뒤로 이동
        let cursorAfterPrefix = NSRange(location: replacementRange.location + prefix.utf16.count, length: 0)
        selectedRange = cursorAfterPrefix
        textView?.selectedRange = cursorAfterPrefix
        onFormattingApplied?()
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

    /// 선택 영역의 배경 강조 색상을 적용하고, 이후 입력되는 텍스트에도 해당 색을 유지합니다.
    @MainActor
    func applyHighlight(color: Color) {
        let uiColor = UIColor(color)
        activeHighlightColor = uiColor

        // 선택 영역이 있으면 기존 텍스트에도 적용
        if let storage = textStorage {
            let clampedRange = clampedSelectedRange(in: storage)
            if clampedRange.length > 0 {
                storage.beginEditing()
                storage.addAttribute(.backgroundColor, value: uiColor, range: clampedRange)
                storage.endEditing()
            }
        }

        // 이후 입력 텍스트에도 적용 (typingAttributes)
        textView?.typingAttributes[.backgroundColor] = uiColor

        onFormattingApplied?()
        syncFormattingState()
    }

    /// 선택 영역의 배경 강조 색상을 제거하고, 이후 입력되는 텍스트의 하이라이트도 해제합니다.
    @MainActor
    func clearHighlight() {
        activeHighlightColor = nil

        // 선택 영역이 있으면 기존 텍스트에서도 제거
        if let storage = textStorage {
            let clampedRange = clampedSelectedRange(in: storage)
            if clampedRange.length > 0 {
                storage.beginEditing()
                storage.removeAttribute(.backgroundColor, range: clampedRange)
                storage.endEditing()
            }
        }

        // 이후 입력 텍스트 하이라이트 해제
        textView?.typingAttributes.removeValue(forKey: .backgroundColor)

        onFormattingApplied?()
        syncFormattingState()
    }

    /// 활성 하이라이트 색상이 있으면 typingAttributes에 재적용합니다.
    /// UIKit이 커서 이동 시 typingAttributes를 덮어쓰는 문제를 방지합니다.
    @MainActor
    func reapplyActiveHighlightIfNeeded() {
        guard let uiColor = activeHighlightColor else { return }
        textView?.typingAttributes[.backgroundColor] = uiColor
    }

    /// 포맷 패널 노출 상태를 토글합니다.
    func toggleFormatPanel() {
        isFormatPanelVisible.toggle()
    }

    /// 포맷 패널을 닫습니다.
    func dismissFormatPanel() {
        isFormatPanelVisible = false
    }

    /// 에디터 포커스 상태를 설정합니다.
    func setEditorActive(_ active: Bool) {
        isEditorActive = active
    }

    /// 서식이 실제로 변경된 후 호출됩니다. (attributedText 바인딩 동기화용)
    var onFormattingApplied: (() -> Void)?

    /// 선택 영역의 실제 속성을 읽어 툴바 상태를 동기화합니다.
    @MainActor
    func syncFormattingState() {
        guard let storage = textStorage else {
            resetFormattingState()
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
            isBold = typingFont.fontDescriptor.symbolicTraits.contains(.traitBold)
            isItalic = typingFont.fontDescriptor.symbolicTraits.contains(.traitItalic)
            isUnderline = (tv.typingAttributes[.underlineStyle] as? Int ?? 0) > 0
            isStrikethrough = (tv.typingAttributes[.strikethroughStyle] as? Int ?? 0) > 0
        } else {
            isBold = resolvedSyncRange.map { rangeHasUniformFontTrait($0, trait: .traitBold, in: storage) } ?? false
            isItalic = resolvedSyncRange.map { rangeHasUniformFontTrait($0, trait: .traitItalic, in: storage) } ?? false
            isUnderline = resolvedSyncRange.map { rangeHasUniformTextDecoration($0, key: .underlineStyle, in: storage) } ?? false
            isStrikethrough = resolvedSyncRange.map { rangeHasUniformTextDecoration($0, key: .strikethroughStyle, in: storage) } ?? false
        }
        isBlockquote = isBlockquoteAttributeEnabled(at: paragraphLocation, in: storage)
        paragraphStyle = detectedParagraphStyle(at: paragraphLocation, in: storage)
        activeListStyle = detectedListStyle(in: paragraphRange, storage: storage)
        highlightColor = resolvedSyncRange.flatMap { uniformHighlightColor(in: $0, storage: storage) }
    }

    // MARK: - Private

    /// 선택 영역의 폰트 심볼릭 트레이트를 토글합니다.
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
            storage.endEditing()
            onFormattingApplied?()
        } else if let tv = textView {
            let currentFont = tv.typingAttributes[.font] as? UIFont ?? font(for: .body)
            tv.typingAttributes[.font] = updatedFont(from: currentFont, toggling: trait, enabled: shouldEnable)
        }

        syncFormattingState()
    }

    /// 선택 영역의 선형 텍스트 장식을 토글합니다.
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
        }

        syncFormattingState()
    }

    /// 선택된 단락 범위의 들여쓰기 값을 안전하게 조정합니다.
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
