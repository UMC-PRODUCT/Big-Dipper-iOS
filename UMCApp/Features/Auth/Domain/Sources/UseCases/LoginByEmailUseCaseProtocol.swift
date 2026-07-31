//
//  LoginByEmailUseCaseProtocol.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/31/26.
//

/// 이메일(ID/PW) 로그인 UseCase 인터페이스
public protocol LoginByEmailUseCaseProtocol {
    /// 이메일 로그인 실행
    /// - Parameters:
    ///   - email: 이메일 주소
    ///   - password: 평문 비밀번호 (TLS 구간 서버 해싱 위임)
    /// - Returns: 로그인 결과 (회원 ID)
    func execute(email: String, password: String) async throws -> LoginByIdPwResult
}
