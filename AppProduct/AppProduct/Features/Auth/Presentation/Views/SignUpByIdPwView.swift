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
/// `appFlow.showPendingApproval()`로 전환합니다.
struct SignUpByIdPwView: View {

    // MARK: - Property

    @State private var viewModel: SignUpByIdPwViewModel
    @State private var lastEmailSnapshot: String = ""
    @State private var alertPrompt: AlertPrompt?
    @FocusState private var focusedField: Field?

    @Environment(\.appFlow) private var appFlow
    @Environment(\.di) private var di
    @Environment(\.openURL) private var openURL
    @Environment(ErrorHandler.self) private var errorHandler

    private let fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol

    // MARK: - Field

    private enum Field: Hashable, CaseIterable {
        case loginId
        case password
        case passwordConfirm
        case name
        case nickname
    }

    // MARK: - Constant

    private enum Constants {
        static let naviSubTitle: String = "동아리 활동을 위해 정보를 입력해주세요."
        static let spacerSize: CGFloat = 30
        static let termsTitle: String = "약관 동의"
        static let allAgreeTitle: String = "전체 동의"
        static let termsLoadFailedMessage: String = "약관 정보를 불러오지 못했습니다."
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
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: Constants.spacerSize) {
                    emailSection
                    loginIdSection
                    passwordSection
                    nameNicknameSection
                    schoolSection
                    termsSection
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
    }
}

// MARK: - Sections

private extension SignUpByIdPwView {

    var emailSection: some View {
        FormEmailField(
            title: "이메일",
            placeholder: "example@example.com",
            text: $viewModel.emailInput,
            onVerificationRequested: {
                try await viewModel.requestEmailVerification()
            },
            onVerificationComplete: { code in
                try await viewModel.verifyEmailCode(code)
            },
            submitLabel: .next,
            onSubmit: {
                focusedField = .loginId
            },
            onEmailChanged: {
                if lastEmailSnapshot != viewModel.emailInput {
                    Task { @MainActor in
                        viewModel.resetEmailVerification()
                        lastEmailSnapshot = viewModel.emailInput
                    }
                }
            }
        )
    }

