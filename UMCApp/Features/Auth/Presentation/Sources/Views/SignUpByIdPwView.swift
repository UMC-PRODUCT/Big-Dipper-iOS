//
//  SignUpByIdPwView.swift
//  AuthPresentation
//
//  Created by euijjang97 on 7/9/26.
//

import AuthDomain
import CoreDesignSystem
import CoreDI
import SwiftUI
import UMCFoundation

/// 이메일(ID/PW) 신규회원 가입 화면 — 이름/닉네임/비밀번호/이메일/학교/약관을 입력받아
/// 가입을 완료한다.
///
/// Task 3에서 만들어진 섹션 컴포넌트를 조립하는 역할만 담당하며, `SignUpView`(소셜)와
/// 동일한 조립 패턴을 따르되 비밀번호 섹션과 이메일 중복 확인 표시가 추가된다.
///
/// - Note: 프로덕션 네비게이션 배선은 이 Task의 범위가 아니다(Q1). 실제 진입 경로는
///   후속 이슈에서 배선되며, 이 화면은 `#if DEBUG` 진입점(`AppRootView`)을 통해서만
///   현재 리뷰/QA 가능하다.
public struct SignUpByIdPwView: View {

    // MARK: - Property

    @State private var viewModel: SignUpByIdPwViewModel
    @State private var alertPrompt: AlertPrompt?
    @FocusState private var focusedField: SignUpFocusField?
    @Environment(\.appFlow) private var appFlow

    // MARK: - Constant

    fileprivate enum Constants {
        static let naviSubtitle: String = "동아리 활동을 위해 정보를 입력해주세요."
        static let submitTitle: String = "완료"
        static let completedTitle: String = "가입이 완료됐어요"
        static let pendingApprovalMessage: String =
            "운영진 승인 후 서비스를 이용할 수 있어요. 잠시만 기다려주세요."
        static let confirmTitle: String = "확인"
        static let emailAvailabilityTitle: String = "이메일 중복 확인"
        static let emailAvailableMessage: String = "사용 가능한 이메일이에요."
        static let emailUnavailableMessage: String = "이미 가입된 이메일이에요."
        static let emailAvailabilityFailedMessage: String = "중복 확인에 실패했어요."
        static let emailAvailabilityRetryTitle: String = "재시도"
    }

    // MARK: - Init

    public init(container: DIContainer, errorHandler: ErrorHandler) {
        _viewModel = State(initialValue: SignUpByIdPwViewModel(
            container: container,
            errorHandler: errorHandler
        ))
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DefaultSpacing.spacing24) {
                    SignUpNameNicknameSection(
                        name: $viewModel.name,
                        nickname: $viewModel.nickname,
                        focusBinding: $focusedField,
                        onNicknameSubmit: { focusedField = .password }
                    )

                    SignUpPasswordSection(
                        password: $viewModel.password,
                        passwordConfirm: $viewModel.passwordConfirm,
                        isPasswordValid: viewModel.isPasswordValid,
                        isPasswordConfirmed: viewModel.isPasswordConfirmed,
                        focusBinding: $focusedField,
                        onConfirmSubmit: { focusedField = nil }
                    )

                    VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
                        SignUpEmailSection(
                            email: $viewModel.emailVerificationFlow.email,
                            isVerified: $viewModel.emailVerificationFlow.isEmailVerified,
                            onVerificationRequested: {
                                try await viewModel.emailVerificationFlow
                                    .requestEmailVerification()
                            },
                            onVerificationComplete: { code in
                                try await viewModel.verifyEmailCode(code)
                            },
                            onResend: {
                                try await viewModel.emailVerificationFlow.resendEmailVerification()
                            },
                            onEmailChanged: {
                                viewModel.emailVerificationFlow.handleEmailChanged()
                            },
                            showsVerifiedMessage: false
                        )

                        if viewModel.emailVerificationFlow.isEmailVerified {
                            emailAvailabilityStatusRow
                        }
                    }

                    SignUpSchoolSection(
                        schoolsState: viewModel.schoolsState,
                        selectedSchool: $viewModel.selectedSchool
                    )

                    SignUpTermsSection(
                        termsState: viewModel.termsAgreementFlow.termsState,
                        termsAgreements: viewModel.termsAgreementFlow.termsAgreements,
                        isAllTermsAgreed: viewModel.termsAgreementFlow.isAllTermsAgreed,
                        onToggleAll: { viewModel.termsAgreementFlow.toggleAllTerms($0) },
                        onToggleRow: { viewModel.termsAgreementFlow.toggleTerm($0) }
                    )
                }
                .safeAreaPadding(.vertical, DefaultConstant.defaultContentTopMargins)
                .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
            }
            .navigation(naviTitle: .signUp, displayMode: .large)
            .navigationSubtitle(Constants.naviSubtitle)
            .safeAreaInset(edge: .bottom) {
                submitButton
            }
        }
        .task {
            await viewModel.fetchSchools()
            await viewModel.termsAgreementFlow.fetchTerms()
        }
        .onChange(of: viewModel.registerState) { _, newState in
            handleRegisterStateChange(newState)
        }
        .alertPrompt(item: $alertPrompt)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var emailAvailabilityStatusRow: some View {
        switch viewModel.emailAvailabilityState {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: DefaultSpacing.spacing8) {
                ProgressView()
                Text(Constants.emailAvailabilityTitle)
                    .appFont(.footnote, color: .grey500)
            }
        case .loaded(let isAvailable):
            HStack(spacing: DefaultSpacing.spacing8) {
                Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isAvailable ? Color.green500 : Color.red500)
                Text(
                    isAvailable
                        ? Constants.emailAvailableMessage
                        : Constants.emailUnavailableMessage
                )
                .appFont(.footnote, color: isAvailable ? .green500 : .red500)
            }
        case .failed:
            HStack(spacing: DefaultSpacing.spacing8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Color.red500)
                Text(Constants.emailAvailabilityFailedMessage)
                    .appFont(.footnote, color: .red500)
                Button(Constants.emailAvailabilityRetryTitle) {
                    viewModel.retryEmailAvailabilityCheck()
                }
                .appFont(.footnote, weight: .semibold, color: .indigo500)
            }
        }
    }

    private var submitButton: some View {
        Button {
            Task { await viewModel.register() }
        } label: {
            Group {
                if viewModel.registerState.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(Constants.submitTitle)
                        .appFont(.subheadline, weight: .semibold, color: .white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DefaultConstant.defaultBtnPadding)
        }
        .buttonStyle(.glassProminent)
        .tint(.indigo500)
        .disabled(!viewModel.canSubmit || viewModel.registerState.isLoading)
        .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }

    // MARK: - Function

    /// 가입 완료 처리 (Q2): 재조회한 프로필의 승인 여부에 따라 분기한다.
    ///
    /// 승인된 경우 바로 메인으로 진입하고, 미승인인 경우 로그인 화면으로 안내한다.
    /// `pendingApproval` 전용 상태는 아직 `AppFlow`에 없으므로 선점하지 않는다.
    // TODO(#945): pendingApproval 전용 AppFlow 상태가 추가되면 그쪽으로 분기.
    private func handleRegisterStateChange(_ newState: Loadable<String>) {
        guard case .loaded = newState else { return }

        guard !viewModel.isApprovedAfterRegister else {
            appFlow.showMain()
            return
        }

        alertPrompt = AlertPrompt(
            title: Constants.completedTitle,
            message: Constants.pendingApprovalMessage,
            positiveBtnTitle: Constants.confirmTitle,
            positiveBtnAction: { appFlow.showLogin() }
        )
    }
}
