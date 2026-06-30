//
//  RichTextCoordinator.swift
//  NoticeData
//
//  Created by 이예지 on 6/30/26.
//

import UIKit

public final class RichTextCoordinator: NSObject, UITextViewDelegate {

    // MARK: - Property

    public var parent: RichTextViewRepresentable
    public var isEditing = false
    public var pendingScrollWork: DispatchWorkItem?
    /// 내부 커서 보정 중 selection delegate 재진입을 방지합니다.
    public var isSuppressingSelectionSync = false

    // MARK: - Initializer

    public init(parent: RichTextViewRepresentable) {
        self.parent = parent
    }

    // MARK: - UITextViewDelegate

    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // 한글 등 IME 조합 중에는 Enter 커스텀 처리를 건너뜁니다.
        // markedTextRange != nil이면 조합이 진행 중이므로 UIKit 기본 동작을 유지합니다.
        if let bqTextView = textView as? BlockquoteTextView {
            // 인용구가 아닌 단락에 인용구 들여쓰기가 남아있으면
            // UIKit이 문자를 삽입하기 전에 미리 정리하여 들여쓰기 상속을 방지합니다.
            cleanupOrphanedBlockquoteIndent(in: bqTextView, at: range.location)

            if text == "\n", textView.markedTextRange == nil {
                // blockquote Enter 처리를 먼저 시도합니다. 처리됐으면 list 처리는 건너뜁니다.
                if !handleReturnInBlockquote(textView: bqTextView, range: range) { return false }
                // 목록 Enter 처리를 시도합니다.
                return handleReturnInList(textView: bqTextView, range: range)
            }
        }

        // 붙여넣기 등 다중 문자 삽입이 마크다운 문법을 포함하면 서식으로 변환해 직접 삽입합니다.
        if text.count > 1, textView.markedTextRange == nil,
           MarkdownAutoformat.containsMarkdownSyntax(text) {
            insertParsedMarkdown(text, in: textView, range: range)
            return false
        }

        return true
    }

    public func textViewDidChange(_ textView: UITextView) {
        // italic 토글 후 첫 타이핑: _pendingItalicEnabled 플래그를 초기화합니다.
        // 이후부터는 storage 속성과 .editorItalic 커스텀 키로 상태를 추적합니다.
        parent.toolbarViewModel.clearPendingItalic()

        // 빈 인용구 활성화 시 삽입한 ZWS 플레이스홀더를 실제 콘텐츠 입력 후 정리합니다.
        // IME 조합 중에는 건드리지 않습니다.
        if textView.markedTextRange == nil {
            stripZeroWidthSpacesIfNeeded(in: textView)
        }

        // 백스페이스 등으로 텍스트가 모두 삭제되어 인용구가 해제된 경우
        // typingAttributes에 남아 있는 인용구 들여쓰기를 리셋합니다.
        cleanupBlockquoteTypingAttributesIfNeeded(in: textView)

        // 타이핑으로 완성된 마크다운 토큰(`**굿**`, `- ` 등)을 서식으로 변환합니다.
        // 아래 바인딩 동기화보다 먼저 수행해 변환 결과가 함께 반영되도록 합니다.
        if textView.markedTextRange == nil {
            applyTypedMarkdownAutoformatIfNeeded(in: textView)
        }

        // IME 조합 중(markedTextRange != nil)에는 바인딩 갱신을 보류합니다.
        // SwiftUI .onChange가 발화되면 상위에서 MarkdownSerializer.serialize가
        // 실행되어 조합 입력이 깨지거나 커서가 튀는 원인이 됩니다.
        if textView.markedTextRange == nil {
            parent.attributedText = textView.attributedText
        }
        if parent.toolbarViewModel.textStorage !== textView.textStorage {
            parent.toolbarViewModel.textStorage = textView.textStorage
        }
        updatePlaceholder(in: textView)

        // 인용구 경계선: 일반 입력으로 줄바꿈/삭제 시에도 갱신
        if let bqTextView = textView as? BlockquoteTextView {
            bqTextView.setNeedsBlockquoteRefresh()
        }

        // 일반 타이핑/붙여넣기 시에도 커서가 키보드 뒤에 숨지 않도록 합니다.
        scheduleScrollCursorToVisible(in: textView)
    }

    public func textViewDidChangeSelection(_ textView: UITextView) {
        // 내부 커서 보정 중에는 동기화를 건너뜁니다.
        guard !isSuppressingSelectionSync else { return }
        // IME 조합 중(한글 등)에는 선택 범위가 빈번하게 변경됩니다.
        // 조합 중 서식 동기화를 수행하면 툴바 깜빡임과 렌더링 지연이 발생합니다.
        guard textView.markedTextRange == nil else { return }

        // UIKit은 커서 이동 시 typingAttributes를 재계산하면서
        // 커스텀 NSAttributedString.Key를 버립니다.
        // storage의 단락 시작 위치에서 인용구 속성을 읽어 재주입합니다.
        reinjectBlockquoteTypingAttributesIfNeeded(in: textView)

        // IME 조합이 끝난 시점: textViewDidChange에서 보류했던 바인딩을 반영합니다.
        if !parent.attributedText.isEqual(textView.attributedText) {
            parent.attributedText = textView.attributedText
        }

        parent.toolbarViewModel.selectedRange = textView.selectedRange
        parent.toolbarViewModel.toolbarMode = textView.selectedRange.length > 0 ? .textSelected : .default
        parent.toolbarViewModel.reapplyActiveHighlightIfNeeded()
        parent.toolbarViewModel.syncFormattingState()
    }

    public func textViewDidBeginEditing(_ textView: UITextView) {
        isEditing = true
        parent.toolbarViewModel.setEditorActive(true)
        updatePlaceholder(in: textView)
    }

    public func textViewDidEndEditing(_ textView: UITextView) {
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

    public func clampedSelectedRange(for selectedRange: NSRange, in attributedText: NSAttributedString) -> NSRange {
        let safeLocation = min(max(selectedRange.location, 0), attributedText.length)
        let safeLength = min(max(selectedRange.length, 0), attributedText.length - safeLocation)
        return NSRange(location: safeLocation, length: safeLength)
    }

    // MARK: - Constants

    public enum Constants {
        static let cursorScrollPadding: CGFloat = 40
        static let placeholderTag = 92_601
    }
}
