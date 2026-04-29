//
//  SignUpViewModel.swift
//  AppProduct
//
//  Created by euijjang97 on 1/12/26.
//

import Foundation
import UserNotifications
import Photos

/// 회원가입 화면의 상태와 비즈니스 로직을 관리하는 뷰 모델
///
/// UseCase를 주입받아 이메일 인증, 학교/약관 조회, 회원가입 API를 처리합니다.
/// @Observable 패턴을 사용하여 SwiftUI와 자동으로 바인딩됩니다.
@Observable
final class SignUpViewModel {

    // MARK: - Property

    /// OAuth 인증 토큰 (소셜 로그인 시 발급)
    private let oAuthVerificationToken: String

    /// 회원가입 직후 세션 복구에 사용할 소셜 로그인 컨텍스트
    private let postRegisterLoginContext: PostRegisterLoginContext?

    /// 이메일 인증 발송 UseCase
    private let sendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol

    /// 이메일 인증코드 검증 UseCase
    private let verifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol

    /// 회원가입 UseCase
    private let registerUseCase: RegisterUseCaseProtocol

    /// 회원가입 직후 세션 복구용 로그인 UseCase
    private let loginUseCase: LoginUseCaseProtocol

    /// 회원가입 데이터 조회 UseCase
    private let fetchSignUpDataUseCase: FetchSignUpDataUseCaseProtocol

    /// 사용자 실명
    var name: String = ""

    /// 사용자 닉네임
    var nickname: String = ""

    /// 이메일 주소
    var email: String = ""

    /// 이메일 인증번호
    var emailCode: String = ""

    /// 선택된 학교
    var selectedSchool: School?

    /// 학교 목록 상태
    private(set) var schoolsState: Loadable<[School]> = .idle

    /// 약관 목록 상태
    private(set) var termsState: Loadable<[Terms]> = .idle

    /// 약관 동의 상태 (termsId(String) → 동의 여부)
    var termsAgreements: [String: Bool] = [:]

    /// 이메일 인증 완료 여부
    var isEmailVerified: Bool = false

    /// 이메일 인증 ID (인증 발송 후 저장)
    private(set) var emailVerificationId: String?

    /// 이메일 인증 토큰 (코드 검증 후 저장)
    private(set) var emailVerificationToken: String?

    /// 회원가입 상태
    private(set) var registerState: Loadable<Int> = .idle

    /// 폼 유효성 검증 상태
    var isFormValid: Bool {
        !name.isEmpty &&
        !nickname.isEmpty &&
        !email.isEmpty &&
        selectedSchool != nil &&
        isEmailVerified
//        mandatoryTermsAgreed
    }

//    /// 필수 약관 모두 동의 여부
//    private var mandatoryTermsAgreed: Bool {
//        guard case .loaded(let terms) = termsState else {
//            return false
//        }
//        return terms
//            .filter { $0.isMandatory }
//            .allSatisfy { termsAgreements[$0.id] == true }
//    }

    /// 로딩 상태 (비동기 작업 진행 중)
    var isLoading: Bool = false

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
        self.oAuthVerificationToken = oAuthVerificationToken
        self.postRegisterLoginContext = postRegisterLoginContext
        self.sendEmailVerificationUseCase = sendEmailVerificationUseCase
        self.verifyEmailCodeUseCase = verifyEmailCodeUseCase
        self.registerUseCase = registerUseCase
        self.loginUseCase = loginUseCase
        self.fetchSignUpDataUseCase = fetchSignUpDataUseCase
        self.email = initialEmail?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
        self.name = initialName?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
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

