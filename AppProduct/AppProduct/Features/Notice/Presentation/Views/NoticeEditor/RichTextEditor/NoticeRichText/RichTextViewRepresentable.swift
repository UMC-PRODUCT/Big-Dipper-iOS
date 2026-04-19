//
//  RichTextViewRepresentable.swift
//  AppProduct
//

import SwiftUI
import UIKit

struct RichTextViewRepresentable: UIViewRepresentable {

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
        // Pretendard는 Dynamic Type 미지원 커스텀 폰트이므로 false로 설정합니다.
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
            if textView.markedTextRange == nil {
                coordinator.parent.attributedText = textView.attributedText
            }
            coordinator.updatePlaceholder(in: textView)
            textView.setNeedsBlockquoteRefresh()
        }

        toolbarViewModel.onPlaceholderNeedsUpdate = { [weak textView, weak coordinator] in
            guard let textView, let coordinator else { return }
            coordinator.updatePlaceholder(in: textView)
        }

        return textView
    }

    func updateUIView(_ uiView: BlockquoteTextView, context: Context) {
        context.coordinator.parent = self

        if !uiView.attributedText.isEqual(attributedText) {
            // IME 조합 중(한글 등) attributedText 강제 재주입은 조합 문자를 깨뜨립니다.
            if uiView.markedTextRange == nil {
                // UITextView.attributedText setter는 typingAttributes를 리셋하므로
                // 커스텀 속성 보존을 위해 재주입 전후로 저장/복원합니다.
                let savedTypingAttributes = uiView.typingAttributes
                let selectedRange = context.coordinator.clampedSelectedRange(for: uiView.selectedRange, in: attributedText)
                uiView.attributedText = attributedText
                uiView.selectedRange = selectedRange
                uiView.typingAttributes = savedTypingAttributes
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
                if uiView.markedTextRange == nil {
                    coordinator.parent.attributedText = uiView.attributedText
                }
                coordinator.updatePlaceholder(in: uiView)
                uiView.setNeedsBlockquoteRefresh()
            }
            toolbarViewModel.onPlaceholderNeedsUpdate = { [weak uiView, weak coordinator] in
                guard let uiView, let coordinator else { return }
                coordinator.updatePlaceholder(in: uiView)
            }
        }

        context.coordinator.installPlaceholderIfNeeded(in: uiView)
        context.coordinator.updatePlaceholder(in: uiView)
    }

    func makeCoordinator() -> RichTextCoordinator {
        RichTextCoordinator(parent: self)
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
}
