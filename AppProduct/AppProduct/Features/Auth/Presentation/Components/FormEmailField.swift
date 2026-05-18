//
//  FormEmailField.swift
//  AppProduct
//
//  Created by euijjang97 on 1/12/26.
//

import SwiftUI

/// 이메일 인증 기능이 포함된 폼 입력 필드
///
/// 이메일 입력과 동시에 인증번호 요청 및 검증 프로세스를 처리하는 컴포넌트입니다.
/// 이메일 형식 유효성 검사, 인증번호 입력, 상태별 UI 변화를 제공합니다.
struct FormEmailField: View {

    // MARK: - Enum

    /// 이메일 인증 프로세스의 상태
    enum VerificationState {
        /// 초기 상태 - 인증 요청 전
        case initial

        /// 인증번호 요청 완료 - 인증번호 입력 필드 표시
        case codeRequested

        /// 인증번호 검증 중 - 로딩 상태
        case verifying

        /// 인증 완료 - 성공 메시지 표시
        case verified

        /// 인증 실패 - 에러 메시지 표시
        case failed
    }

    // MARK: - Property

    /// 필드 제목
    let title: String

    /// 플레이스홀더 텍스트
    let placeholder: String

    /// 이메일 입력 텍스트 바인딩
    @Binding var text: String

    /// 인증번호 요청 시 실행될 비동기 클로저
    let onVerificationRequested: () async throws -> Void

    /// 인증번호 검증 시 실행될 비동기 클로저 (인증번호를 파라미터로 받음)
    let onVerificationComplete: (String) async throws -> Void

    /// 인증번호 재전송 시 실행될 비동기 클로저
    ///
    /// nil이면 재전송 버튼을 표시하지 않습니다.
    var onResend: (() async throws -> Void)? = nil

    /// 필수 입력 여부 (기본값: true)
    var isRequired: Bool = true

    /// 키보드 완료 버튼 타입 (기본값: .return)
    var submitLabel: SubmitLabel = .return

    /// 키보드 완료 시 실행될 클로저
    var onSubmit: (() -> Void)?
    
    /// 이메일 텍스트가 변경될 때 실행될 클로저
    var onEmailChanged: (() -> Void)? = nil

    /// 이메일 형식 오류 표시 여부
    @State private var showError: Bool = false

    /// 현재 인증 상태
    @State private var verificationState: VerificationState = .initial

    /// 입력된 인증번호
    @State private var verificationCode: String = ""

    /// 인증 발송/재전송 throttle 남은 초 (0이면 재전송 가능)
    @State private var resendCooldownSeconds: Int = 0

    /// 표시할 에러 메시지 (이메일 형식 외 서버 에러용)
    @State private var customErrorMessage: String? = nil

    /// 애니메이션 네임스페이스
    @Namespace var namespace
    
    // MARK: - Computed Properties

