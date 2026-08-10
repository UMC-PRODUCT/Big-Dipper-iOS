//
//  ChangePasswordUseCaseProtocol.swift
//  AuthDomain
//
//  Created by euijjang97 on 8/10/26.
//

/// 비밀번호 변경 UseCase 인터페이스
public protocol ChangePasswordUseCaseProtocol {
    /// 현재 비밀번호를 확인한 뒤 새 비밀번호로 변경한다.
    /// - Parameters:
    ///   - currentPassword: 현재 비밀번호(평문)
    ///   - newPassword: 새로 설정할 평문 비밀번호
    func execute(currentPassword: String, newPassword: String) async throws
}
