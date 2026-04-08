//
//  NoticeRichTextView.swift
//  AppProduct
//
//  Created by OpenAI Codex on 4/8/26.
//

import SwiftUI
import UIKit

struct NoticeRichTextView: View {

    // MARK: - Property

    @Bindable var toolbarViewModel: EditorToolbarViewModel
    @Binding var attributedText: NSAttributedString
    var placeholder: String

    // MARK: - Toolbar Callbacks

    /// 테이블 삽입 버튼 탭 핸들러
    var onInsertTable: () -> Void = {}
    /// 사진 첨부 버튼 탭 핸들러
    var onInsertImage: () -> Void = {}
    /// 링크 삽입 버튼 탭 핸들러
    var onInsertLink: () -> Void = {}
    /// AI 도우미 버튼 탭 핸들러
    var onTapAI: () -> Void = {}
    /// 형광펜 버튼 탭 핸들러
    var onTapHighlight: () -> Void = {}

    // MARK: - Body

    var body: some View {
        _RichTextViewRepresentable(
            toolbarViewModel: toolbarViewModel,
            attributedText: $attributedText,
            placeholder: placeholder,
            onInsertTable: onInsertTable,
            onInsertImage: onInsertImage,
            onInsertLink: onInsertLink,
            onTapAI: onTapAI,
            onTapHighlight: onTapHighlight
        )
    }
}

// MARK: - UIViewRepresentable

private struct _RichTextViewRepresentable: UIViewRepresentable {

    // MARK: - Property

    @Bindable var toolbarViewModel: EditorToolbarViewModel
    @Binding var attributedText: NSAttributedString
    var placeholder: String
    var onInsertTable: () -> Void
    var onInsertImage: () -> Void
    var onInsertLink: () -> Void
    var onTapAI: () -> Void
    var onTapHighlight: () -> Void

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        let accessoryView = EditorAccessoryView(
            toolbarViewModel: toolbarViewModel,
            onInsertTable: onInsertTable,
            onInsertImage: onInsertImage,
            onInsertLink: onInsertLink,
            onTapAI: onTapAI,
            onTapHighlight: onTapHighlight
        )

        textView.delegate = context.coordinator
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.attributedText = attributedText
        textView.inputAccessoryView = accessoryView

        accessoryView.translatesAutoresizingMaskIntoConstraints = false
        accessoryView.heightAnchor.constraint(equalToConstant: EditorAccessoryView.Constants.toolbarHeight).isActive = true

        context.coordinator.accessoryView = accessoryView
        context.coordinator.installPlaceholderIfNeeded(in: textView)
        context.coordinator.updatePlaceholder(in: textView)

        toolbarViewModel.textStorage = textView.textStorage

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self

        if !uiView.attributedText.isEqual(attributedText) {
            let selectedRange = context.coordinator.clampedSelectedRange(for: uiView.selectedRange, in: attributedText)
            uiView.attributedText = attributedText
            uiView.selectedRange = selectedRange
        }

        uiView.font = UIFont.preferredFont(forTextStyle: .body)
        toolbarViewModel.textStorage = uiView.textStorage

        if let accessoryView = uiView.inputAccessoryView as? EditorAccessoryView {
            accessoryView.update(
                toolbarViewModel: toolbarViewModel,
                onInsertTable: onInsertTable,
                onInsertImage: onInsertImage,
                onInsertLink: onInsertLink,
                onTapAI: onTapAI,
                onTapHighlight: onTapHighlight
            )
            context.coordinator.accessoryView = accessoryView
        } else {
            let accessoryView = EditorAccessoryView(
                toolbarViewModel: toolbarViewModel,
                onInsertTable: onInsertTable,
                onInsertImage: onInsertImage,
                onInsertLink: onInsertLink,
                onTapAI: onTapAI,
                onTapHighlight: onTapHighlight
            )
            uiView.inputAccessoryView = accessoryView
            context.coordinator.accessoryView = accessoryView
        }

