//
//  FormEmailField.swift
//  AuthPresentation
//
//  Created by euijjang97 on 7/9/26.
//

import CoreDesignSystem
import Foundation
import SwiftUI
import UMCFoundation

/// 이메일 입력 + 인증코드 발송/검증/재발송 UI를 캡슐화한 폼 필드.
///
/// 인증 진행 단계(코드 발송 전/후, 검증 중)는 컴포넌트 내부 `@State`(UI 로컬 상태)로만
/// 관리한다. 반면 "인증 완료 여부"는 비즈니스 상태이므로 `isVerified` 바인딩으로
/// 외부화해 부모(ViewModel)가 단일 소스로 유지하도록 한다.
struct FormEmailField: View {

    // MARK: - Phase

    /// 인증 진행 단계. `.verified` 케이스를 두지 않고 `isVerified` 바인딩으로 대체한다.
    private enum Phase: Equatable {
        case initial
        case codeRequested
        case verifying
        case failed
    }

    // MARK: - Property

    let title: String
    let placeholder: String
    @Binding var text: String

    /// 인증 완료 여부 (양방향 바인딩) — 이메일이 변경되면 컴포넌트가 직접 `false`로 되돌린다.
    @Binding var isVerified: Bool

    /// 인증번호 발송 요청 — 실패 시 `throw`
    let onVerificationRequested: () async throws -> Void

    /// 인증번호 검증 요청 — 실패 시 `throw`
    let onVerificationComplete: (String) async throws -> Void

    /// 인증번호 재전송 요청 — 실패 시 `throw`. `nil`이면 재전송 버튼을 표시하지 않는다.
    var onResend: (() async throws -> Void)?

    var isRequired: Bool = true

    /// 인증 완료 시 "인증되었습니다" 성공 메시지 표시 여부.
    ///
    /// 부모가 인증 이후 별도 상태 행(예: 이메일 중복 확인 결과)을 직접 노출하는 경우
    /// 같은 의미의 메시지가 중복되지 않도록 `false`를 준다.
    var showsVerifiedMessage: Bool = true

    var submitLabel: SubmitLabel = .return
    var onSubmit: (() -> Void)?

    /// 이메일 텍스트가 변경될 때 실행되는 콜백 (인증 상태 리셋과는 별개로 매 입력마다 호출됨)
    var onEmailChanged: (() -> Void)?

    @State private var showError: Bool = false
    @State private var phase: Phase = .initial
    @State private var verificationCode: String = ""
    @State private var resendCooldownSeconds: Int = 0
    @State private var customErrorMessage: String?

    // MARK: - Constant

    fileprivate enum Constants {
        static let errorPadding: CGFloat = 10
        static let verificationCodeLength: Int = 6
        static let requestButtonTitle: String = "인증요청"
        static let completedButtonTitle: String = "인증 완료"
        static let defaultErrorMessage: String = "유효하지 않은 이메일입니다."
        static let successMessage: String = "인증되었습니다."
        static let successImage: String = "checkmark.circle.fill"
        static let resendCooldown: Int = 60
    }

    // MARK: - Computed Property

    private var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: text)
    }

    private var buttonText: String {
        isVerified || phase == .codeRequested
            ? Constants.completedButtonTitle
            : Constants.requestButtonTitle
    }

    private var buttonForegroundColor: Color {
        isVerified || text.isEmpty ? .grey400 : .white
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            TitleLabel(title: title, isRequired: isRequired)
            textFieldView

            if showError {
                errorMessageView
            }

            if !isVerified, phase == .codeRequested || phase == .verifying {
                verificationCodeField
                if onResend != nil {
                    resendButton
                }
            }

            if isVerified, showsVerifiedMessage {
                successMessageView
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: phase)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isVerified)
        .task(id: phase) {
            await runResendCooldownIfNeeded()
        }
    }

    // MARK: - Subviews

    private var textFieldView: some View {
        HStack {
            TextField("", text: $text, prompt: placeholderView)
                .foregroundStyle(Color.grey900)
                .tint(showError ? .red500 : .indigo500)
                .padding(DefaultConstant.defaultTextFieldPadding)
                .submitLabel(submitLabel)
                .glassEffect(.regular, in: .capsule)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .onSubmit { onSubmit?() }
                .onChange(of: text) { _, _ in
                    if showError {
                        showError = false
                    }
                    resetVerificationStateForEmailChange()
                    onEmailChanged?()
                }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: DefaultConstant.animationTime)) {
                    handleButtonTap()
                }
            } label: {
                Text(buttonText)
                    .appFont(.callout, color: buttonForegroundColor)
                    .padding(DefaultConstant.defaultBtnPadding)
            }
            .buttonStyle(.glassProminent)
            .tint(isVerified ? .green500 : .indigo500)
            .disabled(text.isEmpty || phase == .verifying || isVerified)
        }
    }

    private var placeholderView: Text {
        Text(placeholder)
            .font(.app(.callout))
    }

    private var errorMessageView: some View {
        Text(customErrorMessage ?? Constants.defaultErrorMessage)
            .appFont(.footnote, color: .red500)
            .padding(.leading, Constants.errorPadding)
    }

    private var resendButton: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Spacer()
            Button {
                handleResendTap()
            } label: {
                Text(
                    resendCooldownSeconds > 0
                        ? "재전송 (\(resendCooldownSeconds)초)"
                        : "인증번호 재전송"
                )
                .appFont(.footnote, color: resendCooldownSeconds > 0 ? .grey500 : .indigo500)
            }
            .buttonStyle(.plain)
            .disabled(resendCooldownSeconds > 0 || phase == .verifying)
        }
        .padding(.horizontal, Constants.errorPadding)
    }

    private var verificationCodeField: some View {
        TextField("", text: $verificationCode, prompt: Text("인증번호 6자리").font(.app(.callout)))
            .foregroundStyle(Color.grey900)
            .padding(DefaultConstant.defaultTextFieldPadding)
            .glassEffect(.regular, in: .capsule)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .onChange(of: verificationCode) { _, newValue in
                if newValue.count > Constants.verificationCodeLength {
                    verificationCode = String(newValue.prefix(Constants.verificationCodeLength))
                }
            }
            .transition(.asymmetric(
                insertion: .scale(scale: DefaultConstant.transitionScale).combined(with: .opacity),
                removal: .scale(scale: DefaultConstant.transitionScale).combined(with: .opacity)
            ))
    }

    private var successMessageView: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Image(systemName: Constants.successImage)
                .foregroundStyle(Color.green500)
            Text(Constants.successMessage)
                .appFont(.footnote, color: .green500)
        }
        .padding(.leading, Constants.errorPadding)
        .transition(.asymmetric(
            insertion: .scale(scale: DefaultConstant.transitionScale).combined(with: .opacity),
            removal: .scale(scale: DefaultConstant.transitionScale).combined(with: .opacity)
        ))
    }
}

