//
//  SignUpByIdPwViewModel.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import Foundation
import UserNotifications
import Photos

/// 이메일 회원가입 화면의 상태와 비즈니스 로직을 관리하는 ViewModel
///
/// 이메일 인증, 이메일 중복 확인(debounce), 비밀번호 검증, 약관 동의를 단일 화면에서
/// 처리합니다. 가입 성공 시 서버가 토큰을 즉시 발급하므로 별도 로그인 단계는 없습니다.
@Observable
final class SignUpByIdPwViewModel {

    // MARK: - Property

    private let sendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol
    private let verifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol
    private let registerByEmailUseCase: RegisterByEmailUseCaseProtocol
    private let checkEmailAvailabilityUseCase: CheckEmailAvailabilityUseCaseProtocol
    private let fetchSignUpDataUseCase: FetchSignUpDataUseCaseProtocol

    // 이메일 인증
    var emailInput: String = ""
    var verificationCodeInput: String = ""
    private(set) var emailVerificationId: String?
    private(set) var emailVerificationToken: String?
    var isEmailVerified: Bool = false

    // 이메일 중복 확인
    private(set) var emailAvailability: Loadable<Bool> = .idle
    private var emailAvailabilityCache: [String: Bool] = [:]
    private var emailAvailabilityTask: Task<Void, Never>?

    // 비밀번호
    var passwordInput: String = ""
    var passwordConfirmInput: String = ""

    // 이름 / 닉네임
    var nameInput: String = ""
    var nicknameInput: String = ""

    // 학교
    var selectedSchool: School?
    private(set) var schoolsState: Loadable<[School]> = .idle

    // 약관
    private(set) var termsState: Loadable<[Terms]> = .idle
    var termsAgreements: [String: Bool] = [:]

    // 제출
    private(set) var registerState: Loadable<RegisterByIdPwResult> = .idle
    var isLoading: Bool = false

    // MARK: - Init

    init(
        sendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol,
        verifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol,
        registerByEmailUseCase: RegisterByEmailUseCaseProtocol,
        checkEmailAvailabilityUseCase: CheckEmailAvailabilityUseCaseProtocol,
        fetchSignUpDataUseCase: FetchSignUpDataUseCaseProtocol
    ) {
        self.sendEmailVerificationUseCase = sendEmailVerificationUseCase
        self.verifyEmailCodeUseCase = verifyEmailCodeUseCase
        self.registerByEmailUseCase = registerByEmailUseCase
        self.checkEmailAvailabilityUseCase = checkEmailAvailabilityUseCase
        self.fetchSignUpDataUseCase = fetchSignUpDataUseCase
    }

    deinit {
        emailAvailabilityTask?.cancel()
    }

    // MARK: - Validation

    /// 비밀번호 8자 이상 검증
    var isPasswordValid: Bool {
        passwordInput.count >= 8
    }

    /// 비밀번호 확인 일치 검증
    var isPasswordConfirmed: Bool {
        !passwordInput.isEmpty && passwordInput == passwordConfirmInput
    }

