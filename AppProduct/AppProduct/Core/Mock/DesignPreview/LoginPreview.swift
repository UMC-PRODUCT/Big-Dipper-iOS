//
//  LoginPreview.swift
//  AppProduct
//
//  Created by euijjang97 on 1/31/26.
//

import Foundation
import SwiftUI

#Preview("로그인") {
    LoginView(
        loginUseCase: PreviewLoginUseCase(),
        loginByIdPwUseCase: PreviewLoginByIdPwUseCase(),
        fetchMyProfileUseCase: PreviewFetchMyProfileUseCase(),
        tokenStore: KeychainTokenStore(),
        errorHandler: ErrorHandler()
    )
}

/// Preview 전용 ID/PW 로그인 UseCase
private struct PreviewLoginByIdPwUseCase: LoginByIdPwUseCaseProtocol {
    func execute(
        loginId: String,
        password: String
    ) async throws -> LoginByIdPwResult {
        LoginByIdPwResult(
            memberId: "preview_member_id",
            tokenPair: TokenPair(
                accessToken: "preview",
                refreshToken: "preview"
            )
        )
    }
}

/// Preview 전용 LoginUseCase
private struct PreviewLoginUseCase: LoginUseCaseProtocol {
    func executeKakao(
        accessToken: String,
        email: String
    ) async throws -> OAuthLoginResult {
        .existingMember(
            tokenPair: TokenPair(
                accessToken: "preview",
                refreshToken: "preview"
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
                accessToken: "preview",
                refreshToken: "preview"
            )
        )
    }
}

/// Preview 전용 내 프로필 조회 UseCase
private struct PreviewFetchMyProfileUseCase: FetchMyProfileUseCaseProtocol {
    func execute() async throws -> HomeProfileResult {
        HomeProfileResult(
            memberId: "1",
            schoolId: 1,
            schoolName: "중앙대학교",
            latestChallengerId: nil,
            latestGisuId: nil,
            chapterId: nil,
            chapterName: "",
            part: nil,
            seasonTypes: [
                .days(0),
                .gens([])
            ],
            roles: [],
            generations: []
        )
    }
}

#Preview("회원가입") {
    NavigationStack {
        SignUpView(
            oAuthVerificationToken: "preview_token",
            sendEmailVerificationUseCase: PreviewSendEmailUseCase(),
            verifyEmailCodeUseCase: PreviewVerifyCodeUseCase(),
            registerUseCase: PreviewRegisterUseCase(),
            loginUseCase: PreviewLoginUseCase(),
            fetchSignUpDataUseCase: PreviewFetchSignUpDataUseCase()
        )
    }
}

/// Preview 전용 UseCase들
private struct PreviewSendEmailUseCase: SendEmailVerificationUseCaseProtocol {
    func execute(email: String) async throws -> String {
        "preview_verification_id"
    }
}

private struct PreviewVerifyCodeUseCase: VerifyEmailCodeUseCaseProtocol {
    func execute(
        emailVerificationId: String,
        verificationCode: String
    ) async throws -> String {
        "preview_email_token"
    }
}

private struct PreviewRegisterUseCase: RegisterUseCaseProtocol {
    func execute(request: RegisterRequestDTO) async throws -> String {
        "1"
    }
}

private struct PreviewFetchSignUpDataUseCase: FetchSignUpDataUseCaseProtocol {
    func fetchSchools() async throws -> [School] {
        [
            School(id: "1", name: "중앙대학교"),
            School(id: "2", name: "서울대학교")
        ]
    }

    func fetchTerms(termsType: String) async throws -> Terms {
        let type = TermsType(rawValue: termsType) ?? .service
        return Terms(
            id: type == .service ? "2" : "1",
            link: "https://example.com/terms/\(type.rawValue.lowercased())",
            isMandatory: true,
            termsType: type
        )
    }
}

#Preview("실패시 화면") {
    FailedVerificationUMC()
}

#Preview("승인 대기") {
    FailedVerificationUMC()
}

#Preview("홈") {
    LoginHomePreviewView()
}

/// 홈 화면 Preview용 래퍼 뷰 (PathStore 포함 DIContainer 구성)
private struct LoginHomePreviewView: View {
    private let di: DIContainer

    init() {
        let container = DIContainer()
        container.register(PathStore.self) { PathStore() }
        self.di = container
    }

    var body: some View {
        NavigationStack {
            HomeView(container: di, shouldFetchOnTask: false)
        }
        .environment(di)
        .environment(ErrorHandler())
    }
}
