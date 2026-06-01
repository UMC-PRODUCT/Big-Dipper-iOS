//
//  EditorToolbarViewModel.swift
//  NoticeData
//
//  Created by 이예지 on 6/1/26.
//

import Foundation
import SwiftUI
import UIKit

/// 공지 에디터 툴바의 서식 상태와 편집 액션을 관리합니다.
@Observable
public final class EditorToolbarViewModel {

    // MARK: - Property

    /// 블록 인용문에 적용할 기본 들여쓰기 값입니다.
    private let blockquoteIndent: CGFloat = EditorConstants.blockquoteIndent

    /// 일반 들여쓰기 증감 단위입니다.
    private let indentStep: CGFloat = 24

    /// 현재 툴바의 표시 모드입니다.
    public var toolbarMode: EditorToolbarMode = .default

    /// 포맷 패널 노출 여부입니다.
    private(set) var isFormatPanelVisible: Bool = false

    /// 에디터(리치 텍스트 뷰)가 포커스 상태인지 여부입니다.
    private(set) var isEditorActive: Bool = false

    /// 선택 영역이 굵게 표시되는지 여부입니다.
    private(set) var isBold: Bool = false

    /// 선택 영역이 기울임꼴인지 여부입니다.
    private(set) var isItalic: Bool = false

    /// italic 토글 직후 UIKit 리셋을 거슬러 상태를 일시 보존합니다.
    private var _pendingItalicEnabled: Bool?

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
    public weak var textStorage: NSTextStorage?

    /// 타이핑 속성 제어를 위한 UITextView 참조입니다.
    public weak var textView: UITextView?

    /// 사용자가 명시적으로 활성화한 형광펜 색상입니다. nil이면 비활성 상태입니다.
    private(set) var activeHighlightColor: UIColor?

    /// 현재 UITextView의 선택 범위입니다.
    public var selectedRange: NSRange = NSRange(location: 0, length: 0)

    // MARK: - Function

    /// 기본 상태로 초기화합니다.
    public init() { }

    /// 선택 영역의 폰트에 굵게 서식을 토글합니다.
    @MainActor
    public func toggleBold() {
        toggleFontTrait(.traitBold, shouldEnable: !isBold)
    }

    /// 선택 영역의 폰트에 기울임꼴 서식을 토글합니다.
    @MainActor
    public func toggleItalic() {
        toggleFontTrait(.traitItalic, shouldEnable: !isItalic)
    }

    /// 첫 타이핑 후 italic 임시 추적 플래그를 초기화합니다.
    public func clearPendingItalic() {
        _pendingItalicEnabled = nil
    }

    /// 선택 영역의 텍스트에 밑줄 서식을 토글합니다.
    @MainActor
    public func toggleUnderline() {
        toggleTextDecoration(.underlineStyle, enabled: !isUnderline, style: NSUnderlineStyle.single.rawValue)
    }

    /// 선택 영역의 텍스트에 취소선 서식을 토글합니다.
    @MainActor
    public func toggleStrikethrough() {
        toggleTextDecoration(.strikethroughStyle, enabled: !isStrikethrough, style: NSUnderlineStyle.single.rawValue)
    }

    /// 현재 단락의 블록 인용문 스타일을 토글합니다.
    @MainActor
    public func toggleBlockquote() {
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

    /// 선택된 단락 범위에 지정한 단락 스타일 폰트를 적용합니다.
    @MainActor
    public func applyParagraphStyle(_ style: EditorParagraphStyle) {
        guard let storage = textStorage else { return }
        let paragraphRange = selectedParagraphRange(in: storage)
        let font = font(for: style)

        storage.beginEditing()
        storage.addAttribute(.font, value: font, range: paragraphRange)
        storage.endEditing()

        // 커서 이후 입력 텍스트에도 동일한 폰트가 적용되도록 typingAttributes 동기화
        textView?.typingAttributes[.font] = font

        onFormattingApplied?()
        syncFormattingState()
    }

    /// 현재 단락 시작 부분에 목록 접두사를 적용하거나, 이미 같은 스타일이면 제거합니다.
    @MainActor
    public func applyList(_ style: EditorListStyle) {
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

        // 삽입할 접두사에 적용할 폰트: 기존 단락 본문의 폰트 → typingAttributes 폰트 → body 기본폰트 순으로 사용
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

        // 커서가 기존 접두사 내부에 있었으면 새 접두사 뒤로, 아니면 delta만큼 보정
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

    /// 선택된 단락 범위의 들여쓰기를 한 단계 증가시킵니다.
    @MainActor
    public func applyIndent() {
        adjustParagraphIndent(by: indentStep)
    }

    /// 선택된 단락 범위의 들여쓰기를 한 단계 감소시킵니다.
    @MainActor
    public func applyOutdent() {
        adjustParagraphIndent(by: -indentStep)
    }

    /// 선택 영역의 배경 강조 색상을 적용하고, 이후 입력되는 텍스트에도 해당 색을 유지합니다.
    @MainActor
    public func applyHighlight(color: Color) {
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
    public func clearHighlight() {
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

    /// 활성 하이라이트 색상이 있으면 커서 위치의 기존 배경색과 비교하여
    /// 일치하는 경우에만 typingAttributes에 재적용합니다.
    /// 하이라이트 영역을 벗어나면 다음 입력에 색이 번지지 않도록 합니다.
    @MainActor
    public func reapplyActiveHighlightIfNeeded() {
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

    /// 포맷 패널 노출 상태를 토글합니다.
    public func toggleFormatPanel() {
        isFormatPanelVisible.toggle()
    }

    /// 포맷 패널을 닫습니다.
    public func dismissFormatPanel() {
        isFormatPanelVisible = false
    }

    /// 에디터 포커스 상태를 설정합니다.
    public func setEditorActive(_ active: Bool) {
        isEditorActive = active
    }

    /// 서식이 실제로 변경된 후 호출됩니다. (attributedText 바인딩 동기화용)
    public var onFormattingApplied: (() -> Void)?

    /// typingAttributes만 변경된 경우 placeholder 갱신만 수행합니다.
    /// attributedText 바인딩 재할당을 건너뛰어 불필요한 SwiftUI 갱신을 방지합니다.
    public var onPlaceholderNeedsUpdate: (() -> Void)?

    /// typingAttributes 변경 후 placeholder 갱신을 요청합니다.
    private func notifyPlaceholderUpdate() {
        onPlaceholderNeedsUpdate?()
    }

    /// 선택 영역의 실제 속성을 읽어 툴바 상태를 동기화합니다.
    @MainActor
    public func syncFormattingState() {
        guard let storage = textStorage else {
            resetFormattingState()
            return
        }

        // 빈 에디터 또는 EOF 빈 단락: typingAttributes만으로 상태를 결정합니다.
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
            // .editorItalic 커스텀 키를 우선 확인합니다.
            // UIKit이 typingAttributes를 재계산할 때 oblique matrix는 소실되지만
            // 커스텀 키는 reinject 패턴으로 재주입됩니다.
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

        // 선택 없을 때: typingAttributes 기준으로 하이라이트 상태를 읽어
        // clearHighlight() 이후에도 커서가 하이라이트된 텍스트 위에 있으면 툴바가 잘못 활성화되는 문제를 방지합니다.
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
            notifyPlaceholderUpdate()
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
    /// 빈 에디터 또는 EOF 빈 단락에서 typingAttributes만으로 툴바 상태를 동기화합니다.
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

    /// 폰트 크기로부터 문단 스타일을 추론합니다.
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
