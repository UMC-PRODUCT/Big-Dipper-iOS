//
//  SignUpPasswordSection.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import SwiftUI

/// 회원가입 비밀번호 · 비밀번호 확인 입력 섹션
///
/// 두 `SecureField`를 묶어 제공하며, 각 검증 결과(8자 미만, 불일치)를
/// 인라인 텍스트로 표시합니다.
/// - 외부에서 주입받는 상태: `password`, `passwordConfirm` 바인딩
/// - 외부에서 주입받는 검증 결과: `isPasswordValid`, `isPasswordConfirmed` (ViewModel 계산 프로퍼티)
/// - 포커스는 부모의 `FocusState.Binding`을 직접 주입받아 관리합니다.
struct SignUpPasswordSection: View {

    // MARK: - Property

    /// 비밀번호 입력값 (양방향 바인딩)
    @Binding var password: String

    /// 비밀번호 확인 입력값 (양방향 바인딩)
    @Binding var passwordConfirm: String

    /// 8자 이상 여부 (ViewModel의 `isPasswordValid`)
    let isPasswordValid: Bool

    /// 비밀번호 일치 여부 (ViewModel의 `isPasswordConfirmed`)
    let isPasswordConfirmed: Bool

    /// 부모 View의 FocusState 바인딩 — 포커스 흐름을 부모가 일원 관리합니다.
    var focusBinding: FocusState<SignUpByIdPwField?>.Binding

    /// 비밀번호 확인 필드 제출 시 포커스를 다음 필드로 이동시키는 콜백
    let onConfirmSubmit: () -> Void

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
                prompt: Text(Constants.passwordPlaceholder).font(.callout)
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .foregroundStyle(.grey900)
            .padding(DefaultConstant.defaultTextFieldPadding)
            .glassEffect(.regular, in: .capsule)
            .submitLabel(.next)
            .focused(focusBinding, equals: .password)
            .onSubmit { focusBinding.wrappedValue = .passwordConfirm }

            // 입력이 시작된 후에만 오류 메시지를 표시하여 사용자 경험 개선
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
                prompt: Text(Constants.passwordConfirmPlaceholder).font(.callout)
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .foregroundStyle(.grey900)
            .padding(DefaultConstant.defaultTextFieldPadding)
            .glassEffect(.regular, in: .capsule)
            .submitLabel(.next)
            .focused(focusBinding, equals: .passwordConfirm)
            .onSubmit(onConfirmSubmit)

            // 입력이 시작된 후에만 오류 메시지를 표시하여 사용자 경험 개선
            if !passwordConfirm.isEmpty, !isPasswordConfirmed {
                Text("비밀번호가 일치하지 않습니다.")
                    .appFont(.footnote, color: .red500)
                    .padding(.leading, DefaultSpacing.spacing8)
            }
        }
    }

    // MARK: - Constant

    private enum Constants {
        static let passwordTitle: String = "비밀번호"
        static let passwordPlaceholder: String = "8자 이상 입력"
        static let passwordConfirmTitle: String = "비밀번호 확인"
        static let passwordConfirmPlaceholder: String = "비밀번호 다시 입력"
    }
}
