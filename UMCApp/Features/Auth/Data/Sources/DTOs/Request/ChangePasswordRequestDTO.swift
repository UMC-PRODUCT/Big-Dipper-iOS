//
//  ChangePasswordRequestDTO.swift
//  AuthData
//
//  Created by euijjang97 on 8/10/26.
//

/// 로그인 상태에서 비밀번호를 변경하는 요청 DTO
///
/// `PATCH /api/v1/auth/password`
public struct ChangePasswordRequestDTO: Encodable {
    /// 현재 비밀번호(평문)
    public let currentPassword: String
    /// 새로 설정할 평문 비밀번호
    public let newPassword: String

    public init(currentPassword: String, newPassword: String) {
        self.currentPassword = currentPassword
        self.newPassword = newPassword
    }
}
