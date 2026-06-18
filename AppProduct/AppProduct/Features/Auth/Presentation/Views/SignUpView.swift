//
//  SignUpView.swift
//  AppProduct
//
//  Created by euijjang97 on 1/12/26.
//

import SwiftUI

/// 회원가입 정보 입력 화면
///
/// 사용자의 이름, 닉네임, 이메일, 학교 정보를 입력받고
/// 이메일 인증 프로세스와 약관 동의를 처리합니다.
struct SignUpView: View {

    // MARK: - Property

    /// 회원가입 뷰 모델 (@Observable 패턴)
    @State private var viewModel: SignUpViewModel

    /// 현재 포커스된 입력 필드
    @FocusState private var focusedField: SignUpFieldType?
    @State private var lastEmailSnapshot: String = ""
    @State private var alertPrompt: AlertPrompt?
    @Environment(\.appFlow) private var appFlow
    @Environment(\.di) private var di
    @Environment(\.openURL) private var openURL
    @Environment(ErrorHandler.self) private var errorHandler

    // MARK: - Constant

    /// 레이아웃 및 텍스트 상수
    private enum Constants {
        /// 네비게이션 서브타이틀
        static let naviSubTitle: String = "동아리 활동을 위해 정보를 입력해주세요."
        /// 필드 간 수직 간격
        static let spacerSize: CGFloat = 30
        /// 약관 섹션 타이틀
        static let termsTitle: String = "약관 동의"
        /// 전체 동의 문구
        static let allAgreeTitle: String = "전체 동의"
        /// 약관 로드 실패 문구
        static let termsLoadFailedMessage: String = "약관 정보를 불러오지 못했습니다."
    }

    // MARK: - Init

