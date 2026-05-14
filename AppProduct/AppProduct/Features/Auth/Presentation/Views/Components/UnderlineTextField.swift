//
//  UnderlineTextField.swift
//  AppProduct
//
//  Created by euijjang97 on 5/14/26.
//

import SwiftUI

/// 라벨 + 입력 필드 + 언더라인 3-레이어로 구성된 텍스트 필드 컴포넌트
///
/// 포커스 상태에 따라 라벨과 언더라인 색상이 `grey` → `indigo500` 으로 전환됩니다.
/// `SecureField` 모드를 지원하며, ID/PW 로그인 화면에 사용됩니다.
struct UnderlineTextField: View {

    // MARK: - Property

    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var submitLabel: SubmitLabel = .next
    var keyboardType: UIKeyboardType = .default
    var onSubmit: (() -> Void)? = nil
    var focusBinding: FocusState<Bool>.Binding

    // MARK: - Constant

    private enum Constants {
        static let underlineHeightUnfocused: CGFloat = 1
        static let underlineHeightFocused: CGFloat = 1.5
        static let fieldVerticalPadding: CGFloat = 8
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            labelText
            field
            underline
        }
    }

    // MARK: - Subviews

    private var labelText: some View {
        Text(label)
            .appFont(
                .caption1Emphasis,
                color: focusBinding.wrappedValue ? .indigo500 : .grey500
            )
            .animation(.easeInOut(duration: 0.15), value: focusBinding.wrappedValue)
    }

    @ViewBuilder
    private var field: some View {
        let promptText = Text(placeholder).font(.app(.callout))
        if isSecure {
            SecureField("", text: $text, prompt: promptText)
                .applyCommonFieldStyle(
                    focus: focusBinding,
                    submitLabel: submitLabel,
                    onSubmit: onSubmit
                )
        } else {
            TextField("", text: $text, prompt: promptText)
                .keyboardType(keyboardType)
                .applyCommonFieldStyle(
                    focus: focusBinding,
                    submitLabel: submitLabel,
                    onSubmit: onSubmit
                )
        }
    }

    private var underline: some View {
        Rectangle()
            .fill(focusBinding.wrappedValue ? Color.indigo500 : Color.grey300)
            .frame(
                height: focusBinding.wrappedValue
                ? Constants.underlineHeightFocused
                : Constants.underlineHeightUnfocused
            )
            .animation(.easeInOut(duration: 0.15), value: focusBinding.wrappedValue)
    }
}

// MARK: - Field Style Helper

private extension View {

    /// TextField / SecureField 공통 스타일 적용 헬퍼
    func applyCommonFieldStyle(
        focus: FocusState<Bool>.Binding,
        submitLabel: SubmitLabel,
        onSubmit: (() -> Void)?
    ) -> some View {
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .foregroundStyle(Color.grey900)
            .font(.app(.callout))
            .padding(.vertical, 8)
            .submitLabel(submitLabel)
            .focused(focus)
            .onSubmit { onSubmit?() }
    }
}

#if DEBUG
private struct UnderlineTextFieldPreview: View {

    @State private var idText: String = ""
    @State private var pwText: String = "abcd1234"
    @FocusState private var idFocused: Bool
    @FocusState private var pwFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            UnderlineTextField(
                label: "아이디 또는 휴대폰번호",
                placeholder: "아이디 또는 휴대폰번호를 입력하세요",
                text: $idText,
                focusBinding: $idFocused
            )

            UnderlineTextField(
                label: "비밀번호",
                placeholder: "비밀번호를 입력하세요",
                text: $pwText,
                isSecure: true,
                submitLabel: .done,
                focusBinding: $pwFocused
            )
        }
        .padding(24)
    }
}

#Preview("UnderlineTextField") {
    UnderlineTextFieldPreview()
}
#endif
