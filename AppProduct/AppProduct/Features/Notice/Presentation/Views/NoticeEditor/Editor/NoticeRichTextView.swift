//
//  NoticeRichTextView.swift
//  AppProduct
//
//  Created by euijjang97 on 4/8/26.
//

import SwiftUI
import UIKit

struct NoticeRichTextView: View {

    // MARK: - Property

    @Bindable var toolbarViewModel: EditorToolbarViewModel
    @Binding var attributedText: NSAttributedString
    var placeholder: String

    // MARK: - Body

    var body: some View {
        _RichTextViewRepresentable(
            toolbarViewModel: toolbarViewModel,
            attributedText: $attributedText,
            placeholder: placeholder
        )
    }
}

// MARK: - UIViewRepresenAItable

private struct _RichTextViewRepresentable: UIViewRepresentable {

    // MARK: - Property

    @Bindable var toolbarViewModel: EditorToolbarViewModel
    @Binding var attributedText: NSAttributedString
    var placeholder: String

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> BlockquoteTextView {
        let textView = BlockquoteTextView()

        textView.delegate = context.coordinator
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.font = UIFont(name: "Pretendard-Regular", size: 16) ?? UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.attributedText = attributedText

        context.coordinator.installPlaceholderIfNeeded(in: textView)
        context.coordinator.updatePlaceholder(in: textView)

        toolbarViewModel.textStorage = textView.textStorage
        toolbarViewModel.textView = textView

        let coordinator = context.coordinator
        toolbarViewModel.onFormattingApplied = { [weak textView, weak coordinator] in
            guard let textView, let coordinator else { return }
            coordinator.parent.attributedText = textView.attributedText
            coordinator.updatePlaceholder(in: textView)
            textView.refreshBlockquoteBorders()
        }

        return textView
    }