    /// 이름 1~10자 검증
    var isNameValid: Bool {
        let count = nameInput.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).count
        return count >= 1 && count <= 10
    }

    /// 닉네임 한글 1~5자 검증
    var isNicknameValid: Bool {
        let trimmed = nicknameInput.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard (1...5).contains(trimmed.count) else { return false }
        let pattern = "^[가-힣]+$"
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    /// 이메일 사용 가능 여부 (.loaded(true)만 OK)
    var isEmailAvailable: Bool {
        if case .loaded(true) = emailAvailability {
            return true
        }
        return false
    }

    /// 필수 약관 모두 동의 여부
    var isMandatoryTermsAgreed: Bool {
        guard case .loaded(let terms) = termsState else { return false }
        return terms
            .filter { $0.isMandatory }
            .allSatisfy { termsAgreements[$0.id] == true }
    }

    /// 전체 약관 동의 여부
    var isAllTermsAgreed: Bool {
        !termsAgreements.isEmpty &&
        termsAgreements.values.allSatisfy { $0 }
    }

    /// 가입 완료 버튼 활성 조건 (모든 검증 통과)
    var canSubmit: Bool {
        isEmailVerified &&
        isEmailAvailable &&
        isPasswordValid &&
        isPasswordConfirmed &&
        isNameValid &&
        isNicknameValid &&
        selectedSchool != nil &&
        isMandatoryTermsAgreed
    }

    // MARK: - Function

    /// 학교 목록 조회
    @MainActor
    func fetchSchools() async {
        schoolsState = .loading
        do {
            let schools = try await fetchSignUpDataUseCase.fetchSchools()
            schoolsState = .loaded(schools)
        } catch {
            schoolsState = .failed(
                .unknown(message: error.localizedDescription)
            )
        }
    }

    /// 약관 목록 조회 (SERVICE, PRIVACY)
    @MainActor
    func fetchTerms() async {
        termsState = .loading
        do {
            var termsList: [Terms] = []
            termsAgreements.removeAll()
            for type in [TermsType.service, TermsType.privacy] {
                let terms = try await fetchSignUpDataUseCase
                    .fetchTerms(termsType: type.rawValue)
                termsList.append(terms)
                termsAgreements[terms.id] = false
            }
            termsState = .loaded(termsList)
        } catch let appError as AppError {
            termsState = .failed(appError)
        } catch let repositoryError as RepositoryError {
            termsState = .failed(.repository(repositoryError))
        } catch let networkError as NetworkError {
            termsState = .failed(.network(networkError))
        } catch {
            termsState = .failed(
                .unknown(message: error.localizedDescription)
            )
        }
    }

    /// 이메일 인증번호 요청
    @MainActor
    func requestEmailVerification() async throws {
        let id = try await sendEmailVerificationUseCase
            .execute(email: emailInput)
        emailVerificationId = id
    }

    /// 이메일 인증번호 검증
    @MainActor
    func verifyEmailCode(_ code: String) async throws {
        guard let emailVerificationId else { return }
        let token = try await verifyEmailCodeUseCase.execute(
            emailVerificationId: emailVerificationId,
            verificationCode: code
        )
        emailVerificationToken = token
        verificationCodeInput = code
        isEmailVerified = true

        scheduleEmailAvailabilityCheck()
    }

    /// 이메일 변경 시 인증 상태 및 중복확인 초기화
    @MainActor
    func resetEmailVerification() {
        isEmailVerified = false
        emailVerificationId = nil
        emailVerificationToken = nil
        verificationCodeInput = ""
        emailAvailabilityTask?.cancel()
        emailAvailability = .idle
        emailAvailabilityCache.removeAll()
    }

    /// 전체 약관 동의/해제 토글
    func toggleAllTerms(_ agreed: Bool) {
        for key in termsAgreements.keys {
            termsAgreements[key] = agreed
        }
    }

    /// 회원가입 실행
    @MainActor
    func register() async {
        guard canSubmit,
              let selectedSchool,
              let emailVerificationToken else { return }

        isLoading = true
        registerState = .loading

        let agreements = termsAgreements.map { key, value in
            EmailRegisterTermsAgreementDTO(termsId: key, agreed: value)
        }

        let request = EmailRegisterRequestDTO(
            rawPassword: passwordInput,
            name: nameInput.trimmingCharacters(in: .whitespacesAndNewlines),
            nickname: nicknameInput.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            emailVerificationToken: emailVerificationToken,
            schoolId: selectedSchool.id,
            termsAgreements: agreements
        )

        do {
            let result = try await registerByEmailUseCase.execute(
                request: request
            )
            registerState = .loaded(result)
        } catch let error as AppError {
            registerState = .failed(error)
        } catch let error as RepositoryError {
            registerState = .failed(.repository(error))
        } catch let error as NetworkError {
            registerState = .failed(.network(error))
        } catch let error as AuthError {
            registerState = .failed(.auth(error))
        } catch {
            registerState = .failed(
                .unknown(message: error.localizedDescription)
            )
        }

        isLoading = false
    }
}

// MARK: - Email Availability (debounce)

private extension SignUpByIdPwViewModel {
    /// 이메일 인증 완료 시 중복 검사를 500ms debounce 후 호출
    func scheduleEmailAvailabilityCheck() {
        emailAvailabilityTask?.cancel()

        let trimmed = emailInput.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            emailAvailability = .idle
            return
        }

        if let cached = emailAvailabilityCache[trimmed] {
            emailAvailability = .loaded(cached)
            return
        }

        emailAvailability = .loading
        emailAvailabilityTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            await self.performEmailAvailabilityCheck(email: trimmed)
        }
    }

    @MainActor
    func performEmailAvailabilityCheck(email: String) async {
        guard emailInput.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) == email else { return }

        do {
            let available = try await checkEmailAvailabilityUseCase
                .execute(email: email)
            emailAvailabilityCache[email] = available
            guard emailInput.trimmingCharacters(
                in: .whitespacesAndNewlines
            ) == email else { return }
            emailAvailability = .loaded(available)
        } catch let error as RepositoryError {
            if case .serverError(let code, _) = error, code == "AUTHENTICATION-0026" {
                emailAvailability = .loaded(false)
            } else {
                emailAvailability = .failed(.repository(error))
            }
        } catch let error as AppError {
            emailAvailability = .failed(error)
        } catch {
            emailAvailability = .failed(
                .unknown(message: error.localizedDescription)
            )
        }
    }
}

// MARK: - Permission

extension SignUpByIdPwViewModel {

    /// 시스템 권한 요청을 순차적으로 처리합니다.
    func requestPermission(
        notification: Bool,
        location: Bool,
        photo: Bool
    ) async -> [String: Bool] {
        var request: [String: Bool] = [:]

        if notification {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
                request["notification"] = granted
            } catch {
                request["notification"] = false
            }
            try? await Task.sleep(for: .milliseconds(200))
        }

        if location {
            LocationManager.shared.requestAuthorization()
            try? await Task.sleep(for: .milliseconds(1))
            request["location"] = LocationManager.shared.isAuthorized
            try? await Task.sleep(for: .milliseconds(500))
        }

        if photo {
            let status = await PHPhotoLibrary
                .requestAuthorization(for: .readWrite)
            request["photo"] = (
                status == .authorized || status == .limited
            )
        }

        return request
    }
}
