//
//  LoginByIdPwSection.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import SwiftUI

/// LoginView 상단의 ID/PW 입력 + 로그인 버튼 섹션
///
/// 로그인 ID와 비밀번호 입력 필드, 인라인 에러, "로그인" 버튼을 한 묶음으로 제공합니다.
/// 상태(로딩/에러) 관리는 부모 ViewModel이 담당합니다. 디바이더/회원가입/소셜 로그인은
/// 하단 그룹(`BottomAuthSection`)에서 묶어 노출합니다.
struct LoginByIdPwSection: View {

    // MARK: - Property

    @Binding var loginId: String
    @Binding var password: String
    let isLoading: Bool
    let errorMessage: String?
    let onLoginTapped: () -> Void

    @FocusState private var focusedField: Field?

    // MARK: - Field

    private enum Field: Hashable {
        case loginId
        case password
    }

    // MARK: - Constant

    private enum Constants {
        static let loginIdPlaceholder: String = "아이디 입력"
        static let passwordPlaceholder: String = "비밀번호 입력"
        static let loginButtonTitle: String = "로그인"
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
        }
    }
    
    // MARK: - Subviews
    
    private var loginIdField: some View {
        TextField(
            "",
            text: $loginId,
            prompt: Text(Constants.loginIdPlaceholder).font(.app(.callout))
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
        .foregroundStyle(.grey900)
        .padding(DefaultConstant.defaultTextFieldPadding)
        .glassEffect(.regular, in: .capsule)
        .submitLabel(.next)
        .focused($focusedField, equals: .loginId)
        .onSubmit { focusedField = .password }
        .accessibilityLabel(Text("로그인 ID"))
    }
    
    private var passwordField: some View {
        SecureField(
            "",
            text: $password,
            prompt: Text(Constants.passwordPlaceholder).font(.app(.callout))
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
        .accessibilityLabel(Text("비밀번호"))
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
}
