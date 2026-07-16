//
//  RichTextCoordinator+Blockquote.swift
//  NoticePresentation
//
//  Created by 이예지 on 6/30/26.
//

import UIKit

extension RichTextCoordinator {

    // MARK: - Blockquote Enter

    /// 인용구 단락에서 Enter 키 입력을 처리합니다.
    /// - 빈 인용구 줄: 인용구 속성 제거(탈출)하고 false 반환
    /// - 내용 있는 인용구 줄: 같은 인용구 속성으로 새 줄 삽입하고 false 반환
    func handleReturnInBlockquote(textView: BlockquoteTextView, range: NSRange) -> Bool {
        let storage = textView.textStorage
        guard storage.length > 0 else { return true }

        // paragraphRange 계산은 EOF 위치(storage.length)를 허용합니다.
        // storage.length - 1 로 clamp하면 trailing \n이 있는 경우 이전 단락을 오인합니다.
        let paragraphLocation = min(range.location, storage.length)
        let nsString = storage.string as NSString
        let paragraphRange = nsString.paragraphRange(
            for: NSRange(location: paragraphLocation, length: 0)
        )

        // EOF 빈 단락(location >= storage.length)은 typingAttributes로 blockquote 상태를 확인합니다.
        let isInBlockquote: Bool
        if paragraphRange.location >= storage.length {
            isInBlockquote = (textView.typingAttributes[.editorBlockquote] as? Bool) == true
        } else {
            isInBlockquote = (storage.attribute(
                .editorBlockquote,
                at: paragraphRange.location,
                effectiveRange: nil
            ) as? Bool) == true
        }
        guard isInBlockquote else { return true }

        // attribute 읽기용 위치: EOF 빈 단락이면 trailing \n(storage.length - 1)에서 blockquote 속성을 읽습니다.
        let checkLocation = min(paragraphRange.location, max(0, storage.length - 1))
        let paragraphText = nsString.substring(with: paragraphRange)
        // zero-width space(\u{200B})는 빈 인용구 플레이스홀더이므로 내용으로 취급하지 않습니다.
        let hasContent = paragraphText.contains {
            !$0.isNewline && !$0.isWhitespace && $0 != "\u{200B}"
        }

        if !hasContent {
            // 빈 인용구 줄 → 인용구 탈출 (새 줄 삽입 없이 속성만 제거)
            let baseHead = (storage.attribute(
                .editorBlockquoteBaseHeadIndent,
                at: checkLocation,
                effectiveRange: nil
            ) as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
            let baseLine = (storage.attribute(
                .editorBlockquoteBaseFirstLineHeadIndent,
                at: checkLocation,
                effectiveRange: nil
            ) as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0

            let existingParaStyle = storage.attribute(
                .paragraphStyle,
                at: checkLocation,
                effectiveRange: nil
            ) as? NSParagraphStyle ?? .default
            let normalStyle = (existingParaStyle.mutableCopy() as? NSMutableParagraphStyle)
                ?? NSMutableParagraphStyle()
            normalStyle.headIndent = baseHead
            normalStyle.firstLineHeadIndent = baseLine

            storage.beginEditing()
            // ZWS 플레이스홀더가 포함되어 있으면 함께 제거합니다.
            let cleanedText = paragraphText.replacingOccurrences(of: "\u{200B}", with: "")
            if cleanedText.count != paragraphText.count {
                storage.replaceCharacters(in: paragraphRange, with: cleanedText)
                // ZWS 제거 후 해당 단락이 완전히 사라졌거나(EOF) 스토리지가 비었으면
                // 스토리지 속성 수정을 건너뛰고 typingAttributes만 정리합니다.
                if storage.length > 0, paragraphRange.location < storage.length {
                    let safeLocation = min(paragraphRange.location, storage.length - 1)
                    let updatedRange = (storage.string as NSString)
                        .paragraphRange(for: NSRange(location: safeLocation, length: 0))
                    if updatedRange.length > 0 {
                        storage.addAttribute(
                            .paragraphStyle,
                            value: (normalStyle.copy() as? NSParagraphStyle) ?? normalStyle,
                            range: updatedRange
                        )
                        storage.removeAttribute(.editorBlockquote, range: updatedRange)
                        storage.removeAttribute(.editorBlockquoteBorderColor, range: updatedRange)
                        storage.removeAttribute(
                            .editorBlockquoteBaseHeadIndent,
                            range: updatedRange
                        )
                        storage.removeAttribute(
                            .editorBlockquoteBaseFirstLineHeadIndent,
                            range: updatedRange
                        )
                    }
                }
            } else {
                storage.addAttribute(
                    .paragraphStyle,
                    value: (normalStyle.copy() as? NSParagraphStyle) ?? normalStyle,
                    range: paragraphRange
                )
                storage.removeAttribute(.editorBlockquote, range: paragraphRange)
                storage.removeAttribute(.editorBlockquoteBorderColor, range: paragraphRange)
                storage.removeAttribute(.editorBlockquoteBaseHeadIndent, range: paragraphRange)
                storage.removeAttribute(
                    .editorBlockquoteBaseFirstLineHeadIndent,
                    range: paragraphRange
                )
            }
            storage.endEditing()

            textView.typingAttributes.removeValue(forKey: .editorBlockquote)
            textView.typingAttributes.removeValue(forKey: .editorBlockquoteBorderColor)
            textView.typingAttributes.removeValue(forKey: .editorBlockquoteBaseHeadIndent)
            textView.typingAttributes.removeValue(forKey: .editorBlockquoteBaseFirstLineHeadIndent)
            let mutableNormal = (normalStyle.mutableCopy() as? NSMutableParagraphStyle)
                ?? NSMutableParagraphStyle()
            textView.typingAttributes[.paragraphStyle] =
                (mutableNormal.copy() as? NSParagraphStyle) ?? mutableNormal

            // 인용구 탈출 시 경계선을 즉시 제거합니다.
            // setNeedsBlockquoteRefresh()는 다음 layoutSubviews까지 지연되어
            // 이전 경계선이 한 프레임 남을 수 있습니다.
            textView.refreshBlockquoteBorders()
            parent.attributedText = textView.attributedText
            parent.toolbarViewModel.selectedRange = textView.selectedRange
            parent.toolbarViewModel.syncFormattingState()
            return false
        }

        // 내용 있는 인용구 줄 → 같은 인용구 속성으로 새 줄 이어받기
        let borderColor = storage.attribute(
            .editorBlockquoteBorderColor,
            at: checkLocation,
            effectiveRange: nil
        ) as? UIColor ?? UIColor.systemGray3
        let baseHeadNum = storage.attribute(
            .editorBlockquoteBaseHeadIndent,
            at: checkLocation,
            effectiveRange: nil
        ) as? NSNumber
        let baseLineNum = storage.attribute(
            .editorBlockquoteBaseFirstLineHeadIndent,
            at: checkLocation,
            effectiveRange: nil
        ) as? NSNumber
        let existingStyle = storage.attribute(
            .paragraphStyle,
            at: checkLocation,
            effectiveRange: nil
        ) as? NSParagraphStyle ?? NSParagraphStyle.default
        let newStyle = (existingStyle.mutableCopy() as? NSMutableParagraphStyle)
            ?? NSMutableParagraphStyle()

        let fontLocation = range.location > 0 ? min(range.location - 1, storage.length - 1) : 0
        let currentFont = storage.attribute(.font, at: fontLocation, effectiveRange: nil)
            as? UIFont
            ?? textView.typingAttributes[.font] as? UIFont
            ?? UIFont.preferredFont(forTextStyle: .body)

        var newAttrs: [NSAttributedString.Key: Any] = [
            .paragraphStyle: (newStyle.copy() as? NSParagraphStyle) ?? newStyle,
            .font: currentFont,
            NSAttributedString.Key.editorBlockquote: true,
            NSAttributedString.Key.editorBlockquoteBorderColor: borderColor,
        ]
        if let b = baseHeadNum { newAttrs[.editorBlockquoteBaseHeadIndent] = b }
        if let b = baseLineNum { newAttrs[.editorBlockquoteBaseFirstLineHeadIndent] = b }

        storage.beginEditing()
        storage.replaceCharacters(
            in: range,
            with: NSAttributedString(string: "\n", attributes: newAttrs)
        )
        storage.endEditing()

        let newCursor = range.location + 1
        textView.selectedRange = NSRange(location: newCursor, length: 0)
        scheduleScrollCursorToVisible(in: textView)

        // 인라인 서식이 다음 인용구 줄로 번지지 않도록 typingAttributes를 재구성합니다.
        textView.typingAttributes = newAttrs

        textView.setNeedsBlockquoteRefresh()
        parent.attributedText = textView.attributedText
        parent.toolbarViewModel.selectedRange = NSRange(location: newCursor, length: 0)
        parent.toolbarViewModel.syncFormattingState()
        return false
    }

    // MARK: - Blockquote TypingAttributes Cleanup

    /// 백스페이스 등으로 텍스트가 모두 삭제되었거나
    /// 현재 단락에 인용구 속성이 없는데 typingAttributes에 인용구 들여쓰기가
    /// 남아 있는 경우, typingAttributes와 storage 단락 속성을 모두 리셋합니다.
    func cleanupBlockquoteTypingAttributesIfNeeded(
        in textView: UITextView
    ) {
        let storage = textView.textStorage
        let blockquoteIndent = EditorConstants.blockquoteIndent

        // 현재 단락의 storage 속성도 확인: 인용구가 아닌데 들여쓰기가 남아있는지
        // 단락 시작 위치에서 확인하여 커스텀 키가 없는 중간 문자에 의한 오탐을 방지합니다.
        let cursorLoc = textView.selectedRange.location

        let hasStorageBlockquoteIndent: Bool = {
            guard storage.length > 0 else { return false }
            let pRange = (storage.string as NSString).paragraphRange(
                for: NSRange(location: min(cursorLoc, storage.length), length: 0)
            )
            let loc = pRange.location < storage.length
                ? pRange.location
                : max(0, storage.length - 1)
            let blockquoteFlag = storage.attribute(.editorBlockquote, at: loc, effectiveRange: nil)
            guard (blockquoteFlag as? Bool) != true else { return false }
            // indent 크기와 base indent 존재 여부를 함께 확인하여 오탐을 방지합니다.
            let ps = storage.attribute(.paragraphStyle, at: loc, effectiveRange: nil)
                as? NSParagraphStyle
            let hasBaseAttr = storage.attribute(
                .editorBlockquoteBaseHeadIndent,
                at: loc,
                effectiveRange: nil
            ) != nil
            return (ps?.headIndent ?? 0) >= blockquoteIndent || hasBaseAttr
        }()

        // typingAttributes에 인용구 관련 속성이 없으면 정리 불필요
        let hasBlockquoteTyping = (textView.typingAttributes[.editorBlockquote] as? Bool) == true
        let typingStyle = textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle
        let hasBlockquoteIndent = (typingStyle?.headIndent ?? 0) >= blockquoteIndent

        guard hasBlockquoteTyping || hasBlockquoteIndent || hasStorageBlockquoteIndent else {
            return
        }

        // 저장소가 비어있거나 현재 단락에 인용구 속성이 없으면 정리
        let isCurrentParagraphBlockquote: Bool = {
            guard storage.length > 0 else { return false }
            let pRange = (storage.string as NSString).paragraphRange(
                for: NSRange(location: min(cursorLoc, storage.length), length: 0)
            )
            let loc = pRange.location < storage.length
                ? pRange.location
                : max(0, storage.length - 1)
            let blockquoteFlag = storage.attribute(.editorBlockquote, at: loc, effectiveRange: nil)
            return (blockquoteFlag as? Bool) == true
        }()

        // typingAttributes에 인용구가 명시적으로 활성화되어 있으면
        // 인용구 입력 중이므로 정리하지 않습니다.
        // (storage가 비어도 사용자가 인용구 모드를 유지하고 있을 수 있음)
        if hasBlockquoteTyping {
            return
        }

        guard storage.length == 0 || !isCurrentParagraphBlockquote else { return }

        // base indent 값을 먼저 읽어 둔 뒤 키를 삭제합니다.
        let typingHeadValue = textView.typingAttributes[.editorBlockquoteBaseHeadIndent]
        let typingBaseHead = (typingHeadValue as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
        let typingLineValue = textView.typingAttributes[.editorBlockquoteBaseFirstLineHeadIndent]
        let typingBaseLine = (typingLineValue as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0

        textView.typingAttributes.removeValue(forKey: .editorBlockquote)
        textView.typingAttributes.removeValue(forKey: .editorBlockquoteBorderColor)
        textView.typingAttributes.removeValue(forKey: .editorBlockquoteBaseHeadIndent)
        textView.typingAttributes.removeValue(forKey: .editorBlockquoteBaseFirstLineHeadIndent)

        // 기존 paragraphStyle을 보존하고 indent를 base 값으로 복원합니다.
        let existingTypingStyle = textView.typingAttributes[.paragraphStyle]
            as? NSParagraphStyle ?? .default
        let cleanTypingStyle = (existingTypingStyle.mutableCopy() as? NSMutableParagraphStyle)
            ?? NSMutableParagraphStyle()
        cleanTypingStyle.headIndent = typingBaseHead
        cleanTypingStyle.firstLineHeadIndent = typingBaseLine
        textView.typingAttributes[.paragraphStyle] = cleanTypingStyle.copy()

        // storage의 현재 단락에 남은 인용구 들여쓰기도 정리
        if hasStorageBlockquoteIndent, storage.length > 0 {
            let loc = min(cursorLoc, storage.length - 1)
            let nsString = storage.string as NSString
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: loc, length: 0))
            if paragraphRange.length > 0 {
                let safeLoc = min(paragraphRange.location, storage.length - 1)
                let existingPS = storage.attribute(
                    .paragraphStyle,
                    at: safeLoc,
                    effectiveRange: nil
                ) as? NSParagraphStyle ?? .default
                let baseHead = (storage.attribute(
                    .editorBlockquoteBaseHeadIndent,
                    at: safeLoc,
                    effectiveRange: nil
                ) as? NSNumber)
                    .map { CGFloat($0.doubleValue) } ?? 0
                let baseLine = (storage.attribute(
                    .editorBlockquoteBaseFirstLineHeadIndent,
                    at: safeLoc,
                    effectiveRange: nil
                ) as? NSNumber)
                    .map { CGFloat($0.doubleValue) } ?? 0
                let cleanPS = (existingPS.mutableCopy() as? NSMutableParagraphStyle)
                    ?? NSMutableParagraphStyle()
                cleanPS.headIndent = baseHead
                cleanPS.firstLineHeadIndent = baseLine

                storage.beginEditing()
                storage.addAttribute(
                    .paragraphStyle,
                    value: cleanPS.copy() as Any,
                    range: paragraphRange
                )
                storage.removeAttribute(.editorBlockquote, range: paragraphRange)
                storage.removeAttribute(.editorBlockquoteBorderColor, range: paragraphRange)
                storage.removeAttribute(.editorBlockquoteBaseHeadIndent, range: paragraphRange)
                storage.removeAttribute(
                    .editorBlockquoteBaseFirstLineHeadIndent,
                    range: paragraphRange
                )
                storage.endEditing()
            }
        }

        parent.toolbarViewModel.syncFormattingState()
    }

    /// 인용구가 아닌 단락에 인용구 들여쓰기(paragraphStyle)가 남아있으면
    /// UIKit이 문자를 삽입하기 전에 미리 제거합니다.
    /// `shouldChangeTextIn` 시점에 호출하여 새 문자에 들여쓰기가 상속되는 것을 방지합니다.
    func cleanupOrphanedBlockquoteIndent(in textView: BlockquoteTextView, at location: Int) {
        let storage = textView.textStorage
        let blockquoteIndent = EditorConstants.blockquoteIndent
        guard storage.length > 0 else { return }

        // typingAttributes에 인용구가 활성화되어 있으면 인용구 입력 중이므로 정리하지 않습니다.
        guard (textView.typingAttributes[.editorBlockquote] as? Bool) != true else { return }

        // 단락 시작 위치에서 확인하여 커스텀 키가 없는 중간 문자에 의한 오탐을 방지합니다.
        let nsString = storage.string as NSString
        let paraRange = nsString.paragraphRange(
            for: NSRange(location: min(location, storage.length), length: 0)
        )
        let loc = paraRange.location < storage.length
            ? paraRange.location
            : max(0, storage.length - 1)

        let blockquoteFlag = storage.attribute(.editorBlockquote, at: loc, effectiveRange: nil)
        guard (blockquoteFlag as? Bool) != true else { return }

        let ps = storage.attribute(.paragraphStyle, at: loc, effectiveRange: nil)
            as? NSParagraphStyle
        let hasBaseAttr = storage.attribute(
            .editorBlockquoteBaseHeadIndent,
            at: loc,
            effectiveRange: nil
        ) != nil
        guard (ps?.headIndent ?? 0) >= blockquoteIndent || hasBaseAttr else { return }

        let paragraphRange = nsString.paragraphRange(for: NSRange(location: loc, length: 0))
        guard paragraphRange.length > 0 else { return }

        // 기존 paragraphStyle을 보존하고 indent를 base 값으로 복원합니다.
        let baseHead = (storage.attribute(
            .editorBlockquoteBaseHeadIndent,
            at: loc,
            effectiveRange: nil
        ) as? NSNumber)
            .map { CGFloat($0.doubleValue) } ?? 0
        let baseLine = (storage.attribute(
            .editorBlockquoteBaseFirstLineHeadIndent,
            at: loc,
            effectiveRange: nil
        ) as? NSNumber)
            .map { CGFloat($0.doubleValue) } ?? 0
        let cleanStyle = (ps?.mutableCopy() as? NSMutableParagraphStyle)
            ?? NSMutableParagraphStyle()
        cleanStyle.headIndent = baseHead
        cleanStyle.firstLineHeadIndent = baseLine

        storage.beginEditing()
        storage.addAttribute(
            .paragraphStyle,
            value: cleanStyle.copy() as Any,
            range: paragraphRange
        )
        storage.removeAttribute(.editorBlockquote, range: paragraphRange)
        storage.removeAttribute(.editorBlockquoteBorderColor, range: paragraphRange)
        storage.removeAttribute(.editorBlockquoteBaseHeadIndent, range: paragraphRange)
        storage.removeAttribute(.editorBlockquoteBaseFirstLineHeadIndent, range: paragraphRange)
        storage.endEditing()

        // typingAttributes도 동기화: base indent로 복원
        let typingHeadValue = textView.typingAttributes[.editorBlockquoteBaseHeadIndent]
        let typingBaseHead = (typingHeadValue as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
        let typingLineValue = textView.typingAttributes[.editorBlockquoteBaseFirstLineHeadIndent]
        let typingBaseLine = (typingLineValue as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
        let existingTypingPS = textView.typingAttributes[.paragraphStyle]
            as? NSParagraphStyle ?? .default
        let cleanTypingPS = (existingTypingPS.mutableCopy() as? NSMutableParagraphStyle)
            ?? NSMutableParagraphStyle()
        cleanTypingPS.headIndent = typingBaseHead
        cleanTypingPS.firstLineHeadIndent = typingBaseLine
        textView.typingAttributes.removeValue(forKey: .editorBlockquote)
        textView.typingAttributes.removeValue(forKey: .editorBlockquoteBorderColor)
        textView.typingAttributes.removeValue(forKey: .editorBlockquoteBaseHeadIndent)
        textView.typingAttributes.removeValue(forKey: .editorBlockquoteBaseFirstLineHeadIndent)
        textView.typingAttributes[.paragraphStyle] = cleanTypingPS.copy()
    }

    /// UIKit이 커서 이동 시 typingAttributes에서 버린 인용구 커스텀 키를 재주입합니다.
    ///
    /// UIKit은 `.font`, `.paragraphStyle` 등 표준 키만 typingAttributes에 유지하고,
    /// `.editorBlockquote` 등 커스텀 키는 소실됩니다.
    /// storage의 현재 단락 시작 위치에서 인용구 속성을 읽어 typingAttributes에 반영합니다.
    func reinjectBlockquoteTypingAttributesIfNeeded(in textView: UITextView) {
        let storage = textView.textStorage
        guard storage.length > 0 else { return }

        let cursorLoc = textView.selectedRange.location
        let nsString = storage.string as NSString
        let paragraphRange = nsString.paragraphRange(
            for: NSRange(location: min(cursorLoc, storage.length), length: 0)
        )
        let checkLoc = paragraphRange.location < storage.length
            ? paragraphRange.location
            : max(0, storage.length - 1)

        // italic은 인라인 속성이므로 단락 시작이 아닌 커서 앞 문자를 기준으로 조회합니다.
        let italicCheckLoc: Int = {
            let selRange = textView.selectedRange
            if selRange.length > 0 {
                return max(0, min(selRange.location, storage.length - 1))
            }
            return min(cursorLoc > 0 ? cursorLoc - 1 : 0, storage.length - 1)
        }()

        let blockquoteFlag = storage.attribute(
            .editorBlockquote,
            at: checkLoc,
            effectiveRange: nil
        )
        let isBlockquote = (blockquoteFlag as? Bool) == true

        if isBlockquote {
            textView.typingAttributes[.editorBlockquote] = true
            if let color = storage.attribute(
                .editorBlockquoteBorderColor,
                at: checkLoc,
                effectiveRange: nil
            ) {
                textView.typingAttributes[.editorBlockquoteBorderColor] = color
            }
            if let ps = storage.attribute(.paragraphStyle, at: checkLoc, effectiveRange: nil) {
                textView.typingAttributes[.paragraphStyle] = ps
            }
            if let baseHead = storage.attribute(
                .editorBlockquoteBaseHeadIndent,
                at: checkLoc,
                effectiveRange: nil
            ) {
                textView.typingAttributes[.editorBlockquoteBaseHeadIndent] = baseHead
            }
            if let baseLine = storage.attribute(
                .editorBlockquoteBaseFirstLineHeadIndent,
                at: checkLoc,
                effectiveRange: nil
            ) {
                textView.typingAttributes[.editorBlockquoteBaseFirstLineHeadIndent] = baseLine
            }
        } else {
            textView.typingAttributes.removeValue(forKey: .editorBlockquote)
            textView.typingAttributes.removeValue(forKey: .editorBlockquoteBorderColor)
            textView.typingAttributes.removeValue(forKey: .editorBlockquoteBaseHeadIndent)
            textView.typingAttributes.removeValue(forKey: .editorBlockquoteBaseFirstLineHeadIndent)
        }

        // Pretendard italic: storage의 .editorItalic 속성을 typingAttributes에 재주입합니다.
        // UIKit은 커서 이동 시 typingAttributes를 재계산하면서 oblique matrix를 소실시킵니다.
        let italicFlag = storage.attribute(.editorItalic, at: italicCheckLoc, effectiveRange: nil)
        let isItalicInStorage = (italicFlag as? Bool) == true

        if isItalicInStorage {
            textView.typingAttributes[.editorItalic] = true
            let fontValue = storage.attribute(.font, at: italicCheckLoc, effectiveRange: nil)
            if let storedFont = fontValue as? UIFont,
               storedFont.fontDescriptor.matrix.c != 0.0 {
                textView.typingAttributes[.font] = storedFont
            }
        } else {
            textView.typingAttributes.removeValue(forKey: .editorItalic)
        }
    }

    // MARK: - ZWS Cleanup

    /// 빈 인용구 활성화 시 삽입한 ZWS 플레이스홀더를 정리합니다.
    /// 실제 콘텐츠가 입력된 후에만 ZWS를 제거합니다.
    /// 커서가 위치한 단락만 스캔하여 O(1) 비용으로 처리합니다.
    func stripZeroWidthSpacesIfNeeded(in textView: UITextView) {
        let storage = textView.textStorage
        guard storage.length > 0 else { return }

        // 커서 주변 단락으로 범위를 제한하여 성능을 보장합니다.
        let cursorLocation = textView.selectedRange.location
        let nsString = storage.string as NSString
        let paragraphRange = nsString.paragraphRange(
            for: NSRange(location: min(cursorLocation, max(0, storage.length - 1)), length: 0)
        )
        let paragraphText = nsString.substring(with: paragraphRange)

        guard paragraphText.contains("\u{200B}") else { return }
        // ZWS 외에 실제 콘텐츠가 없으면(빈 인용구 상태) 제거하지 않습니다.
        let hasRealContent = paragraphText.contains(where: {
            !$0.isNewline && !$0.isWhitespace && $0 != "\u{200B}"
        })
        guard hasRealContent else { return }

        // ZWS 제거 전: 해당 단락의 인용구 속성을 기록합니다.
        let checkLoc = min(paragraphRange.location, storage.length - 1)
        let blockquoteFlag = storage.attribute(
            .editorBlockquote,
            at: checkLoc,
            effectiveRange: nil
        )
        let wasBlockquote = (blockquoteFlag as? Bool) == true
        let savedBorderColor = storage.attribute(
            .editorBlockquoteBorderColor,
            at: checkLoc,
            effectiveRange: nil
        ) as? UIColor
        let savedBaseHead = storage.attribute(
            .editorBlockquoteBaseHeadIndent,
            at: checkLoc,
            effectiveRange: nil
        ) as? NSNumber
        let savedBaseLine = storage.attribute(
            .editorBlockquoteBaseFirstLineHeadIndent,
            at: checkLoc,
            effectiveRange: nil
        ) as? NSNumber
        let savedParagraphStyle = storage.attribute(
            .paragraphStyle,
            at: checkLoc,
            effectiveRange: nil
        ) as? NSParagraphStyle

        // 단락 내 ZWS 위치를 수집한 뒤 뒤에서부터 삭제합니다.
        let paragraphNSString = paragraphText as NSString
        var zwsOffsets: [Int] = []
        var searchStart = 0
        while searchStart < paragraphNSString.length {
            let range = paragraphNSString.range(
                of: "\u{200B}",
                range: NSRange(
                    location: searchStart,
                    length: paragraphNSString.length - searchStart
                )
            )
            guard range.location != NSNotFound else { break }
            zwsOffsets.append(range.location)
            searchStart = range.location + range.length
        }
        guard !zwsOffsets.isEmpty else { return }

        let zwsBeforeCursor = zwsOffsets
            .filter { paragraphRange.location + $0 < cursorLocation }
            .count

        storage.beginEditing()
        for offset in zwsOffsets.reversed() {
            storage.replaceCharacters(
                in: NSRange(location: paragraphRange.location + offset, length: 1),
                with: ""
            )
        }

        // ZWS 제거 후: 인용구 속성 세트 전체를 무조건 재적용합니다.
        // replaceCharacters로 ZWS를 제거하면 attribute run이 병합되면서
        // 일부 속성만 소실될 수 있으므로, 전체 세트를 일관되게 재적용합니다.
        if wasBlockquote, storage.length > 0 {
            let updatedLoc = min(paragraphRange.location, max(0, storage.length - 1))
            let updatedRange = (storage.string as NSString).paragraphRange(
                for: NSRange(location: updatedLoc, length: 0)
            )
            if updatedRange.length > 0 {
                storage.addAttribute(.editorBlockquote, value: true, range: updatedRange)
                if let color = savedBorderColor {
                    storage.addAttribute(
                        .editorBlockquoteBorderColor,
                        value: color,
                        range: updatedRange
                    )
                }
                if let ps = savedParagraphStyle {
                    storage.addAttribute(.paragraphStyle, value: ps, range: updatedRange)
                }
                if let baseHead = savedBaseHead {
                    storage.addAttribute(
                        .editorBlockquoteBaseHeadIndent,
                        value: baseHead,
                        range: updatedRange
                    )
                }
                if let baseLine = savedBaseLine {
                    storage.addAttribute(
                        .editorBlockquoteBaseFirstLineHeadIndent,
                        value: baseLine,
                        range: updatedRange
                    )
                }
            }
        }
        storage.endEditing()

        let newCursor = max(0, cursorLocation - zwsBeforeCursor)
        isSuppressingSelectionSync = true
        textView.selectedRange = NSRange(location: min(newCursor, storage.length), length: 0)
        isSuppressingSelectionSync = false

        // typingAttributes 복원은 selectedRange 변경 이후에 수행합니다.
        // UIKit은 selectedRange 변경 시 typingAttributes를 재계산하면서
        // 커스텀 키를 버리므로, 재계산 후에 덮어써야 유지됩니다.
        if wasBlockquote {
            textView.typingAttributes[.editorBlockquote] = true
            if let color = savedBorderColor {
                textView.typingAttributes[.editorBlockquoteBorderColor] = color
            }
            if let ps = savedParagraphStyle {
                textView.typingAttributes[.paragraphStyle] = ps
            }
            if let baseHead = savedBaseHead {
                textView.typingAttributes[.editorBlockquoteBaseHeadIndent] = baseHead
            }
            if let baseLine = savedBaseLine {
                textView.typingAttributes[.editorBlockquoteBaseFirstLineHeadIndent] = baseLine
            }
        }

        parent.toolbarViewModel.selectedRange = textView.selectedRange
        parent.toolbarViewModel.syncFormattingState()
    }
}
