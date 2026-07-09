import CoreDesignSystem
import SwiftUI

/// 회원가입 화면의 이메일 인증 섹션 — `FormEmailField`에 회원가입 전용 문구/제출 동작을 고정한다.
///
/// 재전송(`onResend`)은 `SignUpView`/`SignUpByIdPwView` 두 화면 모두에서 지원해야 하므로
/// (PM 결정 Q5) 필수 파라미터로 둔다.
struct SignUpEmailSection: View {

    // MARK: - Property

    @Binding var email: String
    @Binding var isVerified: Bool
    let onVerificationRequested: () async throws -> Void
    let onVerificationComplete: (String) async throws -> Void
    let onResend: () async throws -> Void
    var onEmailChanged: (() -> Void)?
    var onSubmit: (() -> Void)?
    var showsVerifiedMessage: Bool = true

    // MARK: - Constant

    private enum Constants {
        static let title = "이메일"
        static let placeholder = "example@example.com"
    }

    // MARK: - Body

    var body: some View {
        FormEmailField(
            title: Constants.title,
            placeholder: Constants.placeholder,
            text: $email,
            isVerified: $isVerified,
            onVerificationRequested: onVerificationRequested,
            onVerificationComplete: onVerificationComplete,
            onResend: onResend,
            showsVerifiedMessage: showsVerifiedMessage,
            submitLabel: .next,
            onSubmit: onSubmit,
            onEmailChanged: onEmailChanged
        )
    }
}

// MARK: - Preview

#if DEBUG
private struct SignUpEmailSectionPreviewWrapper: View {
    @State private var email: String = ""
    @State private var isVerified: Bool = false

    var body: some View {
        SignUpEmailSection(
            email: $email,
            isVerified: $isVerified,
            onVerificationRequested: {
                try await Task.sleep(for: .seconds(1))
            },
            onVerificationComplete: { _ in
                try await Task.sleep(for: .seconds(1))
            },
            onResend: {
                try await Task.sleep(for: .seconds(1))
            }
        )
        .padding()
    }
}

#Preview {
    SignUpEmailSectionPreviewWrapper()
}
#endif
