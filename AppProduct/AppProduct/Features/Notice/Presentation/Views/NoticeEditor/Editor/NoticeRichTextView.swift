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

// MARK: - UIViewRepresentable

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
        // Pretendard는 Dynamic Type 스케일 미지원 커스텀 폰트이므로 false로 설정합니다.
        // true이면 접근성 글자 크기 변경 시 UIKit이 시스템 폰트로 폴백할 수 있습니다.
        textView.adjustsFontForContentSizeCategory = false
        textView.accessibilityLabel = "내용"
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
            textView.setNeedsBlockquoteRefresh()
        }

        return textView
    }

    func updateUIView(_ uiView: BlockquoteTextView, context: Context) {
        context.coordinator.parent = self

        if !uiView.attributedText.isEqual(attributedText) {
            // IME 조합 중(한글 등) attributedText 강제 재주입은 조합 문자를 깨뜨립니다.
            // 텍스트 재주입만 건너뛰고, 아래 툴바/placeholder 갱신은 계속 실행합니다.
            if uiView.markedTextRange == nil {
                let selectedRange = context.coordinator.clampedSelectedRange(for: uiView.selectedRange, in: attributedText)
                uiView.attributedText = attributedText
                uiView.selectedRange = selectedRange
                uiView.setNeedsBlockquoteRefresh()
            }
        }

        // 동일 참조인 경우 재할당 생략: @Observable 불필요 변경 알림을 방지합니다.
        if toolbarViewModel.textStorage !== uiView.textStorage {
            toolbarViewModel.textStorage = uiView.textStorage
        }
        if toolbarViewModel.textView !== uiView {
            toolbarViewModel.textView = uiView
            let coordinator = context.coordinator
            toolbarViewModel.onFormattingApplied = { [weak uiView, weak coordinator] in
                guard let uiView, let coordinator else { return }
                coordinator.parent.attributedText = uiView.attributedText
                coordinator.updatePlaceholder(in: uiView)
                uiView.setNeedsBlockquoteRefresh()
            }
        }

        let coordinator = context.coordinator
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

        // textContainer 폭을 제안 폭에 맞춘 뒤 레이아웃을 확정합니다.
        // 이전 프레임 폭이 남아있으면 줄바꿈 기준이 틀려 높이가 점프합니다.
        let inset = uiView.textContainerInset
        let padding = uiView.textContainer.lineFragmentPadding
        let containerWidth = max(0, width - inset.left - inset.right - padding * 2)
        if abs(uiView.textContainer.size.width - containerWidth) > 0.5 {
            uiView.textContainer.size = CGSize(width: containerWidth, height: .greatestFiniteMagnitude)
        }
        uiView.layoutManager.ensureLayout(for: uiView.textContainer)
        let usedRect = uiView.layoutManager.usedRect(for: uiView.textContainer)
        let height = ceil(usedRect.height + inset.top + inset.bottom)
        return CGSize(width: width, height: max(height, uiView.minimumHeight))
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {

        // MARK: - Property

        var parent: _RichTextViewRepresentable
        private var isEditing = false
        private var pendingScrollWork: DispatchWorkItem?

        // MARK: - Initializer

        init(parent: _RichTextViewRepresentable) {
            self.parent = parent
        }

        // MARK: - UITextViewDelegate

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // 한글 등 IME 조합 중에는 Enter 커스텀 처리를 건너뜁니다.
            // markedTextRange != nil이면 조합이 진행 중이므로 UIKit 기본 동작을 유지합니다.
            guard text == "\n",
                  textView.markedTextRange == nil,
                  let bqTextView = textView as? BlockquoteTextView
            else { return true }
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

            // paragraphRange 계산은 EOF 위치(storage.length)를 허용합니다.
            // storage.length - 1 로 clamp하면 trailing \n이 있는 경우 이전 단락을 오인합니다.
            let paragraphLocation = min(range.location, storage.length)
            let nsString = storage.string as NSString
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: paragraphLocation, length: 0))

            // EOF 빈 단락(location >= storage.length)은 typingAttributes로 blockquote 상태를 확인합니다.
            let isInBlockquote: Bool
            if paragraphRange.location >= storage.length {
                isInBlockquote = (textView.typingAttributes[NSAttributedString.Key.editorBlockquote] as? Bool) == true
            } else {
                isInBlockquote = (storage.attribute(.editorBlockquote, at: paragraphRange.location, effectiveRange: nil) as? Bool) == true
            }
            guard isInBlockquote else { return true }

            // attribute 읽기용 위치: EOF 빈 단락이면 trailing \n(storage.length - 1)에서 blockquote 속성을 읽습니다.
            let checkLocation = min(paragraphRange.location, max(0, storage.length - 1))
            let paragraphText = nsString.substring(with: paragraphRange)
            let hasContent = paragraphText.contains { !$0.isNewline && !$0.isWhitespace }

            if !hasContent {
                // 빈 인용구 줄 → 인용구 탈출 (새 줄 삽입 없이 속성만 제거)
                let baseHead = (storage.attribute(.editorBlockquoteBaseHeadIndent, at: checkLocation, effectiveRange: nil) as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
                let baseLine = (storage.attribute(.editorBlockquoteBaseFirstLineHeadIndent, at: checkLocation, effectiveRange: nil) as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0

                let normalStyle = NSMutableParagraphStyle()
                normalStyle.headIndent = baseHead
                normalStyle.firstLineHeadIndent = baseLine

                storage.beginEditing()
                storage.addAttribute(.paragraphStyle, value: (normalStyle.copy() as? NSParagraphStyle) ?? normalStyle, range: paragraphRange)
                storage.removeAttribute(.editorBlockquote, range: paragraphRange)
                storage.removeAttribute(.editorBlockquoteBorderColor, range: paragraphRange)
                storage.removeAttribute(.editorBlockquoteBaseHeadIndent, range: paragraphRange)
                storage.removeAttribute(.editorBlockquoteBaseFirstLineHeadIndent, range: paragraphRange)
                storage.endEditing()

                textView.typingAttributes.removeValue(forKey: NSAttributedString.Key.editorBlockquote)
                textView.typingAttributes.removeValue(forKey: NSAttributedString.Key.editorBlockquoteBorderColor)
                textView.typingAttributes.removeValue(forKey: NSAttributedString.Key.editorBlockquoteBaseHeadIndent)
                textView.typingAttributes.removeValue(forKey: NSAttributedString.Key.editorBlockquoteBaseFirstLineHeadIndent)
                let mutableNormal = (normalStyle.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
                textView.typingAttributes[.paragraphStyle] = (mutableNormal.copy() as? NSParagraphStyle) ?? mutableNormal

                textView.setNeedsBlockquoteRefresh()
                parent.attributedText = textView.attributedText
                parent.toolbarViewModel.selectedRange = textView.selectedRange
                parent.toolbarViewModel.syncFormattingState()
                return false
            }

            // 내용 있는 인용구 줄 → 같은 인용구 속성으로 새 줄 이어받기
            let borderColor = storage.attribute(.editorBlockquoteBorderColor, at: checkLocation, effectiveRange: nil) as? UIColor ?? UIColor.systemGray3
            let baseHeadNum = storage.attribute(.editorBlockquoteBaseHeadIndent, at: checkLocation, effectiveRange: nil) as? NSNumber
            let baseLineNum = storage.attribute(.editorBlockquoteBaseFirstLineHeadIndent, at: checkLocation, effectiveRange: nil) as? NSNumber
            let existingStyle = storage.attribute(.paragraphStyle, at: checkLocation, effectiveRange: nil) as? NSParagraphStyle ?? NSParagraphStyle.default
            let newStyle = (existingStyle.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()

            let fontLocation = range.location > 0 ? min(range.location - 1, storage.length - 1) : 0
            let currentFont = storage.attribute(.font, at: fontLocation, effectiveRange: nil) as? UIFont
                ?? textView.typingAttributes[.font] as? UIFont
                ?? UIFont.preferredFont(forTextStyle: .body)

            var newAttrs: [NSAttributedString.Key: Any] = [
                .paragraphStyle: (newStyle.copy() as? NSParagraphStyle) ?? newStyle,
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
            scheduleScrollCursorToVisible(in: textView)

            // 인라인 서식이 다음 인용구 줄로 번지지 않도록 typingAttributes를 재구성합니다.
            textView.typingAttributes = newAttrs

            textView.setNeedsBlockquoteRefresh()
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

            // paragraphRange 계산은 EOF 위치(storage.length)를 허용합니다.
            // storage.length - 1 로 clamp하면 trailing \n이 있는 경우 이전 단락을 오인합니다.
            let paragraphLocation = min(range.location, storage.length)
            let nsString = storage.string as NSString
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: paragraphLocation, length: 0))
            // EOF 빈 단락(location >= storage.length): paragraphText가 빈 문자열이어서 detectListPrefix가 nil을 반환합니다.
            let paragraphText = paragraphRange.location < storage.length
                ? nsString.substring(with: paragraphRange)
                : ""

            guard let (prefix, listKind) = detectListPrefix(in: paragraphText) else {
                return true
            }

            // 접두사 이후 실제 콘텐츠 존재 여부 확인 (NSString 기반으로 통일)
            let prefixNSLength = (prefix as NSString).length
            let paragraphNSStr = paragraphText as NSString
            let contentAfterPrefix = paragraphNSStr.length > prefixNSLength
                ? paragraphNSStr.substring(from: prefixNSLength)
                : ""
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

            // 내용 있는 목록 줄 → 다음 항목 접두사를 자동으로 이어받습니다
            let nextPrefix = nextListPrefix(for: listKind, currentPrefix: prefix)
            let currentFont = textView.typingAttributes[.font] as? UIFont
                ?? UIFont.preferredFont(forTextStyle: .body)
            let listStyleID = listStyleID(for: listKind)

            // 새 줄 속성은 허용 목록 방식으로 구성합니다.
            // 인라인 서식(.link, .underlineStyle, .strikethroughStyle, .backgroundColor)이
            // 다음 목록 항목으로 번지는 것을 방지합니다.
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
            // 인라인 서식이 다음 목록 항목으로 번지지 않도록 typingAttributes를 재구성합니다.
            textView.typingAttributes = newLineAttrs

            parent.attributedText = textView.attributedText
            parent.toolbarViewModel.selectedRange = NSRange(location: newCursor, length: 0)
            parent.toolbarViewModel.syncFormattingState()
            return false
        }

        /// 번호 목록 항목을 삽입한 이후 뒤따르는 번호 목록 단락을 재번호합니다.
        ///
        /// 전체 재번호 작업을 단일 beginEditing/endEditing 블록으로 감싸
        /// delegate 알림을 1회만 발생시켜 SwiftUI 다중 재렌더를 방지합니다.
        private func renumberFollowingNumberedList(from insertedEnd: Int, expectedNext: Int, in storage: NSTextStorage, font: UIFont) {
            var currentNumber = expectedNext
            var location = insertedEnd

            // 삽입된 새 줄(다음 항목)의 다음 단락부터 순회 시작
            var nsString = storage.string as NSString
            let newParagraph = nsString.paragraphRange(for: NSRange(location: min(location, max(0, storage.length - 1)), length: 0))
            location = NSMaxRange(newParagraph)

            // 단일 editing 트랜잭션: N개 항목을 재번호해도 delegate 알림 1회만 발생
            storage.beginEditing()
            while location < storage.length {
                nsString = storage.string as NSString  // replaceCharacters 이후 항상 갱신
                let paragraphRange = nsString.paragraphRange(for: NSRange(location: location, length: 0))
                let paragraphText = nsString.substring(with: paragraphRange)

                guard let match = Coordinator.numberListPrefixRegex.firstMatch(
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

        /// 단락 텍스트에서 목록 접두사와 종류를 감지합니다.
        private func detectListPrefix(in paragraphText: String) -> (prefix: String, kind: EditorListStyle)? {
            if paragraphText.hasPrefix("• ") { return ("• ", .bullet) }
            if paragraphText.hasPrefix("– ") { return ("– ", .dash) }

            let nsText = paragraphText as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)
            guard let match = Coordinator.numberListPrefixRegex.firstMatch(in: paragraphText, range: fullRange) else {
                return nil
            }

            let prefix = nsText.substring(with: match.range)
            return (prefix, .number)
        }

        private static let numberListPrefixRegex = try! NSRegularExpression(pattern: "^(\\d+)\\.\\s+")

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
            // IME 조합 중(markedTextRange != nil)에는 바인딩 갱신을 보류합니다.
            // SwiftUI .onChange가 발화되면 상위에서 MarkdownSerializer.serialize가
            // 실행되어 조합 입력이 깨지거나 커서가 튀는 원인이 됩니다.
            if textView.markedTextRange == nil {
                parent.attributedText = textView.attributedText
            }
            parent.toolbarViewModel.textStorage = textView.textStorage
            updatePlaceholder(in: textView)

            // 인용구 경계선: 일반 입력으로 줄바꿈/삭제 시에도 갱신
            if let bqTextView = textView as? BlockquoteTextView {
                bqTextView.setNeedsBlockquoteRefresh()
            }

            // 일반 타이핑/붙여넣기 시에도 커서가 키보드 뒤에 숨지 않도록 합니다.
            scheduleScrollCursorToVisible(in: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            // IME 조합 중(한글 등)에는 선택 범위가 빈번하게 변경됩니다.
            // 조합 중 서식 동기화를 수행하면 툴바 깜빡임과 렌더링 지연이 발생합니다.
            guard textView.markedTextRange == nil else { return }

            // IME 조합이 끝난 시점: textViewDidChange에서 보류했던 바인딩을 반영합니다.
            if !parent.attributedText.isEqual(textView.attributedText) {
                parent.attributedText = textView.attributedText
            }

            parent.toolbarViewModel.selectedRange = textView.selectedRange
            parent.toolbarViewModel.toolbarMode = textView.selectedRange.length > 0 ? .textSelected : .default
            parent.toolbarViewModel.reapplyActiveHighlightIfNeeded()
            parent.toolbarViewModel.syncFormattingState()
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
            parent.toolbarViewModel.setEditorActive(true)
            updatePlaceholder(in: textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
            // 편집 종료 시 IME 조합 중 보류했던 바인딩을 확실히 반영합니다.
            if !parent.attributedText.isEqual(textView.attributedText) {
                parent.attributedText = textView.attributedText
            }
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
            // VoiceOver에서 placeholder가 별도 요소로 읽히지 않도록 합니다.
            placeholderLabel.isAccessibilityElement = false

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
            // 포커스 여부와 관계없이 내용이 비어있으면 placeholder를 표시합니다.
            // 빈 에디터에 포커스가 들어가도 어떤 필드인지 알 수 있습니다.
            let showPlaceholder = textView.attributedText.length == 0
            placeholderLabel.isHidden = !showPlaceholder
            // VoiceOver: accessibilityHint로 placeholder를 제공합니다.
            textView.accessibilityHint = showPlaceholder ? parent.placeholder : nil
        }

        func clampedSelectedRange(for selectedRange: NSRange, in attributedText: NSAttributedString) -> NSRange {
            let safeLocation = min(max(selectedRange.location, 0), attributedText.length)
            let safeLength = min(max(selectedRange.length, 0), attributedText.length - safeLocation)
            return NSRange(location: safeLocation, length: safeLength)
        }

        /// 다음 run loop에서 커서 스크롤을 1회만 실행하도록 예약합니다.
        /// 빠른 입력/붙여넣기에서 예약이 누적되는 것을 방지합니다.
        func scheduleScrollCursorToVisible(in textView: UITextView) {
            pendingScrollWork?.cancel()
            let work = DispatchWorkItem { [weak self, weak textView] in
                guard let self, let textView else { return }
                self.scrollCursorToVisible(in: textView)
            }
            pendingScrollWork = work
            DispatchQueue.main.async(execute: work)
        }

        /// 프로그래매틱 텍스트 삽입 이후 커서가 화면에 보이도록 가장 가까운 UIScrollView를 스크롤합니다.
        ///
        /// isScrollEnabled = false인 UITextView는 자체 커서 추적을 하지 않으므로
        /// 부모 ScrollView를 직접 찾아 scrollRectToVisible을 호출합니다.
        func scrollCursorToVisible(in textView: UITextView) {
            guard let selectedRange = textView.selectedTextRange else { return }
            let cursorRect = textView.caretRect(for: selectedRange.end)
            guard !cursorRect.isNull, !cursorRect.isInfinite else { return }

            // 뷰 계층에서 첫 번째 수직 스크롤 가능한 UIScrollView를 탐색합니다.
            var ancestor: UIView? = textView.superview
            while let view = ancestor {
                if let scrollView = view as? UIScrollView,
                   scrollView.isScrollEnabled,
                   scrollView.contentSize.height > scrollView.bounds.height {
                    let rectInScrollView = textView.convert(cursorRect, to: scrollView)
                    let topInset = scrollView.adjustedContentInset.top
                    let bottomInset = scrollView.adjustedContentInset.bottom
                    let visibleMinY = scrollView.contentOffset.y + topInset
                    let visibleMaxY = scrollView.contentOffset.y + scrollView.bounds.height - bottomInset

                    // 커서가 이미 visible rect 안에 있으면 스크롤 불필요
                    if rectInScrollView.minY >= visibleMinY && rectInScrollView.maxY <= visibleMaxY {
                        return
                    }

                    var paddedRect = rectInScrollView.insetBy(dx: 0, dy: -Constants.cursorScrollPadding)
                    if paddedRect.maxY > visibleMaxY {
                        paddedRect.size.height += bottomInset
                    }
                    scrollView.scrollRectToVisible(paddedRect, animated: false)
                    return
                }
                ancestor = view.superview
            }
        }

        private enum Constants {
            static let cursorScrollPadding: CGFloat = 40
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
