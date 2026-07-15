//
//  RegisterCredentialUseCaseProtocol.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/9/26.
//

/// OAuth 회원의 이메일/비밀번호 로그인 수단 추가 등록 UseCase 인터페이스
public protocol RegisterCredentialUseCaseProtocol {
    /// OAuth 회원에게 이메일/비밀번호 로그인 수단을 추가 등록한다.
    /// - Parameter rawPassword: 원문 비밀번호
    func execute(rawPassword: String) async throws
}