        context.coordinator.installPlaceholderIfNeeded(in: uiView)
        context.coordinator.updatePlaceholder(in: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
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
        weak var accessoryView: EditorAccessoryView?
        private var isEditing = false

        // MARK: - Initializer

        init(parent: _RichTextViewRepresentable) {
            self.parent = parent
        }

        // MARK: - UITextViewDelegate

        func textViewDidChange(_ textView: UITextView) {
            parent.attributedText = textView.attributedText
            parent.toolbarViewModel.textStorage = textView.textStorage
            updatePlaceholder(in: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.toolbarViewModel.selectedRange = textView.selectedRange
            parent.toolbarViewModel.toolbarMode = textView.selectedRange.length > 0 ? .textSelected : .default
            parent.toolbarViewModel.syncFormattingState()
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
            updatePlaceholder(in: textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
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

// MARK: - Toolbar Assembly

private final class EditorAccessoryView: UIView {

    enum Constants {
        static let toolbarHeight: CGFloat = 44
    }

    private let hostingController = UIHostingController(rootView: AnyView(EmptyView()))

    init(
        toolbarViewModel: EditorToolbarViewModel,
        onInsertTable: @escaping () -> Void,
        onInsertImage: @escaping () -> Void,
        onInsertLink: @escaping () -> Void,
        onTapAI: @escaping () -> Void,
        onTapHighlight: @escaping () -> Void
    ) {
        super.init(frame: .init(x: 0, y: 0, width: 0, height: Constants.toolbarHeight))

        backgroundColor = .clear
        // 포맷 패널이 accessory view 경계 밖으로 올라올 수 있도록 clipsToBounds = false
        clipsToBounds = false
        autoresizingMask = [.flexibleWidth]

        hostingController.view.backgroundColor = .clear
        hostingController.view.clipsToBounds = false
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            hostingController.view.heightAnchor.constraint(equalToConstant: Constants.toolbarHeight)
        ])

        update(
            toolbarViewModel: toolbarViewModel,
            onInsertTable: onInsertTable,
            onInsertImage: onInsertImage,
            onInsertLink: onInsertLink,
            onTapAI: onTapAI,
            onTapHighlight: onTapHighlight
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Constants.toolbarHeight)
    }

    func update(
        toolbarViewModel: EditorToolbarViewModel,
        onInsertTable: @escaping () -> Void,
        onInsertImage: @escaping () -> Void,
        onInsertLink: @escaping () -> Void,
        onTapAI: @escaping () -> Void,
        onTapHighlight: @escaping () -> Void
    ) {
        hostingController.rootView = AnyView(
            EditorAccessoryRootView(
                toolbarViewModel: toolbarViewModel,
                onInsertTable: onInsertTable,
                onInsertImage: onInsertImage,
                onInsertLink: onInsertLink,
                onTapAI: onTapAI,
                onTapHighlight: onTapHighlight
            )
        )
    }
}

private struct EditorAccessoryRootView: View {

    @Bindable var toolbarViewModel: EditorToolbarViewModel
    var onInsertTable: () -> Void
    var onInsertImage: () -> Void
    var onInsertLink: () -> Void
    var onTapAI: () -> Void
    var onTapHighlight: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // 포맷 패널: 툴바 위로 슬라이드업
            if toolbarViewModel.isFormatPanelVisible {
                FormatPanelView(viewModel: toolbarViewModel)
                    .padding(.horizontal, 8)
                    .offset(y: -EditorAccessoryView.Constants.toolbarHeight)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }

            // 메인 툴바
            toolbarContent
                .frame(maxWidth: .infinity)
                .frame(height: EditorAccessoryView.Constants.toolbarHeight)
                .background(.ultraThinMaterial)
                .zIndex(0)
        }
        .animation(.easeInOut(duration: 0.2), value: toolbarViewModel.isFormatPanelVisible)
    }

    @ViewBuilder
    private var toolbarContent: some View {
        switch toolbarViewModel.toolbarMode {
        case .default:
            DefaultToolbarView(
                viewModel: toolbarViewModel,
                onInsertTable: onInsertTable,
                onInsertImage: onInsertImage,
                onInsertLink: onInsertLink,
                onTapAI: onTapAI,
                onTapHighlight: onTapHighlight
            )
        case .textSelected:
            TextSelectedToolbarView(
                viewModel: toolbarViewModel,
                onInsertLink: onInsertLink,
                onTapHighlight: onTapHighlight
            )
        case .tableCell:
            TableCellToolbarView(viewModel: toolbarViewModel)
        }
    }
}

private extension UITextView {

    var minimumHeight: CGFloat {
        let lineHeight = font?.lineHeight ?? UIFont.preferredFont(forTextStyle: .body).lineHeight
        return ceil(lineHeight + textContainerInset.top + textContainerInset.bottom)
    }
}
