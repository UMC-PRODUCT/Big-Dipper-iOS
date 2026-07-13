//
//  VerifyEmailCodeUseCaseProtocol.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/9/26.
//

/// 이메일 인증 코드 검증 UseCase 인터페이스
public protocol VerifyEmailCodeUseCaseProtocol {
    /// 이메일 인증 코드를 검증한다.
    /// - Parameters:
    ///   - emailVerificationId: 발송 시 발급받은 이메일 인증 요청 식별자
    ///   - verificationCode: 사용자가 입력한 인증 코드
    /// - Returns: 회원가입에 사용할 이메일 인증 토큰(emailVerificationToken)
    func execute(emailVerificationId: String, verificationCode: String) async throws -> String
}
