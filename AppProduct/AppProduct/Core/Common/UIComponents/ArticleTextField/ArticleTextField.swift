//
//  ArticleTextField.swift
//  AppProduct
//
//  Created by 이예지 on 1/26/26.
//

import SwiftUI

struct ArticleTextField: View {

    // MARK: - Property

    let placeholder: ArticleTextFieldType
    @Binding var text: String
    private let focused: FocusState<Bool>.Binding?
    private let submitLabel: SubmitLabel
    private let onSubmit: (() -> Void)?

    // MARK: - Initializer

    init(
        placeholder: ArticleTextFieldType,
        text: Binding<String>,
        focused: FocusState<Bool>.Binding? = nil,
        submitLabel: SubmitLabel = .return,
        onSubmit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.focused = focused
        self.submitLabel = submitLabel
        self.onSubmit = onSubmit
    }

    // MARK: - Body

    var body: some View {
        switch placeholder {
        case .title:
            titleField
        case .content:
            contentEditor
        }
    }

    // MARK: - Function

    private var titleField: some View {
        let field = TextField(
            "",
            text: $text,
            prompt: Text(placeholder.placeholderLabel),
            axis: placeholder.axis
        )
        .font(.app(placeholder.placeholderFont))
        .scrollIndicators(placeholder.scrollIndicator)
        .submitLabel(submitLabel)
        .onSubmit {
            onSubmit?()
        }

        return Group {
            if let focused {
                field.focused(focused)
            } else {
                field
            }
        }
    }

    private var contentEditor: some View {
        let editor = TextEditor(text: $text)
            .font(.app(placeholder.placeholderFont))
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .scrollIndicators(.hidden)
            .overlay(alignment: .topLeading) {
                if text.isEmpty && focused?.wrappedValue != true {
                    Text(placeholder.placeholderLabel)
                        .font(.app(placeholder.placeholderFont))
                        .foregroundStyle(.placeholder)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }

        return Group {
            if let focused {
                editor.focused(focused)
            } else {
                editor
            }
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var text = ""
    ArticleTextField(placeholder: .title, text: $text)
}
