import CoreDesignSystem
import SwiftUI

/// 제목(`TitleLabel`) + 텍스트 필드를 수직으로 배치하는 공용 폼 입력 컴포넌트.
///
/// `@Binding`/클로저 콜백만으로 동작하는 dumb 컴포넌트이며,
/// `SignUpNameNicknameSection` 등 회원가입 섹션이 공유한다.
struct FormTextField: View {

    // MARK: - Property

    let title: String
    let placeholder: String
    @Binding var text: String
    var isRequired: Bool = true
    var submitLabel: SubmitLabel = .next
    var onSubmit: (() -> Void)?

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            TitleLabel(title: title, isRequired: isRequired)
            textFieldView
        }
    }

    // MARK: - Subviews

    private var textFieldView: some View {
        TextField("", text: $text, prompt: placeholderView)
            .foregroundStyle(Color.grey900)
            .padding(DefaultConstant.defaultTextFieldPadding)
            .glassEffect(.regular, in: .capsule)
            .submitLabel(submitLabel)
            .onSubmit { onSubmit?() }
    }

    private var placeholderView: Text {
        Text(placeholder)
            .font(.app(.callout))
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    @Previewable @State var name: String = ""
    VStack(spacing: DefaultSpacing.spacing16) {
        FormTextField(title: "이름", placeholder: "이름 입력", text: $name, submitLabel: .done)
        FormTextField(title: "닉네임", placeholder: "한글 1~5자", text: .constant("umc챌린저"))
    }
    .padding()
}
#endif