// MARK: - Function

private extension FormEmailField {

    /// 인증 버튼 탭 핸들러.
    ///
    /// - `.initial`/`.failed`: 이메일 형식 검증 → 인증번호 요청 → `.codeRequested`
    /// - `.codeRequested`: 인증번호 검증 → 성공 시 `isVerified = true`
    func handleButtonTap() {
        guard isValidEmail else {
            customErrorMessage = nil
            showError = true
            return
        }

        showError = false
        customErrorMessage = nil

        switch phase {
        case .initial, .failed:
            Task {
                do {
                    verificationCode = ""
                    phase = .verifying
                    try await onVerificationRequested()
                    resendCooldownSeconds = Constants.resendCooldown
                    phase = .codeRequested
                } catch {
                    customErrorMessage = userMessage(for: error)
                    showError = true
                    phase = .initial
                }
            }

        case .codeRequested:
            guard !verificationCode.isEmpty else { return }
            Task {
                do {
                    phase = .verifying
                    try await onVerificationComplete(verificationCode)
                    isVerified = true
                    phase = .initial
                } catch {
                    customErrorMessage = userMessage(for: error)
                    phase = .failed
                    showError = true
                }
            }

        case .verifying:
            break
        }
    }

    /// 재전송 버튼 탭 핸들러 — 쿨다운이 끝났을 때만 동작하며, 성공 시 쿨다운을 재시작한다.
    func handleResendTap() {
        guard let onResend, resendCooldownSeconds == 0 else { return }
        Task {
            do {
                customErrorMessage = nil
                showError = false
                try await onResend()
                verificationCode = ""
                resendCooldownSeconds = Constants.resendCooldown
            } catch {
                customErrorMessage = userMessage(for: error)
                showError = true
            }
        }
    }

    /// 재전송 쿨다운 카운트다운 — `.codeRequested` 진입 시에만 시작한다.
    func runResendCooldownIfNeeded() async {
        guard phase == .codeRequested else { return }
        if resendCooldownSeconds == 0 {
            resendCooldownSeconds = Constants.resendCooldown
        }
        while resendCooldownSeconds > 0 {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            if Task.isCancelled { return }
            resendCooldownSeconds = max(0, resendCooldownSeconds - 1)
        }
    }

    /// 에러 → 사용자 표시 문구. `AppError`/`LocalizedError`를 우선 사용하고, 그 외엔 기본 문구.
    func userMessage(for error: Error) -> String {
        if let appError = error as? AppError {
            return appError.userMessage
        }
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return Constants.defaultErrorMessage
    }

    /// 이메일 변경 시 인증 상태를 초기화한다. `isVerified`도 함께 되돌려 비즈니스 상태를
    /// 항상 텍스트와 일치시킨다.
    func resetVerificationStateForEmailChange() {
        guard phase != .initial || isVerified else { return }
        verificationCode = ""
        phase = .initial
        resendCooldownSeconds = 0
        customErrorMessage = nil
        isVerified = false
    }
}

// MARK: - Preview

#if DEBUG
private struct FormEmailFieldPreviewWrapper: View {
    @State private var email: String = ""
    @State private var isVerified: Bool = false

    var body: some View {
        FormEmailField(
            title: "이메일",
            placeholder: "example@example.com",
            text: $email,
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
    FormEmailFieldPreviewWrapper()
}
#endif
