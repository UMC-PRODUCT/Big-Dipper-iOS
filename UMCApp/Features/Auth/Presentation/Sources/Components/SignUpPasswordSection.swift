import CoreDesignSystem
import SwiftUI

/// 회원가입 비밀번호 · 비밀번호 확인 입력 섹션.
///
/// 검증 결과(8자 미만, 불일치)는 ViewModel이 계산해 내려주고, 이 컴포넌트는
/// 표시만 담당한다. 포커스는 부모의 `FocusState.Binding`을 그대로 주입받아
/// `SignUpNameNicknameSection`과 흐름을 공유한다.
struct SignUpPasswordSection: View {

    // MARK: - Property

    /// 비밀번호 입력값 (양방향 바인딩)
    @Binding var password: String

    /// 비밀번호 확인 입력값 (양방향 바인딩)
    @Binding var passwordConfirm: String

    /// 8자 이상 여부 (ViewModel의 계산 프로퍼티)
    let isPasswordValid: Bool

    /// 비밀번호 일치 여부 (ViewModel의 계산 프로퍼티)
    let isPasswordConfirmed: Bool

    /// 부모 View의 FocusState 바인딩 — 포커스 흐름을 부모가 일원 관리한다.
    var focusBinding: FocusState<SignUpFocusField?>.Binding

    /// 비밀번호 확인 필드 제출 시 포커스를 다음 필드로 이동시키는 콜백
    let onConfirmSubmit: () -> Void

    // MARK: - Constant

    fileprivate enum Constants {
        static let passwordTitle: String = "비밀번호"
        static let passwordPlaceholder: String = "8자 이상 입력"
        static let passwordConfirmTitle: String = "비밀번호 확인"
        static let passwordConfirmPlaceholder: String = "비밀번호 다시 입력"
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            passwordField
            passwordConfirmField
        }
    }

    // MARK: - Subviews

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            TitleLabel(title: Constants.passwordTitle, isRequired: true)
            SecureField(
                "",
                text: $password,
                prompt: Text(Constants.passwordPlaceholder).font(.app(.callout))
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .foregroundStyle(Color.grey900)
            .padding(DefaultConstant.defaultTextFieldPadding)
            .glassEffect(.regular, in: .capsule)
            .submitLabel(.next)
            .focused(focusBinding, equals: .password)
            .onSubmit { focusBinding.wrappedValue = .passwordConfirm }

            if !password.isEmpty, !isPasswordValid {
                Text("8자 이상 입력해 주세요.")
                    .appFont(.footnote, color: .red500)
                    .padding(.leading, DefaultSpacing.spacing8)
            }
        }
    }

    private var passwordConfirmField: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            TitleLabel(title: Constants.passwordConfirmTitle, isRequired: true)
            SecureField(
                "",
                text: $passwordConfirm,
                prompt: Text(Constants.passwordConfirmPlaceholder).font(.app(.callout))
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .foregroundStyle(Color.grey900)
            .padding(DefaultConstant.defaultTextFieldPadding)
            .glassEffect(.regular, in: .capsule)
            .submitLabel(.next)
            .focused(focusBinding, equals: .passwordConfirm)
            .onSubmit(onConfirmSubmit)

            if !passwordConfirm.isEmpty, !isPasswordConfirmed {
                Text("비밀번호가 일치하지 않습니다.")
                    .appFont(.footnote, color: .red500)
                    .padding(.leading, DefaultSpacing.spacing8)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
private struct SignUpPasswordSectionPreviewWrapper: View {
    @FocusState private var focusedField: SignUpFocusField?
    @State private var password: String = "1234"
    @State private var passwordConfirm: String = "123"

    var body: some View {
        SignUpPasswordSection(
            password: $password,
            passwordConfirm: $passwordConfirm,
            isPasswordValid: password.count >= 8,
            isPasswordConfirmed: !passwordConfirm.isEmpty && password == passwordConfirm,
            focusBinding: $focusedField,
            onConfirmSubmit: { focusedField = .name }
        )
        .padding()
    }
}

#Preview {
    SignUpPasswordSectionPreviewWrapper()
}
#endif
