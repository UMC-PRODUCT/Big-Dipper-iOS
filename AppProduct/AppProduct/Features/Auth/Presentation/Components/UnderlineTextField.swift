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
/// `isSecure: true` 일 때 trailing에 eye 토글 버튼이 자동으로 표시됩니다.
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
    var guideMessage: String? = nil

    @State private var isPasswordRevealed: Bool = false

    // MARK: - Constant

    private enum Constants {
        static let underlineHeightUnfocused: CGFloat = 1
        static let underlineHeightFocused: CGFloat = 1.5
        static let fieldVerticalPadding: CGFloat = 8
        static let eyeIconSize: CGFloat = 20
        static let eyeButtonTouchTarget: CGFloat = 44
    }

    // MARK: - Body

    private var hasError: Bool { guideMessage != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            labelText
            fieldRow
            underline
            if let guideMessage {
                Text(guideMessage)
                    .appFont(.caption1, color: .red500)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: guideMessage)
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
    private var fieldRow: some View {
        if isSecure {
            HStack(spacing: 0) {
                secureFieldOverlay
                eyeToggleButton
            }
        } else {
            TextField("", text: $text, prompt: Text(placeholder).font(.app(.callout)))
                .keyboardType(keyboardType)
                .applyCommonFieldStyle(
                    focus: focusBinding,
                    submitLabel: submitLabel,
                    onSubmit: onSubmit
                )
        }
    }

    /// SecureField와 TextField를 겹쳐 렌더링한 뒤 opacity로 전환합니다.
    /// if/else 분기 대신 두 필드를 동시에 유지하면 SwiftUI가 뷰 아이덴티티를
    /// 재사용하므로 토글 시 포커스 손실이 발생하지 않습니다.
    private var secureFieldOverlay: some View {
        let promptText = Text(placeholder).font(.app(.callout))
        return ZStack {
            SecureField("", text: $text, prompt: promptText)
                .applyCommonFieldStyle(
                    focus: focusBinding,
                    submitLabel: submitLabel,
                    onSubmit: onSubmit
                )
                .opacity(isPasswordRevealed ? 0 : 1)
                .allowsHitTesting(!isPasswordRevealed)

            TextField("", text: $text, prompt: promptText)
                .applyCommonFieldStyle(
                    focus: focusBinding,
                    submitLabel: submitLabel,
                    onSubmit: onSubmit
                )
                .opacity(isPasswordRevealed ? 1 : 0)
                .allowsHitTesting(isPasswordRevealed)
        }
    }

    private var eyeToggleButton: some View {
        Button {
            isPasswordRevealed.toggle()
            // 전환 후 포커스를 즉시 재할당해 키보드를 유지합니다.
            focusBinding.wrappedValue = true
        } label: {
            Image(systemName: isPasswordRevealed ? "eye" : "eye.slash")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Constants.eyeIconSize, height: Constants.eyeIconSize)
                .foregroundStyle(Color.grey500)
        }
        .buttonStyle(.plain)
        .frame(width: Constants.eyeButtonTouchTarget, height: Constants.eyeButtonTouchTarget)
        .accessibilityLabel(Text(isPasswordRevealed ? "비밀번호 숨기기" : "비밀번호 표시"))
        .accessibilityHint(Text("비밀번호 표시 여부를 전환합니다"))
        .accessibilityAddTraits(.isButton)
    }

    private var underlineColor: Color {
        if hasError { return .red500 }
        return focusBinding.wrappedValue ? .indigo500 : .grey300
    }

    private var underline: some View {
        Rectangle()
            .fill(underlineColor)
            .frame(
                height: hasError || focusBinding.wrappedValue
                ? Constants.underlineHeightFocused
                : Constants.underlineHeightUnfocused
            )
            .animation(.easeInOut(duration: 0.15), value: focusBinding.wrappedValue)
            .animation(.easeInOut(duration: 0.15), value: hasError)
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
                label: "아이디",
                placeholder: "아이디를 입력하세요",
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