    func updateUIView(_ uiView: BlockquoteTextView, context: Context) {
        context.coordinator.parent = self

        if !uiView.attributedText.isEqual(attributedText) {
            let selectedRange = context.coordinator.clampedSelectedRange(for: uiView.selectedRange, in: attributedText)
            uiView.attributedText = attributedText
            uiView.selectedRange = selectedRange
            uiView.refreshBlockquoteBorders()
        }

        uiView.font = UIFont.preferredFont(forTextStyle: .body)
        toolbarViewModel.textStorage = uiView.textStorage
        toolbarViewModel.textView = uiView

        let coordinator = context.coordinator
        toolbarViewModel.onFormattingApplied = { [weak uiView, weak coordinator] in
            guard let uiView, let coordinator else { return }
            coordinator.parent.attributedText = uiView.attributedText
            coordinator.updatePlaceholder(in: uiView)
            uiView.refreshBlockquoteBorders()
        }

        coordinator.installPlaceholderIfNeeded(in: uiView)
        coordinator.updatePlaceholder(in: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: BlockquoteTextView, context: Context) -> CGSize? {
        guard let width = proposal.width else {
            return nil
        }

        let targetSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        let fittedSize = uiView.sizeThatFits(targetSize)
        return CGSize(width: width, height: max(fittedSize.height, uiView.minimumHeight))
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {

        // MARK: - Property

        var parent: _RichTextViewRepresentable
        private var isEditing = false

        // MARK: - Initializer

        init(parent: _RichTextViewRepresentable) {
            self.parent = parent
        }

        // MARK: - UITextViewDelegate

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard text == "\n", let bqTextView = textView as? BlockquoteTextView else { return true }
            // blockquote Enter 처리를 먼저 시도합니다. 처리됐으면 list 처리는 건너뜁니다.
            if !handleReturnInBlockquote(textView: bqTextView, range: range) { return false }
            // 목록 Enter 처리를 시도합니다.
            return handleReturnInList(textView: bqTextView, range: range)
        }

        /// 인용구 단락에서 Enter 키 입력을 처리합니다.
        /// - 빈 인용구 줄: 인용구 속성 제거(탈출)하고 false 반환
        /// - 내용 있는 인용구 줄: 같은 인용구 속성으로 새 줄 삽입하고 false 반환
        private func handleReturnInBlockquote(textView: BlockquoteTextView, range: NSRange) -> Bool {
            let storage = textView.textStorage
            guard storage.length > 0 else { return true }

            let safeLocation = min(range.location, max(0, storage.length - 1))
            let nsString = storage.string as NSString
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: safeLocation, length: 0))
            let checkLocation = min(paragraphRange.location, storage.length - 1)

            guard (storage.attribute(.editorBlockquote, at: checkLocation, effectiveRange: nil) as? Bool) == true else {
                return true
            }

            let paragraphText = nsString.substring(with: paragraphRange)
            let hasContent = paragraphText.contains { !$0.isNewline }

            if !hasContent {
                // 빈 인용구 줄 → 인용구 탈출 (새 줄 삽입 없이 속성만 제거)
                let baseHead = (storage.attribute(.editorBlockquoteBaseHeadIndent, at: checkLocation, effectiveRange: nil) as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
                let baseLine = (storage.attribute(.editorBlockquoteBaseFirstLineHeadIndent, at: checkLocation, effectiveRange: nil) as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0

                let normalStyle = NSMutableParagraphStyle()
                normalStyle.headIndent = baseHead
                normalStyle.firstLineHeadIndent = baseLine

                storage.beginEditing()
                storage.addAttribute(.paragraphStyle, value: normalStyle.copy() as! NSParagraphStyle, range: paragraphRange)
                storage.removeAttribute(.editorBlockquote, range: paragraphRange)
                storage.removeAttribute(.editorBlockquoteBorderColor, range: paragraphRange)
                storage.removeAttribute(.editorBlockquoteBaseHeadIndent, range: paragraphRange)
                storage.removeAttribute(.editorBlockquoteBaseFirstLineHeadIndent, range: paragraphRange)
                storage.endEditing()

                textView.typingAttributes.removeValue(forKey: NSAttributedString.Key.editorBlockquote)
                textView.typingAttributes.removeValue(forKey: NSAttributedString.Key.editorBlockquoteBorderColor)
                textView.typingAttributes.removeValue(forKey: NSAttributedString.Key.editorBlockquoteBaseHeadIndent)
                textView.typingAttributes.removeValue(forKey: NSAttributedString.Key.editorBlockquoteBaseFirstLineHeadIndent)
                let mutableNormal = normalStyle.mutableCopy() as! NSMutableParagraphStyle
                textView.typingAttributes[.paragraphStyle] = mutableNormal.copy() as! NSParagraphStyle

                textView.refreshBlockquoteBorders()
                parent.attributedText = textView.attributedText
                parent.toolbarViewModel.syncFormattingState()
                return false
            }

            // 내용 있는 인용구 줄 → 같은 인용구 속성으로 새 줄 이어받기
            let borderColor = storage.attribute(.editorBlockquoteBorderColor, at: checkLocation, effectiveRange: nil) as? UIColor ?? UIColor.systemGray3
            let baseHeadNum = storage.attribute(.editorBlockquoteBaseHeadIndent, at: checkLocation, effectiveRange: nil) as? NSNumber
            let baseLineNum = storage.attribute(.editorBlockquoteBaseFirstLineHeadIndent, at: checkLocation, effectiveRange: nil) as? NSNumber
            let existingStyle = storage.attribute(.paragraphStyle, at: checkLocation, effectiveRange: nil) as? NSParagraphStyle ?? NSParagraphStyle.default
            let newStyle = existingStyle.mutableCopy() as! NSMutableParagraphStyle

            let fontLocation = range.location > 0 ? min(range.location - 1, storage.length - 1) : 0
            let currentFont = storage.attribute(.font, at: fontLocation, effectiveRange: nil) as? UIFont
                ?? textView.typingAttributes[.font] as? UIFont
                ?? UIFont.preferredFont(forTextStyle: .body)

            var newAttrs: [NSAttributedString.Key: Any] = [
                .paragraphStyle: newStyle.copy() as! NSParagraphStyle,
                .font: currentFont,
                NSAttributedString.Key.editorBlockquote: true,
                NSAttributedString.Key.editorBlockquoteBorderColor: borderColor,
            ]
            if let b = baseHeadNum { newAttrs[NSAttributedString.Key.editorBlockquoteBaseHeadIndent] = b }
            if let b = baseLineNum { newAttrs[NSAttributedString.Key.editorBlockquoteBaseFirstLineHeadIndent] = b }

            storage.beginEditing()
            storage.replaceCharacters(in: range, with: NSAttributedString(string: "\n", attributes: newAttrs))
            storage.endEditing()

            let newCursor = range.location + 1
            textView.selectedRange = NSRange(location: newCursor, length: 0)

            textView.typingAttributes[.paragraphStyle] = newStyle.copy() as! NSParagraphStyle
            textView.typingAttributes[.font] = currentFont
            textView.typingAttributes[NSAttributedString.Key.editorBlockquote] = true
            textView.typingAttributes[NSAttributedString.Key.editorBlockquoteBorderColor] = borderColor
            if let b = baseHeadNum { textView.typingAttributes[NSAttributedString.Key.editorBlockquoteBaseHeadIndent] = b }
            if let b = baseLineNum { textView.typingAttributes[NSAttributedString.Key.editorBlockquoteBaseFirstLineHeadIndent] = b }

            textView.refreshBlockquoteBorders()
            parent.attributedText = textView.attributedText
            parent.toolbarViewModel.selectedRange = NSRange(location: newCursor, length: 0)
            parent.toolbarViewModel.syncFormattingState()
            return false
        }

        /// 목록 단락에서 Enter 키 입력을 처리합니다.
        /// - 반환값: true이면 UIKit이 기본 Enter 처리를 수행, false이면 직접 처리 완료
        private func handleReturnInList(textView: BlockquoteTextView, range: NSRange) -> Bool {
            let storage = textView.textStorage
            guard storage.length > 0 else { return true }

            let safeLocation = min(range.location, max(0, storage.length - 1))
            let nsString = storage.string as NSString
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: safeLocation, length: 0))
            let paragraphText = nsString.substring(with: paragraphRange)

            guard let (prefix, listKind) = detectListPrefix(in: paragraphText) else {
                return true
            }

            // 접두사 이후 실제 콘텐츠 존재 여부 확인
            let contentAfterPrefix = String(paragraphText.dropFirst(prefix.count))
            let hasContent = contentAfterPrefix.contains { !$0.isNewline && !$0.isWhitespace }

            if !hasContent {
                // 빈 목록 줄 → 접두사만 제거하고 목록 탈출
                let prefixNSLength = (prefix as NSString).length
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

                textView.typingAttributes[.font] = currentFont
                let newCursor = NSRange(location: removeRange.location, length: 0)
                textView.selectedRange = newCursor
                parent.attributedText = textView.attributedText
                parent.toolbarViewModel.selectedRange = newCursor
                parent.toolbarViewModel.syncFormattingState()
                return false
            }

            // 내용 있는 목록 줄 → 다음 항목 접두사를 자동으로 이어받습니다
            let nextPrefix = nextListPrefix(for: listKind, currentPrefix: prefix)
            let fontLocation = range.location > 0 ? min(range.location - 1, storage.length - 1) : 0
            let currentFont = storage.attribute(.font, at: fontLocation, effectiveRange: nil) as? UIFont
                ?? textView.typingAttributes[.font] as? UIFont
                ?? UIFont.preferredFont(forTextStyle: .body)
            let listStyleID = listStyleID(for: listKind)

            let newLineString = "\n" + nextPrefix
            let newLineAttributed = NSMutableAttributedString(string: newLineString)
            newLineAttributed.addAttribute(
                .font, value: currentFont,
                range: NSRange(location: 0, length: (newLineString as NSString).length)
            )

            storage.beginEditing()
            storage.replaceCharacters(in: range, with: newLineAttributed)
            let insertedEnd = range.location + (newLineString as NSString).length
            let newParagraphLocation = min(insertedEnd, max(0, storage.length - 1))
            let newParagraphRange = (storage.string as NSString)
                .paragraphRange(for: NSRange(location: newParagraphLocation, length: 0))
            storage.addAttribute(.editorListStyle, value: listStyleID, range: newParagraphRange)
            storage.endEditing()

            let newCursor = range.location + (newLineString as NSString).length
            textView.selectedRange = NSRange(location: newCursor, length: 0)
            textView.typingAttributes[.font] = currentFont

            parent.attributedText = textView.attributedText
            parent.toolbarViewModel.selectedRange = NSRange(location: newCursor, length: 0)
            parent.toolbarViewModel.syncFormattingState()
            return false
        }