        #if DEBUG
        if case .failed(let error) = termsState {
            print("[Auth][SignUp] fetchTerms failed: \(error.userMessage)")
        }
        #endif
    }

    /// 이메일 인증번호 요청
    @MainActor
    func requestEmailVerification() async throws {
        let id = try await sendEmailVerificationUseCase
            .execute(email: email)
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
        emailCode = code
        isEmailVerified = true
    }

    /// 이메일 변경 시 이메일 인증 상태를 초기화합니다.
    ///
    /// 기존 인증번호/토큰은 이전 이메일 기준이므로 폐기되어야 합니다.
    @MainActor
    func resetEmailVerification() {
        isEmailVerified = false
        emailVerificationId = nil
        emailVerificationToken = nil
        emailCode = ""
    }

    /// 회원가입 실행
    @MainActor
    func register() async {
        guard let selectedSchool,
              let emailVerificationToken else {
            #if DEBUG
            print("[Auth] register guard 실패 - school: \(selectedSchool != nil), token: \(emailVerificationToken != nil)")
            #endif
            return
        }

        isLoading = true
        registerState = .loading

        // TODO: 약관 UI 복원 후 제거 - [25.2.10] 이재원
        let agreements = termsAgreements.isEmpty
            ? [
                TermsAgreementDTO(termsId: "4", isAgreed: true),
                TermsAgreementDTO(termsId: "2", isAgreed: true),
                TermsAgreementDTO(termsId: "1", isAgreed: true)
            ]
            : termsAgreements.map { key, value in
                TermsAgreementDTO(termsId: key, isAgreed: value)
            }

        let request = RegisterRequestDTO(
            oAuthVerificationToken: oAuthVerificationToken,
            name: name,
            nickname: nickname,
            emailVerificationToken: emailVerificationToken,
            schoolId: selectedSchool.id,
            profileImageId: nil,
            termsAgreements: agreements
        )

        #if DEBUG
        print("[Auth] register 요청: \(request)")
        #endif

        do {
            let memberId = try await registerUseCase
                .execute(request: request)
            try await restoreSessionAfterRegisterIfNeeded()
            #if DEBUG
            print("[Auth] register 성공: memberId=\(memberId)")
            #endif
            registerState = .loaded(memberId)
        } catch let error as AppError {
            #if DEBUG
            print("[Auth] register 실패: \(error)")
            #endif
            registerState = .failed(error)
        } catch let error as RepositoryError {
            #if DEBUG
            print("[Auth] register 실패: \(error)")
            #endif
            registerState = .failed(.repository(error))
        } catch let error as NetworkError {
            #if DEBUG
            print("[Auth] register 실패: \(error)")
            #endif
            registerState = .failed(.network(error))
        } catch let error as AuthError {
            #if DEBUG
            print("[Auth] register 실패: \(error)")
            #endif
            registerState = .failed(.auth(error))
        } catch {
            #if DEBUG
            print("[Auth] register 실패: \(error)")
            #endif
            registerState = .failed(
                .unknown(message: error.localizedDescription)
            )
        }

        isLoading = false
    }

    /// 회원가입 직후 다시 로그인해 액세스 토큰을 저장합니다.
    private func restoreSessionAfterRegisterIfNeeded() async throws {
        guard let postRegisterLoginContext else { return }

        let loginResult: OAuthLoginResult

        switch postRegisterLoginContext {
        case .kakao(let accessToken, let email):
            loginResult = try await loginUseCase.executeKakao(
                accessToken: accessToken,
                email: email
            )
        case .apple(let authorizationCode, let email, let fullName):
            loginResult = try await loginUseCase.executeApple(
                authorizationCode: authorizationCode,
                email: email,
                fullName: fullName
            )
        }

        guard case .existingMember = loginResult else {
            throw AuthError.socialLoginFailed(
                provider: "Auth",
                reason: "회원가입 후 세션 복구에 실패했습니다."
            )
        }
    }

    /// 전체 약관 동의/해제 토글
    func toggleAllTerms(_ agreed: Bool) {
        for key in termsAgreements.keys {
            termsAgreements[key] = agreed
        }
    }

    /// 전체 약관 동의 여부
    var isAllTermsAgreed: Bool {
        !termsAgreements.isEmpty &&
        termsAgreements.values.allSatisfy { $0 }
    }
}

// MARK: - PermissionRequest

extension SignUpViewModel {

    /// 시스템 권한 요청을 순차적으로 처리합니다.
    ///
    /// - Parameters:
    ///   - notification: 알림 권한 요청 여부
    ///   - location: 위치 권한 요청 여부
    ///   - photo: 사진 라이브러리 권한 요청 여부
    /// - Returns: 각 권한의 승인 결과
    func requestPermission(
        notification: Bool,
        location: Bool,
        photo: Bool
    ) async -> [String: Bool] {
        var request: [String: Bool] = [:]

        // 1. 알림 권한 요청
        if notification {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
                request["notification"] = granted
            } catch {
                request["notification"] = false
            }
            // 다음 권한 팝업과의 간격 확보
            try? await Task.sleep(for: .milliseconds(200))
        }

        // 2. 위치 권한 요청
        if location {
            LocationManager.shared.requestAuthorization()
            try? await Task.sleep(for: .milliseconds(1))
            request["location"] = LocationManager.shared.isAuthorized
            try? await Task.sleep(for: .milliseconds(500))
        }

        // 3. 사진 라이브러리 권한 요청
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
