//
//  SignUpEmailSection.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import SwiftUI

/// 회원가입 이메일 입력 · 인증 섹션
///
/// `FormEmailField`를 래핑하여 이메일 입력과 인증 코드 발송/확인 UI를 제공합니다.
/// - 외부에서 주입받는 상태: `email` 바인딩
/// - 외부에서 주입받는 콜백: `onVerificationRequested`, `onVerificationComplete`, `onEmailChanged`
/// - 이메일 값이 변경될 때마다 `onEmailChanged`를 호출하여 부모가 인증 리셋 여부를 결정합니다.
struct SignUpEmailSection: View {

    // MARK: - Property

    /// 사용자가 입력하는 이메일 값 (양방향 바인딩)
    @Binding var email: String

    /// 인증번호 발송 요청 — 실패 시 `throw`
    let onVerificationRequested: () async throws -> Void

    /// 인증번호 확인 요청 — 실패 시 `throw`
    let onVerificationComplete: (String) async throws -> Void

    /// 인증번호 재전송 요청 — 실패 시 `throw`
    let onResend: () async throws -> Void

    /// 이메일 값이 변경될 때 부모에게 알리는 콜백.
    /// 부모는 이 콜백 안에서 인증 상태 리셋 여부를 직접 판단합니다.
    let onEmailChanged: () -> Void

    /// 이메일 필드 제출(return) 시 포커스를 다음 필드로 이동시키는 콜백
    let onSubmit: () -> Void

    /// 인증 완료 시 "인증되었습니다" 성공 메시지 표시 여부 (기본값: true)
    ///
    /// 부모가 인증 이후 중복 확인 결과 행을 직접 노출하는 경우 `false`로 주어 메시지 중복을 피합니다.
    var showsVerifiedMessage: Bool = true

    // MARK: - Body

    var body: some View {
        FormEmailField(
            title: "이메일",
            placeholder: "example@example.com",
            text: $email,
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