    var loginIdSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            TitleLabel(title: "로그인 ID", isRequired: true)
            HStack(spacing: DefaultSpacing.spacing8) {
                TextField(
                    "",
                    text: $viewModel.loginIdInput,
                    prompt: Text("아이디 입력").font(.callout)
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .foregroundStyle(.grey900)
                .padding(DefaultConstant.defaultTextFieldPadding)
                .glassEffect(.regular, in: .capsule)
                .submitLabel(.next)
                .focused($focusedField, equals: .loginId)
                .onSubmit { focusedField = .password }

                loginIdStatusIndicator
            }
            loginIdStatusMessage
        }
    }

    @ViewBuilder
    var loginIdStatusIndicator: some View {
        switch viewModel.loginIdAvailability {
        case .loading:
            ProgressView()
                .frame(width: 24, height: 24)
        case .loaded(true):
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .loaded(false), .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red500)
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    var loginIdStatusMessage: some View {
        switch viewModel.loginIdAvailability {
        case .loaded(true):
            Text("사용 가능한 아이디입니다.")
                .appFont(.footnote, color: .green)
                .padding(.leading, DefaultSpacing.spacing8)
        case .loaded(false):
            Text("이미 사용 중인 아이디입니다.")
                .appFont(.footnote, color: .red500)
                .padding(.leading, DefaultSpacing.spacing8)
        case .failed(let error):
            Text(error.userMessage)
                .appFont(.footnote, color: .red500)
                .padding(.leading, DefaultSpacing.spacing8)
        case .idle, .loading:
            EmptyView()
        }
    }

    var passwordSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
                TitleLabel(title: "비밀번호", isRequired: true)
                SecureField(
                    "",
                    text: $viewModel.passwordInput,
                    prompt: Text("8자 이상 입력").font(.callout)
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .foregroundStyle(.grey900)
                .padding(DefaultConstant.defaultTextFieldPadding)
                .glassEffect(.regular, in: .capsule)
                .submitLabel(.next)
                .focused($focusedField, equals: .password)
                .onSubmit { focusedField = .passwordConfirm }

                if !viewModel.passwordInput.isEmpty,
                   !viewModel.isPasswordValid {
                    Text("8자 이상 입력해 주세요.")
                        .appFont(.footnote, color: .red500)
                        .padding(.leading, DefaultSpacing.spacing8)
                }
            }

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
                TitleLabel(title: "비밀번호 확인", isRequired: true)
                SecureField(
                    "",
                    text: $viewModel.passwordConfirmInput,
                    prompt: Text("비밀번호 다시 입력").font(.callout)
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .foregroundStyle(.grey900)
                .padding(DefaultConstant.defaultTextFieldPadding)
                .glassEffect(.regular, in: .capsule)
                .submitLabel(.next)
                .focused($focusedField, equals: .passwordConfirm)
                .onSubmit { focusedField = .name }

                if !viewModel.passwordConfirmInput.isEmpty,
                   !viewModel.isPasswordConfirmed {
                    Text("비밀번호가 일치하지 않습니다.")
                        .appFont(.footnote, color: .red500)
                        .padding(.leading, DefaultSpacing.spacing8)
                }
            }
        }
    }

    var nameNicknameSection: some View {
        HStack(alignment: .top, spacing: DefaultSpacing.spacing12) {
            FormTextField(
                title: "이름",
                placeholder: "이름 입력",
                text: $viewModel.nameInput,
                isRequired: true,
                submitLabel: .next,
                onSubmit: { focusedField = .nickname }
            )
            .focused($focusedField, equals: .name)

            FormTextField(
                title: "닉네임",
                placeholder: "한글 1~5자",
                text: $viewModel.nicknameInput,
                isRequired: true,
                submitLabel: .done,
                onSubmit: { focusedField = nil }
            )
            .focused($focusedField, equals: .nickname)
        }
    }

    @ViewBuilder
    var schoolSection: some View {
        switch viewModel.schoolsState {
        case .idle, .loading:
            FormPickerField(
                title: "학교",
                placeholder: "학교를 선택하세요",
                selection: .constant(nil as String?),
                options: [String](),
                displayText: { $0 }
            )
        case .loaded(let schools):
            FormPickerField(
                title: "학교",
                placeholder: "학교를 선택하세요",
                selection: $viewModel.selectedSchool,
                options: schools,
                displayText: { $0.name }
            )
        case .failed:
            FormPickerField(
                title: "학교",
                placeholder: "학교 목록을 불러올 수 없습니다",
                selection: .constant(nil as String?),
                options: [String](),
                displayText: { $0 }
            )
        }
    }

    var termsSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            TitleLabel(title: Constants.termsTitle, isRequired: true)

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
                allAgreeButton
                Divider()
                termsContent
            }
            .padding()
            .glassEffect(
                .regular,
                in: .rect(cornerRadius: DefaultConstant.cornerRadius)
            )
        }
    }

    var allAgreeButton: some View {
        Button(action: {
            viewModel.toggleAllTerms(!viewModel.isAllTermsAgreed)
        }) {
            HStack(spacing: DefaultSpacing.spacing8) {
                Image(
                    systemName: viewModel.isAllTermsAgreed
                    ? "checkmark.circle.fill" : "circle"
                )
                .foregroundStyle(
                    viewModel.isAllTermsAgreed ? .indigo500 : .grey400
                )
                Text(Constants.allAgreeTitle)
                    .appFont(.calloutEmphasis)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    var termsContent: some View {
        switch viewModel.termsState {
        case .idle, .loading:
            ProgressView()
        case .failed:
            Text(Constants.termsLoadFailedMessage)
                .appFont(.footnote, color: .grey500)
        case .loaded:
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
                ForEach(termRows) { row in
                    termsRow(row)
                }
            }
        }
    }

    func termsRow(_ row: SignUpByIdPwTermRow) -> some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Button(action: {
                viewModel.termsAgreements[row.id]?.toggle()
            }) {
                HStack(spacing: DefaultSpacing.spacing8) {
                    Image(
                        systemName: row.isAgreed
                        ? "checkmark.circle.fill" : "circle"
                    )
                    .foregroundStyle(row.isAgreed ? .indigo500 : .grey400)
                    Text(row.title)
                        .appFont(.subheadline)
                    Text(row.isMandatory ? "(필수)" : "(선택)")
                        .appFont(
                            .footnote,
                            color: row.isMandatory ? .red500 : .grey400
                        )
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button("보기", action: { openTerms(row.termsType) })
                .appFont(.footnote, color: .indigo500)
                .buttonStyle(.plain)
        }
    }

    var submitButton: some View {
        MainButton(Constants.signUpButtonTitle, action: {
            focusedField = nil
            signUpCompleted()
        })
        .loading($viewModel.isLoading)
        .disabled(!viewModel.canSubmit)
        .buttonStyle(.glassProminent)
        .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }

    var termRows: [SignUpByIdPwTermRow] {
        guard case .loaded(let terms) = viewModel.termsState else { return [] }
        return terms
            .filter { $0.termsType == .service || $0.termsType == .privacy }
            .sorted { $0.termsType.signUpByIdPwOrder < $1.termsType.signUpByIdPwOrder }
            .map {
                SignUpByIdPwTermRow(
                    id: $0.id,
                    title: $0.termsType.signUpByIdPwTitle,
                    isMandatory: $0.isMandatory,
                    isAgreed: viewModel.termsAgreements[$0.id] == true,
                    termsType: $0.termsType
                )
            }
    }
}

// MARK: - Actions

private extension SignUpByIdPwView {

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

    func checkApprovalStatus() async -> Bool {
        do {
            let profile = try await fetchMyProfileUseCase.execute()
            return isApprovedProfile(profile)
        } catch {
            return false
        }
    }

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

// MARK: - Models

private struct SignUpByIdPwTermRow: Identifiable {
    let id: String
    let title: String
    let isMandatory: Bool
    let isAgreed: Bool
    let termsType: TermsType
}

// MARK: - TermsType Display

private extension TermsType {
    var signUpByIdPwTitle: String {
        switch self {
        case .service: return "서비스 이용 약관"
        case .privacy: return "개인정보처리 방침"
        case .marketing: return "마케팅 정보 수신 동의"
        }
    }

    var signUpByIdPwOrder: Int {
        switch self {
        case .service: return 0
        case .privacy: return 1
        case .marketing: return 2
        }
    }

    var signUpByIdPwApiType: String {
        switch self {
        case .service: return LawsType.terms.apiType
        case .privacy: return LawsType.policy.apiType
        case .marketing: return rawValue
        }
    }
}
