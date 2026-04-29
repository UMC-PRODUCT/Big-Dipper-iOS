//
//  LoginByIdPwSection.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import SwiftUI

/// LoginView 상단의 ID/PW 입력 + 로그인 버튼 섹션
///
/// 로그인 ID와 비밀번호 입력 필드, 인라인 에러, "로그인" 버튼, "회원가입" 진입 텍스트 버튼을
/// 한 묶음으로 제공합니다. 상태(로딩/에러) 관리는 부모 ViewModel이 담당합니다.
struct LoginByIdPwSection: View {

    // MARK: - Property

    @Binding var loginId: String
    @Binding var password: String
    let isLoading: Bool
    let errorMessage: String?
    let onLoginTapped: () -> Void
    let onSignUpTapped: () -> Void

    @FocusState private var focusedField: Field?

    // MARK: - Field

    private enum Field: Hashable {
        case loginId
        case password
    }

    // MARK: - Constant

    private enum Constants {
        static let loginIdTitle: String = "로그인 ID"
        static let loginIdPlaceholder: String = "아이디 입력"
        static let passwordTitle: String = "비밀번호"
        static let passwordPlaceholder: String = "비밀번호 입력"
        static let loginButtonTitle: String = "로그인"
        static let signUpPromptText: String = "아직 계정이 없으신가요?"
        static let signUpButtonTitle: String = "회원가입"
        static let dividerText: String = "또는"
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            loginIdField
            passwordField

            if let errorMessage {
                Text(errorMessage)
                    .appFont(.footnote, color: .red500)
                    .padding(.leading, DefaultSpacing.spacing8)
            }

            loginButton
            dividerSection
            signUpButton
        }
    }

    // MARK: - Subviews

    private var loginIdField: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            TitleLabel(title: Constants.loginIdTitle, isRequired: true)
            TextField(
                "",
                text: $loginId,
                prompt: Text(Constants.loginIdPlaceholder).font(.callout)
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .foregroundStyle(.grey900)
            .padding(DefaultConstant.defaultTextFieldPadding)
            .glassEffect(.regular, in: .capsule)
            .submitLabel(.next)
            .focused($focusedField, equals: .loginId)
            .onSubmit { focusedField = .password }
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            TitleLabel(title: Constants.passwordTitle, isRequired: true)
            SecureField(
                "",
                text: $password,
                prompt: Text(Constants.passwordPlaceholder).font(.callout)
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .foregroundStyle(.grey900)
            .padding(DefaultConstant.defaultTextFieldPadding)
            .glassEffect(.regular, in: .capsule)
            .submitLabel(.done)
            .focused($focusedField, equals: .password)
            .onSubmit {
                focusedField = nil
                onLoginTapped()
            }
        }
    }

    private var loginButton: some View {
        MainButton(Constants.loginButtonTitle, action: {
            focusedField = nil
            onLoginTapped()
        })
        .loading(.constant(isLoading))
        .disabled(loginId.isEmpty || password.isEmpty)
        .buttonStyle(.glassProminent)
    }

    private var dividerSection: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Rectangle()
                .fill(.grey300)
                .frame(height: 1)
            Text(Constants.dividerText)
                .appFont(.footnote, color: .grey500)
            Rectangle()
                .fill(.grey300)
                .frame(height: 1)
        }
        .padding(.vertical, DefaultSpacing.spacing4)
    }

    private var signUpButton: some View {
        HStack(spacing: DefaultSpacing.spacing4) {
            Spacer()
            Text(Constants.signUpPromptText)
                .appFont(.footnote, color: .grey600)
            Button(Constants.signUpButtonTitle, action: onSignUpTapped)
                .appFont(.footnoteEmphasis, color: .indigo500)
                .buttonStyle(.plain)
            Spacer()
        }
    }
}