    /// 이메일 형식 유효성 검증
    ///
    /// 정규표현식을 사용하여 이메일 형식이 올바른지 확인합니다.
    private var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: text)
    }

    /// 인증 상태에 따른 버튼 텍스트
    ///
    /// - initial/verifying/failed: "인증요청"
    /// - codeRequested/verified: "인증 완료"
    private var buttonText: String {
        switch verificationState {
        case .initial, .verifying, .failed:
            return Constants.btnText[0]
        case .verified, .codeRequested:
            return Constants.btnText[1]
        }
    }
    
    private var verifiedCheck: Bool {
        verificationState == .verified
    }

    // MARK: - Constant

    /// 레이아웃 및 텍스트 상수
    private enum Constants {
        /// 타이틀 간격 (미사용)
        static let titleSpacing: CGFloat = 2

        /// 코너 반경 (미사용)
        static let cornerRadius: CGFloat = 8

        /// 에러/성공 메시지 좌측 패딩
        static let errorPadding: CGFloat = 10

        /// 인증번호 입력 가능 최대 자릿수
        static let verificationCount: Int = 6

        /// 버튼 텍스트 배열 [인증요청, 인증 완료]
        static let btnText: [String] = ["인증요청", "인증 완료"]

        /// 이메일 형식 오류 메시지
        static let errorMsg: String = "유효하지 않은 이메일입니다."

        /// 인증 완료 성공 메시지
        static let successMsg: String = "인증되었습니다."

        /// 성공 아이콘 SF Symbol 이름
        static let successImage: String = "checkmark.circle.fill"

        /// 재전송 throttle 기본 초 (서버와 동일하게 60초)
        static let resendCooldown: Int = 60
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8, content: {
            TitleLabel(title: title, isRequired: isRequired)
            textFieldView

            if showError {
                erroMsg
            }

            // 인증번호 입력 필드
            if verificationState == .codeRequested || verificationState == .verifying {
                verificationCodeField

                if onResend != nil {
                    resendButton
                }
            }

            // 성공 메시지
            if verificationState == .verified {
                successMessage
            }
        })
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: verificationState)
        .task(id: verificationState) {
            // codeRequested 진입 시 60초 카운트다운 시작
            guard verificationState == .codeRequested else { return }
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
    }
    
    /// 이메일 입력 필드 및 인증 버튼
    ///
    /// HStack으로 구성되며, TextField와 인증 버튼이 나란히 배치됩니다.
    /// 텍스트 변경 시 에러 상태를 초기화하고, 버튼은 상태에 따라 비활성화됩니다.
    private var textFieldView: some View {
        HStack(content: {
            TextField("", text: $text, prompt: placeholderView)
                .foregroundStyle(.grey900)
                .tint(showError ? .red500 : .blue)
                .padding(DefaultConstant.defaultTextFieldPadding)
                .submitLabel(submitLabel)
                .glassEffect(.regular, in: .capsule)
                .keyboardType(.emailAddress)
                .onSubmit {
                    onSubmit?()
                }
                .onChange(of: text) { _, _ in
                    if showError {
                        showError = false
                    }
                    resetVerificationStateForEmailChange()
                    onEmailChanged?()
                }

            Spacer()

            // 인증 요청/완료 버튼
            Button(action: {
                withAnimation(.easeInOut(duration: DefaultConstant.animationTime), {
                    handleButtonTap()
                })
            }, label: {
                Text(buttonText)
                    .appFont(.callout, color: verifiedCheck ? .gray : (text.isEmpty) ? .gray : .white)
                    .padding(DefaultConstant.defaultBtnPadding)
            })
            .buttonStyle(.glassProminent)
            .tint(verifiedCheck ? .green : .indigo500)
            .disabled(text.isEmpty || verificationState == .verifying || verificationState == .verified)
        })
    }

    /// 이메일 필드의 플레이스홀더 뷰
    private var placeholderView: Text {
        Text(placeholder)
            .font(.callout)
    }

    /// 이메일 형식 오류 메시지
    private var erroMsg: some View {
        Text(customErrorMessage ?? Constants.errorMsg)
            .appFont(.footnote, color: .red)
            .padding(.leading, Constants.errorPadding)
    }

    /// 인증번호 재전송 버튼
    ///
    /// 60초 throttle 동안 비활성화되며 남은 시간을 표시합니다.
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
            .disabled(resendCooldownSeconds > 0 || verificationState == .verifying)
        }
        .padding(.horizontal, Constants.errorPadding)
    }

    /// 인증번호 입력 필드
    ///
    /// 6자리 숫자 입력을 받으며, OTP 자동 완성을 지원합니다.
    /// 입력 글자 수가 6자를 초과하면 자동으로 잘립니다.
    private var verificationCodeField: some View {
        TextField("", text: $verificationCode, prompt: Text("인증번호 6자리"))
            .foregroundStyle(.grey900)
            .padding(DefaultConstant.defaultTextFieldPadding)
            .glassEffect(.regular, in: .capsule)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode) // OTP 자동 완성 지원
            .onChange(of: verificationCode) { _, newValue in
                if newValue.count > Constants.verificationCount {
                    verificationCode = String(newValue.prefix(Constants.verificationCount))
                }
            }
            .transition(.asymmetric(
                insertion: .scale(scale: 0.95).combined(with: .opacity),
                removal: .scale(scale: 0.95).combined(with: .opacity)
            ))
    }

    /// 인증 완료 성공 메시지
    ///
    /// 체크마크 아이콘과 함께 "인증되었습니다" 메시지를 표시합니다.
    private var successMessage: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Image(systemName: Constants.successImage)
                .foregroundStyle(.green)
            Text(Constants.successMsg)
                .appFont(.footnote, color: .green)
        }
        .padding(.leading, Constants.errorPadding)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        ))
    }
}

