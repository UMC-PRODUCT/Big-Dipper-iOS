//
//  RichTextCoordinator+Placeholder.swift
//  NoticeData
//
//  Created by 이예지 on 6/30/26.
//

import UIKit

extension RichTextCoordinator {

    // MARK: - Placeholder

    public func installPlaceholderIfNeeded(in textView: UITextView) {
        if let label = textView.viewWithTag(Constants.placeholderTag) as? UILabel {
            label.text = parent.placeholder
            label.font = textView.font
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

    public func updatePlaceholder(in textView: UITextView) {
        guard let placeholderLabel = textView.viewWithTag(Constants.placeholderTag) as? UILabel else {
            return
        }

        let placeholderText = parent.placeholder
        // 포커스 여부와 관계없이 내용이 비어있으면 placeholder를 표시합니다.
        // 빈 에디터에 포커스가 들어가도 어떤 필드인지 알 수 있습니다.
        let showPlaceholder = textView.attributedText.length == 0
        placeholderLabel.isHidden = !showPlaceholder
        // VoiceOver: accessibilityHint로 placeholder를 제공합니다.
        textView.accessibilityHint = showPlaceholder ? placeholderText : nil

        guard showPlaceholder else { return }

        // typingAttributes에서 현재 서식을 읽어 placeholder에 미리보기로 반영합니다.
        let typingAttrs = textView.typingAttributes
        let font = typingAttrs[.font] as? UIFont
            ?? textView.font
            ?? UIFont.preferredFont(forTextStyle: .body)

        var attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.placeholderText,
            .font: font
        ]

        if let underline = typingAttrs[.underlineStyle] as? Int, underline > 0 {
            attrs[.underlineStyle] = underline
        }

        if let strikethrough = typingAttrs[.strikethroughStyle] as? Int, strikethrough > 0 {
            attrs[.strikethroughStyle] = strikethrough
        }

        if let bgColor = typingAttrs[.backgroundColor] as? UIColor {
            attrs[.backgroundColor] = bgColor
        }

        if let paragraphStyle = typingAttrs[.paragraphStyle] as? NSParagraphStyle {
            attrs[.paragraphStyle] = paragraphStyle
        }

        placeholderLabel.attributedText = NSAttributedString(
            string: placeholderText,
            attributes: attrs
        )
    }
}
