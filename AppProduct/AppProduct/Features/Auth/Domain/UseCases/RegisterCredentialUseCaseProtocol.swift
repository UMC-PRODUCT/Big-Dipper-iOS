//
//  RegisterCredentialUseCaseProtocol.swift
//  AppProduct
//

import Foundation

// MARK: - Protocol

protocol RegisterCredentialUseCaseProtocol {
    /// OAuth 회원이 이메일/비밀번호 로그인 수단을 추가 등록합니다.
    /// 이메일은 서버가 기존 Member.email을 사용하며, 비밀번호만 전달합니다.
    /// - Parameter rawPassword: 평문 비밀번호
    func execute(rawPassword: String) async throws
}
