//
//  RichTextCoordinator+List.swift
//  AppProduct
//

import UIKit

extension RichTextCoordinator {

    // MARK: - List Enter

    func handleReturnInList(textView: BlockquoteTextView, range: NSRange) -> Bool {
        let storage = textView.textStorage
        guard storage.length > 0 else { return true }

        // paragraphRange 계산은 EOF 위치(storage.length)를 허용합니다.
        // storage.length - 1 로 clamp하면 trailing \n이 있는 경우 이전 단락을 오인합니다.
        let paragraphLocation = min(range.location, storage.length)
        let nsString = storage.string as NSString
        let paragraphRange = nsString.paragraphRange(for: NSRange(location: paragraphLocation, length: 0))
        // EOF 빈 단락(location >= storage.length): detectListPrefix가 nil을 반환합니다.
        let paragraphText = paragraphRange.location < storage.length ? nsString.substring(with: paragraphRange) : ""

        guard let (prefix, listKind) = detectListPrefix(in: paragraphText) else {
            return true
        }

        let prefixNSLength = (prefix as NSString).length
        let paragraphNSStr = paragraphText as NSString
        let contentAfterPrefix = paragraphNSStr.length > prefixNSLength ? paragraphNSStr.substring(from: prefixNSLength) : ""
        let hasContent = contentAfterPrefix.contains { !$0.isNewline && !$0.isWhitespace }

        if !hasContent {
            // 빈 목록 줄: 접두사만 제거하고 목록 탈출
            let removeRange = NSRange(location: paragraphRange.location, length: prefixNSLength)
            let fontLocation = min(paragraphRange.location, storage.length - 1)
            let currentFont = storage.attribute(.font, at: fontLocation, effectiveRange: nil) as? UIFont
                ?? UIFont.preferredFont(forTextStyle: .body)

            storage.beginEditing()
            storage.replaceCharacters(in: removeRange, with: "")
            let updatedParagraphRange = (storage.string as NSString)
                .paragraphRange(for: NSRange(location: paragraphRange.location, length: 0))
            storage.removeAttribute(.editorListStyle, range: updatedParagraphRange)
            storage.endEditing()

            // 목록 탈출 시 인라인 서식을 정리합니다.
            var cleanAttrs: [NSAttributedString.Key: Any] = [.font: currentFont]
            if let ps = textView.typingAttributes[.paragraphStyle] {
                cleanAttrs[.paragraphStyle] = ps
            }
            if let fg = textView.typingAttributes[.foregroundColor] {
                cleanAttrs[.foregroundColor] = fg
            }
            textView.typingAttributes = cleanAttrs
            let newCursor = NSRange(location: removeRange.location, length: 0)
            textView.selectedRange = newCursor
            scheduleScrollCursorToVisible(in: textView)
            parent.attributedText = textView.attributedText
            parent.toolbarViewModel.selectedRange = newCursor
            parent.toolbarViewModel.syncFormattingState()
            return false
        }

        // 내용 있는 목록 줄: 다음 항목 접두사를 자동으로 이어받습니다.
        let nextPrefix = nextListPrefix(for: listKind, currentPrefix: prefix)
        let currentFont = textView.typingAttributes[.font] as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)
        let listStyleID = listStyleID(for: listKind)

        // 인라인 서식(.link, .underlineStyle, .strikethroughStyle, .backgroundColor)이
        // 다음 목록 항목으로 번지는 것을 방지하기 위해 허용 목록 방식으로 구성합니다.
        var newLineAttrs: [NSAttributedString.Key: Any] = [.font: currentFont]
        if let paragraphStyle = textView.typingAttributes[.paragraphStyle] {
            newLineAttrs[.paragraphStyle] = paragraphStyle
        }
        if let fgColor = textView.typingAttributes[.foregroundColor] {
            newLineAttrs[.foregroundColor] = fgColor
        }

        let newLineString = "\n" + nextPrefix
        let newLineAttributed = NSMutableAttributedString(string: newLineString, attributes: newLineAttrs)