#Preview {
    @Previewable @State var text: String = ""
    FormEmailField(
        title: "이메일",
        placeholder: "example@example.com",
        text: $text,
        onVerificationRequested: {
            try await Task.sleep(for: .seconds(2))
            print("Verification requested")
        },
        onVerificationComplete: { code in
            try await Task.sleep(for: .seconds(2))
            print("Verification complete: \(code)")
        },
        isRequired: true
    )
}

// MARK: - Method

extension FormEmailField {

    /// 인증 버튼 탭 핸들러
    ///
    /// 현재 상태에 따라 다른 동작을 수행합니다:
    /// - **initial**: 이메일 형식 검증 → 인증번호 요청 API 호출 → codeRequested 상태로 전환
    /// - **codeRequested**: 인증번호 검증 API 호출 → verified 상태로 전환
    /// - **verified**: 이미 완료된 상태로 아무 동작 없음
    ///
    /// 에러 발생 시 showError를 true로 설정하고 상태를 초기화합니다.
    private func handleButtonTap() {
        // 이메일 형식 유효성 검증
        if !isValidEmail {
            customErrorMessage = nil
            showError = true
            return
        }

        showError = false
        customErrorMessage = nil

        switch verificationState {
        case .initial, .failed:
            // 1단계: 인증번호 요청
            Task {
                do {
                    verificationCode = ""
                    verificationState = .verifying
                    try await onVerificationRequested()
                    resendCooldownSeconds = Constants.resendCooldown
                    verificationState = .codeRequested
                } catch {
                    customErrorMessage = userMessage(for: error)
                    showError = true
                    verificationState = .initial
                }
            }

        case .codeRequested:
            // 2단계: 인증번호 검증
            guard !verificationCode.isEmpty else { return }
            Task {
                do {
                    verificationState = .verifying
                    try await onVerificationComplete(verificationCode)
                    verificationState = .verified
                } catch {
                    customErrorMessage = userMessage(for: error)
                    verificationState = .failed
                    showError = true
                }
            }
        case .verified:
            // 이미 인증 완료
            break
        case .verifying:
            // 처리 중
            break
        }
    }

    /// 재전송 버튼 탭 핸들러
    ///
    /// 60초 카운트다운이 끝났을 때 호출되며, 성공 시 카운트다운을 재시작합니다.
    private func handleResendTap() {
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

    /// 에러 → 사용자 표시 문구
    private func userMessage(for error: Error) -> String {
        if let appError = error as? AppError {
            return appError.userMessage
        }
        if let authError = error as? AuthError {
            return authError.userMessage
        }
        return Constants.errorMsg
    }

    /// 이메일 변경 시 인증 상태를 초기화합니다.
    ///
    /// 인증 요청 이후 이메일이 수정되면 이전 인증번호/성공 상태는 더 이상 유효하지 않으므로
    /// 초기 상태로 되돌려 재인증을 유도합니다.
    private func resetVerificationStateForEmailChange() {
        guard verificationState != .initial else { return }
        verificationCode = ""
        verificationState = .initial
        resendCooldownSeconds = 0
        customErrorMessage = nil
    }
}
