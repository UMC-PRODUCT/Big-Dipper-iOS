import CoreDesignSystem
import SwiftUI

/// 회원가입 이름 · 닉네임 입력 섹션.
///
/// 이름과 닉네임 필드를 `HStack`으로 나란히 배치한다. 포커스는 부모의
/// `FocusState.Binding`을 그대로 주입받아 `SignUpPasswordSection`과 흐름을 공유한다.
struct SignUpNameNicknameSection: View {

    // MARK: - Property

    /// 이름 입력값 (양방향 바인딩)
    @Binding var name: String

    /// 닉네임 입력값 (양방향 바인딩)
    @Binding var nickname: String

    /// 부모 View의 FocusState 바인딩 — 포커스 흐름을 부모가 일원 관리한다.
    var focusBinding: FocusState<SignUpFocusField?>.Binding

    /// 닉네임 필드 제출 시 포커스를 해제하는 콜백
    let onNicknameSubmit: () -> Void

    // MARK: - Constant

    private enum Constants {
        static let nameTitle: String = "이름"
        static let namePlaceholder: String = "이름 입력"
        static let nicknameTitle: String = "닉네임"
        static let nicknamePlaceholder: String = "한글 1~5자"
    }

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
}

// MARK: - Preview

#if DEBUG
private struct SignUpNameNicknameSectionPreviewWrapper: View {
    @FocusState private var focusedField: SignUpFocusField?
    @State private var name: String = ""
    @State private var nickname: String = ""

    var body: some View {
        SignUpNameNicknameSection(
            name: $name,
            nickname: $nickname,
            focusBinding: $focusedField,
            onNicknameSubmit: { focusedField = nil }
        )
        .padding()
    }
}

#Preview {
    SignUpNameNicknameSectionPreviewWrapper()
}
#endif