        storage.beginEditing()
        storage.replaceCharacters(in: range, with: newLineAttributed)
        let insertedEnd = range.location + (newLineString as NSString).length
        let newParagraphLocation = min(insertedEnd, max(0, storage.length - 1))
        let newParagraphRange = (storage.string as NSString)
            .paragraphRange(for: NSRange(location: newParagraphLocation, length: 0))
        storage.addAttribute(.editorListStyle, value: listStyleID, range: newParagraphRange)
        storage.endEditing()

        // 번호 목록인 경우 이후 항목 번호 재정렬
        if listKind == .number {
            let nextItemNumber: Int
            if let digits = nextPrefix.split(separator: ".").first.flatMap({ Int($0) }) {
                nextItemNumber = digits + 1
            } else {
                nextItemNumber = 2
            }
            renumberFollowingNumberedList(from: insertedEnd, expectedNext: nextItemNumber, in: storage, font: currentFont)
        }

        let newCursor = range.location + (newLineString as NSString).length
        textView.selectedRange = NSRange(location: newCursor, length: 0)
        scheduleScrollCursorToVisible(in: textView)
        textView.typingAttributes = newLineAttrs

        parent.attributedText = textView.attributedText
        parent.toolbarViewModel.selectedRange = NSRange(location: newCursor, length: 0)
        parent.toolbarViewModel.syncFormattingState()
        return false
    }

    // MARK: - Numbered List Renumber

    /// 번호 목록 항목을 삽입한 이후 뒤따르는 번호 목록 단락을 재번호합니다.
    /// 단일 beginEditing/endEditing 블록으로 delegate 알림을 1회만 발생시킵니다.
    func renumberFollowingNumberedList(from insertedEnd: Int, expectedNext: Int, in storage: NSTextStorage, font: UIFont) {
        var currentNumber = expectedNext
        var location = insertedEnd

        var nsString = storage.string as NSString
        let newParagraph = nsString.paragraphRange(for: NSRange(location: min(location, max(0, storage.length - 1)), length: 0))
        location = NSMaxRange(newParagraph)

        storage.beginEditing()
        while location < storage.length {
            nsString = storage.string as NSString  // replaceCharacters 이후 항상 갱신
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: location, length: 0))
            let paragraphText = nsString.substring(with: paragraphRange)

            guard let match = RichTextCoordinator.numberListPrefixRegex.firstMatch(
                in: paragraphText,
                range: NSRange(location: 0, length: (paragraphText as NSString).length)
            ) else { break }

            let oldPrefix = (paragraphText as NSString).substring(with: match.range)
            let newPrefix = "\(currentNumber). "
            let lengthDelta = (newPrefix as NSString).length - match.range.length

            if oldPrefix != newPrefix {
                let replaceRange = NSRange(location: paragraphRange.location, length: match.range.length)
                storage.replaceCharacters(in: replaceRange, with: NSAttributedString(string: newPrefix, attributes: [.font: font]))
                let next = NSMaxRange(paragraphRange) + lengthDelta
                guard next > location else { break }
                location = next
            } else {
                let next = NSMaxRange(paragraphRange)
                guard next > location else { break }
                location = next
            }

            currentNumber += 1
        }
        storage.endEditing()
    }

    // MARK: - List Prefix Detection

    func detectListPrefix(in paragraphText: String) -> (prefix: String, kind: EditorListStyle)? {
        if paragraphText.hasPrefix("• ") { return ("• ", .bullet) }
        if paragraphText.hasPrefix("– ") { return ("– ", .dash) }

        let nsText = paragraphText as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        guard let match = RichTextCoordinator.numberListPrefixRegex.firstMatch(in: paragraphText, range: fullRange) else {
            return nil
        }

        let prefix = nsText.substring(with: match.range)
        return (prefix, .number)
    }

    static let numberListPrefixRegex = try! NSRegularExpression(pattern: "^(\\d+)\\.\\s+")

    func nextListPrefix(for kind: EditorListStyle, currentPrefix: String) -> String {
        switch kind {
        case .bullet: return "• "
        case .dash: return "– "
        case .number:
            let digits = currentPrefix.prefix(while: { $0.isNumber })
            let currentNumber = Int(digits) ?? 1
            return "\(currentNumber + 1). "
        }
    }

    func listStyleID(for style: EditorListStyle) -> String {
        switch style {
        case .bullet: return "bullet"
        case .dash: return "dash"
        case .number: return "number"
        }
    }
}
