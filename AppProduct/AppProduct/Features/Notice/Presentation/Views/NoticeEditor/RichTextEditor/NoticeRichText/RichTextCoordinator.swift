//
//  RichTextCoordinator.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import UIKit

final class RichTextCoordinator: NSObject, UITextViewDelegate {

    // MARK: - Property

    var parent: RichTextViewRepresentable
    var isEditing = false
    var pendingScrollWork: DispatchWorkItem?
    /// 내부 커서 보정 중 selection delegate 재진입을 방지합니다.
    var isSuppressingSelectionSync = false

    // MARK: - Initializer

    init(parent: RichTextViewRepresentable) {
        self.parent = parent
    }

    // MARK: - UITextViewDelegate

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if let bqTextView = textView as? BlockquoteTextView {
            // 인용구가 아닌 단락에 인용구 들여쓰기가 남아있으면
            // UIKit이 문자를 삽입하기 전에 미리 정리하여 들여쓰기 상속을 방지합니다.
            cleanupOrphanedBlockquoteIndent(in: bqTextView, at: range.location)

            // 한글 등 IME 조합 중(markedTextRange != nil)에는 Enter 커스텀 처리를 건너뜁니다.
            if text == "\n", textView.markedTextRange == nil {
                if !handleReturnInBlockquote(textView: bqTextView, range: range) { return false }
                return handleReturnInList(textView: bqTextView, range: range)
            }
        }
        return true
    }

    func textViewDidChange(_ textView: UITextView) {
        parent.toolbarViewModel.clearPendingItalic()

        if textView.markedTextRange == nil {
            stripZeroWidthSpacesIfNeeded(in: textView)
        }

        cleanupBlockquoteTypingAttributesIfNeeded(in: textView)

        // IME 조합 중(markedTextRange != nil)에는 바인딩 갱신을 보류합니다.
        // SwiftUI .onChange가 발화되면 MarkdownSerializer.serialize가 실행되어
        // 조합 입력이 깨지거나 커서가 튀는 원인이 됩니다.
        if textView.markedTextRange == nil {
            parent.attributedText = textView.attributedText
        }
        if parent.toolbarViewModel.textStorage !== textView.textStorage {
            parent.toolbarViewModel.textStorage = textView.textStorage
        }
        updatePlaceholder(in: textView)

        if let bqTextView = textView as? BlockquoteTextView {
            bqTextView.setNeedsBlockquoteRefresh()
        }

        scheduleScrollCursorToVisible(in: textView)
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        guard !isSuppressingSelectionSync else { return }
        // IME 조합 중에는 툴바 깜빡임과 렌더링 지연이 발생합니다.
        guard textView.markedTextRange == nil else { return }

        // UIKit은 커서 이동 시 커스텀 NSAttributedString.Key를 버립니다.
        // storage의 단락 시작 위치에서 인용구 속성을 읽어 재주입합니다.
        reinjectBlockquoteTypingAttributesIfNeeded(in: textView)

        // textViewDidChange에서 보류했던 바인딩을 반영합니다.
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
        if !parent.attributedText.isEqual(textView.attributedText) {
            parent.attributedText = textView.attributedText
        }
        parent.toolbarViewModel.setEditorActive(false)
        parent.toolbarViewModel.dismissFormatPanel()
        updatePlaceholder(in: textView)
    }

    // MARK: - Function

    func clampedSelectedRange(for selectedRange: NSRange, in attributedText: NSAttributedString) -> NSRange {
        let safeLocation = min(max(selectedRange.location, 0), attributedText.length)
        let safeLength = min(max(selectedRange.length, 0), attributedText.length - safeLocation)
        return NSRange(location: safeLocation, length: safeLength)
    }

    // MARK: - Constants

    enum Constants {
        static let cursorScrollPadding: CGFloat = 40
        static let placeholderTag = 92_601
    }
}
