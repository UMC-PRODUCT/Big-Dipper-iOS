//
//  ResetPasswordUseCaseProtocol.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/10/26.
//

/// 비밀번호 재설정 UseCase 인터페이스
public protocol ResetPasswordUseCaseProtocol {
    /// 이메일 인증 완료 토큰으로 비밀번호를 재설정한다.
    /// - Parameters:
    ///   - emailVerificationToken: 이메일 인증 완료 토큰(`PASSWORD_RESET` 목적)
    ///   - newPassword: 새로 설정할 평문 비밀번호
    func execute(emailVerificationToken: String, newPassword: String) async throws
}
