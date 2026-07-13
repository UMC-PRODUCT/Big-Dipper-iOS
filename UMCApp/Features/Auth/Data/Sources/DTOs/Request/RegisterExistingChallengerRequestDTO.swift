//
//  RegisterExistingChallengerRequestDTO.swift
//  AuthData
//
//  Created by euijjang97 on 7/9/26.
//

/// 기존 챌린저 코드 등록 요청 DTO
///
/// `POST /api/v1/challenger-record/member`
public struct RegisterExistingChallengerRequestDTO: Encodable {
    /// 운영진이 발급한 6자리 코드
    public let code: String

    public init(code: String) {
        self.code = code
    }
}