        /// 단락 텍스트에서 목록 접두사와 종류를 감지합니다.
        private func detectListPrefix(in paragraphText: String) -> (prefix: String, kind: EditorListStyle)? {
            if paragraphText.hasPrefix("• ") { return ("• ", .bullet) }
            if paragraphText.hasPrefix("– ") { return ("– ", .dash) }

            let nsText = paragraphText as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)
            guard let regex = try? NSRegularExpression(pattern: "^(\\d+)\\.\\s+"),
                  let match = regex.firstMatch(in: paragraphText, range: fullRange) else {
                return nil
            }

            let prefix = nsText.substring(with: match.range)
            return (prefix, .number)
        }

        /// 현재 접두사를 기반으로 다음 목록 항목의 접두사를 계산합니다.
        private func nextListPrefix(for kind: EditorListStyle, currentPrefix: String) -> String {
            switch kind {
            case .bullet: return "• "
            case .dash: return "– "
            case .number:
                let digits = currentPrefix.prefix(while: { $0.isNumber })
                let currentNumber = Int(digits) ?? 1
                return "\(currentNumber + 1). "
            }
        }

        /// 목록 스타일에 대한 저장 식별자를 반환합니다.
        private func listStyleID(for style: EditorListStyle) -> String {
            switch style {
            case .bullet: return "bullet"
            case .dash: return "dash"
            case .number: return "number"
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.attributedText = textView.attributedText
            parent.toolbarViewModel.textStorage = textView.textStorage
            updatePlaceholder(in: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.toolbarViewModel.selectedRange = textView.selectedRange
            parent.toolbarViewModel.toolbarMode = textView.selectedRange.length > 0 ? .textSelected : .default
            parent.toolbarViewModel.syncFormattingState()
            parent.toolbarViewModel.reapplyActiveHighlightIfNeeded()
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
            parent.toolbarViewModel.setEditorActive(true)
            updatePlaceholder(in: textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
            parent.toolbarViewModel.setEditorActive(false)
            parent.toolbarViewModel.dismissFormatPanel()
            updatePlaceholder(in: textView)
        }

        // MARK: - Function

        func installPlaceholderIfNeeded(in textView: UITextView) {
            guard textView.viewWithTag(Constants.placeholderTag) == nil else {
                if let label = textView.viewWithTag(Constants.placeholderTag) as? UILabel {
                    label.text = parent.placeholder
                    label.font = textView.font
                }
                return
            }

            let placeholderLabel = UILabel()
            placeholderLabel.tag = Constants.placeholderTag
            placeholderLabel.text = parent.placeholder
            placeholderLabel.font = textView.font
            placeholderLabel.textColor = .placeholderText
            placeholderLabel.numberOfLines = 0
            placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
            placeholderLabel.isUserInteractionEnabled = false

            textView.addSubview(placeholderLabel)

            NSLayoutConstraint.activate([
                placeholderLabel.topAnchor.constraint(
                    equalTo: textView.topAnchor,
                    constant: textView.textContainerInset.top
                ),
                placeholderLabel.leadingAnchor.constraint(
                    equalTo: textView.leadingAnchor,
                    constant: textView.textContainerInset.left + textView.textContainer.lineFragmentPadding
                ),
                placeholderLabel.trailingAnchor.constraint(
                    lessThanOrEqualTo: textView.trailingAnchor,
                    constant: -(textView.textContainerInset.right + textView.textContainer.lineFragmentPadding)
                )
            ])
        }

        func updatePlaceholder(in textView: UITextView) {
            guard let placeholderLabel = textView.viewWithTag(Constants.placeholderTag) as? UILabel else {
                return
            }

            placeholderLabel.text = parent.placeholder
            placeholderLabel.font = textView.font
            placeholderLabel.isHidden = isEditing || textView.attributedText.length > 0
        }

        func clampedSelectedRange(for selectedRange: NSRange, in attributedText: NSAttributedString) -> NSRange {
            let safeLocation = min(max(selectedRange.location, 0), attributedText.length)
            let safeLength = min(max(selectedRange.length, 0), attributedText.length - safeLocation)
            return NSRange(location: safeLocation, length: safeLength)
        }

        private enum Constants {
            static let placeholderTag = 92_601
        }
    }
}

private extension UITextView {

    var minimumHeight: CGFloat {
        let lineHeight = font?.lineHeight ?? UIFont.preferredFont(forTextStyle: .body).lineHeight
        return ceil(lineHeight + textContainerInset.top + textContainerInset.bottom)
    }
}
