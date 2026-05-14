//
//  SignUpByIdPwView.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import SwiftUI

/// ID/PW 회원가입 화면 (단일 ScrollView)
///
/// 이메일 인증, 로그인 ID, 비밀번호, 이름/닉네임, 학교, 약관 동의를 한 화면에서 입력받고
/// 모든 검증이 통과하면 가입 버튼이 활성화됩니다. 가입 성공 시 서버가 토큰을 즉시 발급하여
/// `appFlow.showPendingApproval()` 또는 `showMain()`으로 전환합니다.
///
/// ## 구조
/// 본 화면은 ViewModel 상태를 6개 섹션 컴포넌트(`Components/SignUp*Section.swift`)에
/// 분배하고, 가입 완료/실패와 약관 링크 등 상태 변화 액션만 처리합니다. UI 세부 구현은 모두
/// 섹션 컴포넌트가 담당합니다.
struct SignUpByIdPwView: View {

    // MARK: - Property

    @State private var viewModel: SignUpByIdPwViewModel
    /// 이메일 변경 감지용 스냅샷 — 값이 바뀌면 인증 상태를 리셋합니다.
    @State private var lastEmailSnapshot: String = ""
    @State private var alertPrompt: AlertPrompt?
    @FocusState private var focusedField: SignUpByIdPwField?

    @Environment(\.appFlow) private var appFlow
    @Environment(\.di) private var di
    @Environment(\.openURL) private var openURL
    @Environment(ErrorHandler.self) private var errorHandler

    /// 가입 완료 후 가입 승인 여부를 확인하기 위해 사용합니다.
    private let fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol

    // MARK: - Constant

    private enum Constants {
        static let naviSubTitle: String = "동아리 활동을 위해 정보를 입력해주세요."
        static let spacerSize: CGFloat = 30
        static let signUpButtonTitle: String = "가입 완료"
    }

    // MARK: - Init

    init(
        sendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol,
        verifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol,
        registerByIdPwUseCase: RegisterByIdPwUseCaseProtocol,
        checkLoginIdAvailabilityUseCase: CheckLoginIdAvailabilityUseCaseProtocol,
        fetchSignUpDataUseCase: FetchSignUpDataUseCaseProtocol,
        fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol
    ) {
        self._viewModel = .init(
            wrappedValue: SignUpByIdPwViewModel(
                sendEmailVerificationUseCase: sendEmailVerificationUseCase,
                verifyEmailCodeUseCase: verifyEmailCodeUseCase,
                registerByIdPwUseCase: registerByIdPwUseCase,
                checkLoginIdAvailabilityUseCase: checkLoginIdAvailabilityUseCase,
                fetchSignUpDataUseCase: fetchSignUpDataUseCase
            )
        )
        self.fetchMyProfileUseCase = fetchMyProfileUseCase
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: Constants.spacerSize) {
                SignUpEmailSection(
                    email: $viewModel.emailInput,
                    onVerificationRequested: {
                        try await viewModel.requestEmailVerification()
                    },
                    onVerificationComplete: { code in
                        try await viewModel.verifyEmailCode(code)
                    },
                    onEmailChanged: handleEmailChange,
                    onSubmit: { focusedField = .loginId }
                )

                SignUpLoginIdSection(
                    loginId: $viewModel.loginIdInput,
                    availability: viewModel.loginIdAvailability,
                    focusBinding: $focusedField,
                    onSubmit: { focusedField = .password }
                )

                SignUpPasswordSection(
                    password: $viewModel.passwordInput,
                    passwordConfirm: $viewModel.passwordConfirmInput,
                    isPasswordValid: viewModel.isPasswordValid,
                    isPasswordConfirmed: viewModel.isPasswordConfirmed,
                    focusBinding: $focusedField,
                    onConfirmSubmit: { focusedField = .name }
                )

                SignUpNameNicknameSection(
                    name: $viewModel.nameInput,
                    nickname: $viewModel.nicknameInput,
                    focusBinding: $focusedField,
                    onNicknameSubmit: { focusedField = nil }
                )

                SignUpSchoolSection(
                    schoolsState: viewModel.schoolsState,
                    selectedSchool: $viewModel.selectedSchool
                )

                SignUpTermsSection(
                    termsState: viewModel.termsState,
                    termsAgreements: viewModel.termsAgreements,
                    isAllTermsAgreed: viewModel.isAllTermsAgreed,
                    onToggleAll: { isAgreed in
                        viewModel.toggleAllTerms(isAgreed)
                    },
                    onToggleRow: { id in
                        viewModel.termsAgreements[id]?.toggle()
                    },
                    onOpenTerms: openTerms
                )
            }
            .safeAreaPadding(
                .vertical,
                DefaultConstant.defaultContentTopMargins
            )
            .safeAreaPadding(
                .horizontal,
                DefaultConstant.defaultSafeHorizon
            )
            .navigation(naviTitle: .signUp, displayMode: .large)
            .navigationSubtitle(Constants.naviSubTitle)
        }
        .keyboardToolbar(focusedField: $focusedField)
        .alertPrompt(item: $alertPrompt)
        .safeAreaInset(edge: .bottom) {
            submitButton
        }
        .task {
            await viewModel.fetchSchools()
            await viewModel.fetchTerms()
            lastEmailSnapshot = viewModel.emailInput
        }
        .onChange(of: viewModel.registerState) { _, newState in
            handleRegisterStateChange(newState)
        }
    }

    // MARK: - Subviews

    /// 화면 하단 고정 가입 완료 버튼.
    /// `viewModel.canSubmit` 이 false 면 비활성, `isLoading` 이면 스피너 표시.
    private var submitButton: some View {
        MainButton(Constants.signUpButtonTitle, action: {
            focusedField = nil
            signUpCompleted()
        })
        .loading($viewModel.isLoading)
        .disabled(!viewModel.canSubmit)
        .buttonStyle(.glassProminent)
        .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }
}

