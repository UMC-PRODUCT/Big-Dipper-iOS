//
//  AuthUseCaseProvider.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/9/26.
//

import Foundation

/// Auth Feature에서 사용하는 UseCase들을 제공하는 Provider Protocol
protocol AuthUseCaseProviding {
    /// 소셜 로그인 UseCase
    var loginUseCase: LoginUseCaseProtocol { get }
    /// 이메일 로그인 UseCase
    var loginByEmailUseCase: LoginByEmailUseCaseProtocol { get }
    /// 이메일 회원가입 UseCase
    var registerByEmailUseCase: RegisterByEmailUseCaseProtocol { get }
    /// 이메일 중복 검사 UseCase
    var checkEmailAvailabilityUseCase: CheckEmailAvailabilityUseCaseProtocol { get }
    /// 내 OAuth 정보 조회 UseCase
    var fetchMyOAuthUseCase: FetchMyOAuthUseCaseProtocol { get }
    /// OAuth 수단 추가 연동 UseCase
    var addMemberOAuthUseCase: AddMemberOAuthUseCaseProtocol { get }
    /// OAuth 수단 연동 해제 UseCase
    var deleteMemberOAuthUseCase: DeleteMemberOAuthUseCaseProtocol { get }
    /// 이메일 인증 발송 UseCase
    var sendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol { get }
    /// 이메일 인증 코드 재전송 UseCase
    var resendEmailVerificationUseCase: ResendEmailVerificationUseCaseProtocol { get }
    /// 이메일 인증코드 검증 UseCase
    var verifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol { get }
    /// 비밀번호 초기화 UseCase
    var resetPasswordUseCase: ResetPasswordUseCaseProtocol { get }
    /// 회원가입 UseCase
    var registerUseCase: RegisterUseCaseProtocol { get }
    /// 기존 챌린저 인증 코드 등록 UseCase
    var registerExistingChallengerUseCase: RegisterExistingChallengerUseCaseProtocol { get }
    /// 회원가입 데이터 조회 UseCase
    var fetchSignUpDataUseCase: FetchSignUpDataUseCaseProtocol { get }
    /// OAuth 회원 비밀번호 추가 등록 UseCase
    var registerCredentialUseCase: RegisterCredentialUseCaseProtocol { get }
}

/// Auth UseCase Provider 구현
///
/// RepositoryProvider와 TokenStore를 주입받아 UseCase들을 생성합니다.
final class AuthUseCaseProvider: AuthUseCaseProviding {

    // MARK: - Property

    let loginUseCase: LoginUseCaseProtocol
    let loginByEmailUseCase: LoginByEmailUseCaseProtocol
    let registerByEmailUseCase: RegisterByEmailUseCaseProtocol
    let checkEmailAvailabilityUseCase: CheckEmailAvailabilityUseCaseProtocol
    let fetchMyOAuthUseCase: FetchMyOAuthUseCaseProtocol
    let addMemberOAuthUseCase: AddMemberOAuthUseCaseProtocol
    let deleteMemberOAuthUseCase: DeleteMemberOAuthUseCaseProtocol
    let sendEmailVerificationUseCase: SendEmailVerificationUseCaseProtocol
    let resendEmailVerificationUseCase: ResendEmailVerificationUseCaseProtocol
    let verifyEmailCodeUseCase: VerifyEmailCodeUseCaseProtocol
    let resetPasswordUseCase: ResetPasswordUseCaseProtocol
    let registerUseCase: RegisterUseCaseProtocol
    let registerExistingChallengerUseCase: RegisterExistingChallengerUseCaseProtocol
    let fetchSignUpDataUseCase: FetchSignUpDataUseCaseProtocol
    let registerCredentialUseCase: RegisterCredentialUseCaseProtocol

    // MARK: - Init

    init(
        repositoryProvider: AuthRepositoryProviding,
        tokenStore: TokenStore
    ) {
        let repository = repositoryProvider.authRepository

        self.loginUseCase = LoginUseCase(
            repository: repository,
            tokenStore: tokenStore
        )
        self.loginByEmailUseCase = LoginByEmailUseCase(
            repository: repository,
            tokenStore: tokenStore
        )
        self.registerByEmailUseCase = RegisterByEmailUseCase(
            repository: repository,
            tokenStore: tokenStore
        )
        self.checkEmailAvailabilityUseCase = CheckEmailAvailabilityUseCase(
            repository: repository
        )
        self.fetchMyOAuthUseCase = FetchMyOAuthUseCase(
            repository: repository
        )
        self.addMemberOAuthUseCase = AddMemberOAuthUseCase(
            repository: repository
        )
        self.deleteMemberOAuthUseCase = DeleteMemberOAuthUseCase(
            repository: repository
        )
        self.sendEmailVerificationUseCase = SendEmailVerificationUseCase(
            repository: repository
        )
        self.resendEmailVerificationUseCase = ResendEmailVerificationUseCase(
            repository: repository
        )
        self.verifyEmailCodeUseCase = VerifyEmailCodeUseCase(
            repository: repository
        )
        self.resetPasswordUseCase = ResetPasswordUseCase(
            repository: repository
        )
        self.registerUseCase = RegisterUseCase(
            repository: repository
        )
        self.registerExistingChallengerUseCase = RegisterExistingChallengerUseCase(
            repository: repository
        )
        self.fetchSignUpDataUseCase = FetchSignUpDataUseCase(
            repository: repository
        )
        self.registerCredentialUseCase = RegisterCredentialUseCase(
            repository: repository
        )
    }
}