    init(
        oAuthVerificationToken: String,
        initialEmail: String? = nil,
        initialName: String? = nil,
        postRegisterLoginContext: PostRegisterLoginContext? = nil,
        sendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol,
        verifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol,
        registerUseCase: RegisterUseCaseProtocol,
        loginUseCase: LoginUseCaseProtocol,
        fetchSignUpDataUseCase: FetchSignUpDataUseCaseProtocol
    ) {
        self._viewModel = .init(
            wrappedValue: SignUpViewModel(
                oAuthVerificationToken: oAuthVerificationToken,
                initialEmail: initialEmail,
                initialName: initialName,
                postRegisterLoginContext: postRegisterLoginContext,
                sendEmailVerificationUseCase: sendEmailVerificationUseCase,
                verifyEmailCodeUseCase: verifyEmailCodeUseCase,
                registerUseCase: registerUseCase,
                loginUseCase: loginUseCase,
                fetchSignUpDataUseCase: fetchSignUpDataUseCase
            )
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: Constants.spacerSize) {
                    HStack {
                        buildField(.name)
                        buildField(.nickname)
                    }
                    buildField(.email)
                    buildField(.univ)
                    termsSection
                }
                .safeAreaPadding(.vertical, DefaultConstant.defaultContentTopMargins)
                .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
                .navigation(naviTitle: .signUp, displayMode: .large)
                .navigationSubtitle(Constants.naviSubTitle)
            }
            .alertPrompt(item: $alertPrompt)
            .safeAreaInset(edge: .bottom, content: {
                mainBtn
            })
            .task {
                await viewModel.fetchSchools()
                await viewModel.fetchTerms()
                lastEmailSnapshot = viewModel.email
            }
            .onChange(of: viewModel.registerState) { _, newState in
                if case .loaded = newState {
                    UserDefaults.standard.set(
                        false,
                        forKey: AppStorageKey.canAutoLogin
                    )
                    appFlow.showPendingApproval()
                    return
                }

                if case .failed(let error) = newState {
                    handleRegisterFailure(error)
                }
            }
        }
    }

    /// 필드 타입에 따른 입력 컴포넌트 생성
    ///
    /// - Parameter field: 생성할 필드 타입 (이름, 닉네임, 이메일, 학교)
    /// - Returns: 해당 타입에 맞는 Form 컴포넌트
    @ViewBuilder
    private func buildField(_ field: SignUpFieldType) -> some View {
        switch field.type {
        case .text:
            // 일반 텍스트 필드 (이름, 닉네임)
            FormTextField(
                title: field.title,
                placeholder: field.placeholder,
                text: binding(field),
                isRequired: field.isRequired,
                submitLabel: .next,
                onSubmit: {
                    moveToNextField(from: field)
                }
            )
            .focused($focusedField, equals: field)
        case .email:
            // 이메일 인증 필드
            FormEmailField(
                title: field.title,
                placeholder: field.placeholder,
                text: binding(field),
                onVerificationRequested: {
                    try await viewModel.requestEmailVerification()
                },
                onVerificationComplete: { code in
                    try await viewModel.verifyEmailCode(code)
                },
                submitLabel: .return,
                onSubmit: {
                    focusedField = nil
                },
                onEmailChanged: {
                    if lastEmailSnapshot != viewModel.email {
                        Task { @MainActor in
                            viewModel.resetEmailVerification()
                            lastEmailSnapshot = viewModel.email
                        }
                    }
                }
            )
            .focused($focusedField, equals: field)
        case .picker:
            schoolPicker
        }
    }

    /// 학교 선택 피커 (API에서 가져온 학교 목록)
    private var schoolPicker: some View {
        Group {
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
    }

    /// 약관 동의 섹션
    private var termsSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            TitleLabel(title: Constants.termsTitle, isRequired: true)

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
                allAgreeButton
                Divider()
                termsSectionContent
            }
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: DefaultConstant.cornerRadius))
        }
    }

    private var allAgreeButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.toggleAllTerms(!viewModel.isAllTermsAgreed)
            }
        }) {
            HStack(spacing: DefaultSpacing.spacing8) {
                Image(
                    systemName: viewModel.isAllTermsAgreed
                    ? "checkmark.circle.fill" : "circle"
                )
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(viewModel.isAllTermsAgreed ? .indigo500 : .grey400)
                Text(Constants.allAgreeTitle)
                    .appFont(.calloutEmphasis)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var termsSectionContent: some View {
        switch viewModel.termsState {
        case .idle, .loading:
            ProgressView()
        case .failed:
            Text(Constants.termsLoadFailedMessage)
                .appFont(.footnote, color: .grey500)
        case .loaded:
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
                ForEach(requiredTermRows) { row in
                    SignUpTermsRow(
                        title: row.title,
                        isMandatory: row.isMandatory,
                        isAgreed: row.isAgreed,
                        showsDetailButton: true,
                        onToggle: {
                            viewModel.termsAgreements[row.id]?.toggle()
                        },
                        onTapDetail: {
                            openTerms(row.termsType)
                        }
                    )
                }
            }
        }
    }

    /// 하단 완료 버튼
    private var mainBtn: some View {
        MainButton("완료", action: {
            signUpCompleted()
        })
        .loading($viewModel.isLoading)
        .disabled(!viewModel.isFormValid)
        .buttonStyle(.glassProminent)
        .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }

    private var requiredTermRows: [SignUpTermRowModel] {
        guard case .loaded(let terms) = viewModel.termsState else {
            return []
        }

        return terms
            .filter { $0.termsType == .service || $0.termsType == .privacy }
            .sorted { $0.termsType.displayOrder < $1.termsType.displayOrder }
            .map {
                SignUpTermRowModel(
                    id: $0.id,
                    title: $0.termsType.displayTitle,
                    isMandatory: $0.isMandatory,
                    isAgreed: viewModel.termsAgreements[$0.id] == true,
                    termsType: $0.termsType
                )
            }
    }

    /// 약관 상세 링크를 외부 브라우저로 엽니다.
    ///
    /// - Parameter termsType: 열람할 약관 종류
    private func openTerms(_ termsType: TermsType) {
        Task {
            do {
                let provider = di.resolve(MyPageUseCaseProviding.self)
                let termsLink = try await provider.fetchTermsUseCase.execute(
                    termsType: termsType.apiType
                )
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

// MARK: - TermsType Display

private extension TermsType {
    var displayTitle: String {
        switch self {
        case .service:
            return "서비스 이용 약관"
        case .privacy:
            return "개인정보처리 방침"
        case .marketing:
            return "마케팅 정보 수신 동의"
        }
    }

    var displayOrder: Int {
        switch self {
        case .service:
            return 0
        case .privacy:
            return 1
        case .marketing:
            return 2
        }
    }

    var apiType: String {
        switch self {
        case .service:
            return LawsType.terms.apiType
        case .privacy:
            return LawsType.policy.apiType
        case .marketing:
            return rawValue
        }
    }
}

// MARK: - Models

/// 약관 Row 표시를 위한 뷰 모델
private struct SignUpTermRowModel: Identifiable {
    let id: String
    let title: String
    let isMandatory: Bool
    let isAgreed: Bool
    let termsType: TermsType
}

/// 약관 동의 체크박스 Row 컴포넌트
private struct SignUpTermsRow: View {
    let title: String
    let isMandatory: Bool
    let isAgreed: Bool
    let showsDetailButton: Bool
    let onToggle: () -> Void
    let onTapDetail: () -> Void

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onToggle()
                }
            }) {
                HStack(spacing: DefaultSpacing.spacing8) {
                    Image(systemName: isAgreed ? "checkmark.circle.fill" : "circle")
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(isAgreed ? .indigo500 : .grey400)
                    Text(title)
                        .appFont(.subheadline)
                    Text(isMandatory ? "(필수)" : "(선택)")
                        .appFont(
                            .footnote,
                            color: isMandatory ? .red500 : .grey400
                        )
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            if showsDetailButton {
                Button("보기", action: onTapDetail)
                    .appFont(.footnote, color: .indigo500)
                    .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Method

extension SignUpView {

    /// 필드에 해당하는 ViewModel 바인딩 반환
    ///
    /// - Parameter field: 바인딩할 필드 타입
    /// - Returns: 해당 필드의 String 바인딩
    private func binding(_ field: SignUpFieldType) -> Binding<String> {
        switch field {
        case .name:
            return $viewModel.name
        case .nickname:
            return $viewModel.nickname
        case .email:
            return $viewModel.email
        case .univ:
            return .constant("")
        }
    }

    /// 다음 입력 필드로 포커스 이동
    ///
    /// 현재 필드에서 다음 필드로 자동으로 포커스를 전환합니다.
    /// 마지막 필드인 경우 포커스를 해제합니다.
    ///
    /// - Parameter field: 현재 포커스된 필드
    private func moveToNextField(from field: SignUpFieldType) {
        let allCases = SignUpFieldType.allCases
        guard let currentIndex = allCases.firstIndex(of: field),
              currentIndex < allCases.count - 1 else {
            focusedField = nil
            return
        }
        focusedField = allCases[currentIndex + 1]
    }

    /// 회원가입 완료 처리
    ///
    /// 시스템 권한 요청 프로세스를 시작합니다.
    /// - 알림 권한
    /// - 위치 권한 (GPS 출석 기능)
    /// - 사진 권한 (프로필 이미지 업로드)
    private func signUpCompleted() {
        Task {
            // 권한 요청
            let results = await viewModel.requestPermission(
                notification: true,
                location: true,
                photo: true
            )

            #if DEBUG
            print("권한 요청: \(results)")
            #endif

            // 회원가입 API 호출
            await viewModel.register()
        }
    }

    @MainActor
    private func handleRegisterFailure(_ error: AppError) {
        if error.isOAuthVerificationExpired {
            alertPrompt = AlertPrompt(
                title: "인증이 만료되었어요",
                message: "회원가입을 계속하려면 다시 로그인해주세요.",
                positiveBtnTitle: "로그인으로 이동",
                positiveBtnAction: {
                    appFlow.showLogin()
                },
                negativeBtnTitle: "닫기"
            )
            return
        }

        if error.isSocialConnectionConflict {
            alertPrompt = AlertPrompt(
                title: "소셜 계정을 확인해주세요",
                message: error.userMessage,
                positiveBtnTitle: "확인"
            )
            return
        }

        errorHandler.handle(
            error,
            context: .init(
                feature: "Auth",
                action: "register",
                retryAction: {
                    await viewModel.register()
                }
            )
        )
    }
}

// MARK: - Register Error

private extension AppError {
    var isSocialConnectionConflict: Bool {
        switch self {
        case .repository(let error):
            let message = error.userMessage
            return message.contains("이미 다른 소셜") ||
                message.contains("이미 연동")
        case .auth(let error):
            return error.userMessage.contains("이미 연동")
        default:
            return false
        }
    }

    var isOAuthVerificationExpired: Bool {
        switch self {
        case .repository(let error):
            guard case .serverError(let code, let message) = error else {
                return false
            }
            if code == "SECURITY-0001" {
                return true
            }
            return message?.contains("만료된 JWT 토큰") == true
        case .network(.requestFailed(let statusCode, _)):
            return statusCode == 401
        default:
            return false
        }
    }
}

// MARK: - Preview

#Preview("회원가입 기본") {
    signUpPreview()
}

#Preview("회원가입 약관 로드 실패") {
    signUpPreview(shouldFailTerms: true)
}

private func signUpPreview(shouldFailTerms: Bool = false) -> some View {
    NavigationStack {
        SignUpView(
            oAuthVerificationToken: "preview_token",
            sendEmailVerificationUseCase: SignUpPreviewSendEmailUseCase(),
            verifyEmailCodeUseCase: SignUpPreviewVerifyCodeUseCase(),
            registerUseCase: SignUpPreviewRegisterUseCase(),
            loginUseCase: SignUpPreviewLoginUseCase(),
            fetchSignUpDataUseCase: SignUpPreviewFetchSignUpDataUseCase(
                shouldFailTerms: shouldFailTerms
            )
        )
    }
    .environment(DIContainer())
    .environment(ErrorHandler())
}

private struct SignUpPreviewSendEmailUseCase: SendEmailVerificationUseCaseProtocol {
    func execute(email: String, purpose: EmailVerificationPurpose) async throws -> String {
        "preview_verification_id"
    }
}

private struct SignUpPreviewVerifyCodeUseCase: VerifyEmailCodeUseCaseProtocol {
    func execute(
        emailVerificationId: String,
        verificationCode: String
    ) async throws -> String {
        "preview_email_token"
    }
}

private struct SignUpPreviewRegisterUseCase: RegisterUseCaseProtocol {
    func execute(request: RegisterRequestDTO) async throws -> String {
        "1"
    }
}

private struct SignUpPreviewLoginUseCase: LoginUseCaseProtocol {
    func executeKakao(
        accessToken: String,
        email: String
    ) async throws -> OAuthLoginResult {
        .existingMember(
            tokenPair: TokenPair(
                accessToken: "preview_access_token",
                refreshToken: "preview_refresh_token"
            )
        )
    }

    func executeApple(
        authorizationCode: String,
        email: String?,
        fullName: String?
    ) async throws -> OAuthLoginResult {
        .existingMember(
            tokenPair: TokenPair(
                accessToken: "preview_access_token",
                refreshToken: "preview_refresh_token"
            )
        )
    }

    func executeGoogle(accessToken: String) async throws -> OAuthLoginResult {
        .existingMember(
            tokenPair: TokenPair(
                accessToken: "preview_access_token",
                refreshToken: "preview_refresh_token"
            )
        )
    }
}

private struct SignUpPreviewFetchSignUpDataUseCase: FetchSignUpDataUseCaseProtocol {
    let shouldFailTerms: Bool

    init(shouldFailTerms: Bool = false) {
        self.shouldFailTerms = shouldFailTerms
    }

    func fetchSchools() async throws -> [School] {
        [
            School(id: "1", name: "중앙대학교"),
            School(id: "2", name: "서울대학교")
        ]
    }

    func fetchTerms(termsType: String) async throws -> Terms {
        if shouldFailTerms {
            throw AppError.unknown(message: "약관 로딩 실패")
        }
        let type = TermsType(rawValue: termsType) ?? .service
        return Terms(
            id: type == .service ? "2" : "1",
            link: "https://makeus-challenge.notion.site/300b57f4596b803f8c94dd4f4fb71960?source=copy_link",
            isMandatory: true,
            termsType: type
        )
    }
}