// MARK: - Actions

private extension SignUpByIdPwView {

    /// 이메일 텍스트가 바뀌었을 때 인증 상태를 리셋합니다.
    /// `FormEmailField` 가 자체 디바운스를 적용하므로 SwiftUI `onChange` 대신
    /// 콜백 + 스냅샷 비교 방식을 사용해 불필요한 리셋을 방지합니다.
    func handleEmailChange() {
        if lastEmailSnapshot != viewModel.emailInput {
            Task { @MainActor in
                viewModel.resetEmailVerification()
                lastEmailSnapshot = viewModel.emailInput
            }
        }
    }

    /// 가입 완료 버튼 액션.
    /// 알림/위치/사진 권한을 먼저 요청한 뒤 실제 가입 API를 호출합니다.
    func signUpCompleted() {
        Task {
            let results = await viewModel.requestPermission(
                notification: true,
                location: true,
                photo: true
            )

            #if DEBUG
            print("[Auth][IdPwSignUp] 권한 요청: \(results)")
            #endif

            await viewModel.register()
        }
    }

    /// `registerState` 변화 핸들러.
    /// 성공 시 자동 로그인 비활성화 후 승인 여부에 따라 메인/대기 화면으로 이동.
    /// 실패 시 ErrorHandler로 위임.
    @MainActor
    func handleRegisterStateChange(_ newState: Loadable<RegisterByIdPwResult>) {
        switch newState {
        case .loaded:
            UserDefaults.standard.set(
                false,
                forKey: AppStorageKey.canAutoLogin
            )
            Task { @MainActor in
                let isApproved = await checkApprovalStatus()
                if isApproved {
                    appFlow.showMain()
                } else {
                    appFlow.showPendingApproval()
                }
            }
        case .failed(let error):
            handleRegisterFailure(error)
        case .idle, .loading:
            break
        }
    }

    /// 가입 직후 프로필을 조회해 정식 회원 승인 여부를 판정합니다.
    func checkApprovalStatus() async -> Bool {
        do {
            let profile = try await fetchMyProfileUseCase.execute()
            return isApprovedProfile(profile)
        } catch {
            return false
        }
    }

    /// 1기수 이상 등록되어 있으면 정식 회원으로 간주합니다.
    func isApprovedProfile(_ profile: HomeProfileResult) -> Bool {
        if !profile.generations.isEmpty { return true }
        for seasonType in profile.seasonTypes {
            if case .gens(let gens) = seasonType, !gens.isEmpty {
                return true
            }
        }
        return false
    }

    @MainActor
    func handleRegisterFailure(_ error: AppError) {
        errorHandler.handle(
            error,
            context: .init(
                feature: "Auth",
                action: "registerByIdPw",
                retryAction: { [viewModel] in
                    await viewModel.register()
                }
            )
        )
    }

    /// 약관 "보기" 버튼 액션 — 약관 원문 링크를 외부 브라우저로 엽니다.
    func openTerms(_ termsType: TermsType) {
        Task {
            do {
                let provider = di.resolve(MyPageUseCaseProviding.self)
                let apiType: String = termsType.signUpByIdPwApiType
                let termsLink = try await provider.fetchTermsUseCase
                    .execute(termsType: apiType)
                guard let url = URL(string: termsLink.link) else {
                    throw AppError.validation(
                        .invalidFormat(
                            field: "termsLink",
                            expected: "https://..."
                        )
                    )
                }
                openURL(url)
            } catch {
                errorHandler.handle(
                    error,
                    context: .init(
                        feature: "Auth",
                        action: "openTerms(\(termsType.rawValue))"
                    )
                )
            }
        }
    }
}
