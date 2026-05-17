//
//  SignUpNameNicknameSection.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import SwiftUI

/// 회원가입 이름 · 닉네임 입력 섹션
///
/// 이름과 닉네임 필드를 `HStack`으로 나란히 배치합니다.
/// - 외부에서 주입받는 상태: `name`, `nickname` 바인딩
/// - 포커스는 부모의 `FocusState.Binding`을 직접 주입받아 관리합니다.
struct SignUpNameNicknameSection: View {

    // MARK: - Property

    /// 이름 입력값 (양방향 바인딩)
    @Binding var name: String

    /// 닉네임 입력값 (양방향 바인딩)
    @Binding var nickname: String

    /// 부모 View의 FocusState 바인딩 — 포커스 흐름을 부모가 일원 관리합니다.
    var focusBinding: FocusState<SignUpByIdPwField?>.Binding

    /// 닉네임 필드 제출 시 포커스를 해제하는 콜백
    let onNicknameSubmit: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: DefaultSpacing.spacing12) {
            FormTextField(
                title: Constants.nameTitle,
                placeholder: Constants.namePlaceholder,
                text: $name,
                isRequired: true,
                submitLabel: .next,
                onSubmit: { focusBinding.wrappedValue = .nickname }
            )
            .focused(focusBinding, equals: .name)

            FormTextField(
                title: Constants.nicknameTitle,
                placeholder: Constants.nicknamePlaceholder,
                text: $nickname,
                isRequired: true,
                submitLabel: .done,
                onSubmit: onNicknameSubmit
            )
            .focused(focusBinding, equals: .nickname)
        }
    }

    // MARK: - Constant

    private enum Constants {
        static let nameTitle: String = "이름"
        static let namePlaceholder: String = "이름 입력"
        static let nicknameTitle: String = "닉네임"
        static let nicknamePlaceholder: String = "한글 1~5자"
    }
}
